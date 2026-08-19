# Dispatch MVP

MVP de una plataforma de **despacho de delivery** con:

- **App móvil Flutter** (iOS + Android): login, registro, creación de pedidos sobre un mapa, seguimiento **en tiempo real** del repartidor y pantalla de **suscripciones**.
- **Backend Node.js + Express**: API REST, autenticación JWT, **pagos recurrentes con Stripe**, e integración con **software de despacho de terceros** (proveedor intercambiable).
- **PostgreSQL**: gestión de cuentas de usuario, niveles de suscripción (`FREE / BASIC / PRO`), órdenes y ubicaciones.
- **Socket.io**: geolocalización en tiempo real (el repartidor publica su posición y los clientes la reciben en vivo).

---

## Arquitectura

```
┌──────────────┐      REST + Socket.io      ┌─────────────────────┐
│  Flutter app │ ◄────────────────────────► │ Node.js + Express   │
│  (iOS/Android)│                            │  · Auth (JWT)       │
│  · Mapas     │                            │  · Stripe (recurring)│
│  · Tracking  │                            │  · Órdenes          │
└──────────────┘                            │  · Socket.io (GPS)  │
                                            └─────────┬───────────┘
                                                      │ REST
                                   ┌──────────────────┴──────────────────┐
                                   │ PostgreSQL                          │
                                   │  users · plans · subscriptions      │
                                   │  orders · courier_locations         │
                                   └─────────────────────────────────────┘

                            Software de despacho de terceros
                                   (Onfleet, Shipbubble,
                                    DispatchTrack, ...) via API REST
```

---

## Estructura del proyecto

```
backend/   API REST en Node.js (Express + PostgreSQL + Stripe + Socket.io)
mobile/    Aplicación Flutter (iOS y Android)
```

---

## Requisitos

- Node.js ≥ 18
- Docker + Docker Compose (para PostgreSQL)
- Flutter ≥ 3.27 (instala iOS/Android toolchains)
- Una cuenta de **Stripe** (modo test) para los pagos recurrentes

---

## 1. Backend

```bash
cd backend
cp .env.example .env          # edita el .env con tus claves
docker compose up -d          # levanta PostgreSQL
npm install
npm run db:init               # aplica el esquema (tablas + planes)
npm run db:seed               # crea prices en Stripe y usuario demo
npm run dev                   # http://localhost:4000
```

Verifica: `curl http://localhost:4000/health`

### Credenciales de prueba
| Email | Contraseña | Rol |
|---|---|---|
| `demo@dispatch.app` | `Demo1234!` | Cliente |

### Stripe (pagos recurrentes)
1. Crea una cuenta en https://dashboard.stripe.com (modo test) y copia `sk_test_...` y `whsec_...` al `.env`.
2. El seed crea automáticamente un **Price** mensual por cada plan (BASIC y PRO).
3. Para probar el webhook localmente:
   ```bash
   stripe listen --forward-to localhost:4000/webhook/stripe
   ```
   Copia la clave `whsec_...` al `.env` y reinicia.
4. Tarjetas de prueba: `4242 4242 4242 4242` (cualquier fecha/CVC).

> Sin claves reales de Stripe, el registro y los pedidos funcionan igual; solo la suscripción requiere Stripe.

### Software de despacho de terceros
La capa `src/services/dispatchService.js` expone una interfaz única (`createTask`, `getTaskStatus`, `cancelTask`):

- `DISPATCH_PROVIDER=mock` → simulación local (ideal para desarrollo).
- `DISPATCH_PROVIDER=rest` → conecta a cualquier API REST mediante `DISPATCH_BASE_URL` y `DISPATCH_API_KEY`. Ajusta los endpoints del proveedor según su documentación.

---

## 2. App Flutter

```bash
cd mobile
flutter pub get
```

> El scaffolding de plataforma (`android/`, `ios/`) ya está incluido con los permisos configurados.

### Permisos (ya aplicados en el proyecto)
**Android** (`android/app/src/main/AndroidManifest.xml`): permisos `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` y `usesCleartextTraffic="true"`.

**iOS** (`ios/Runner/Info.plist`): `NSLocationWhenInUseUsageDescription` y `NSAppTransportSecurity` (permite HTTP en desarrollo).

### URL del backend
Por defecto la app apunta a `http://10.0.2.2:4000` (emulador Android).

- Simulador iOS / desktop: usa `localhost:4000`
- Dispositivo físico: usa la IP de tu máquina en la red local

Se configura al compilar:
```bash
flutter run --dart-define=API_BASE_URL=http://localhost:4000 --dart-define=SOCKET_URL=http://localhost:4000
```

### Ejecutar
```bash
flutter run
```

---

## API REST

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/auth/register` | Crear cuenta (Cliente o Repartidor) |
| POST | `/api/auth/login` | Iniciar sesión → JWT |
| GET | `/api/auth/me` | Perfil + estado de suscripción |
| GET | `/api/subscriptions/plans` | Lista de planes |
| POST | `/api/subscriptions/checkout` | Crea sesión Stripe Checkout (`{ tier }`) |
| POST | `/api/subscriptions/cancel` | Cancela suscripción activa |
| POST | `/api/orders` | Crea pedido y lo despacha al tercero |
| GET | `/api/orders/mine` | Mis pedidos |
| GET | `/api/orders/:id` | Detalle de pedido |
| POST | `/api/orders/:id/cancel` | Cancela pedido |
| POST | `/api/orders/:id/assign` | Repartidor acepta pedido |
| GET | `/api/couriers/pending` | Pedidos pendientes (repartidor) |
| POST | `/api/couriers/location` | Repartidor actualiza ubicación |
| POST | `/webhook/stripe` | Webhook de Stripe (firma verificada) |

### Ejemplo de creación de pedido
```bash
curl -X POST http://localhost:4000/api/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "pickup_address": "Av. Reforma 100",
    "dropoff_address": "Col. Roma Norte",
    "pickup_lat": 19.4326, "pickup_lng": -99.1332,
    "dropoff_lat": 19.4194, "dropoff_lng": -99.1636,
    "price_cents": 2500
  }'
```

---

## WebSocket (geolocalización en tiempo real)

Eventos de **Socket.io** (requiere `token` en el handshake):

| Evento (cliente → servidor) | Descripción |
|---|---|
| `courier:location` | El repartidor publica `{ lat, lng, heading, speedKmh, orderId }` |
| `order:subscribe` | Unirse al canal `order:{id}` |
| `order:unsubscribe` | Salir del canal |
| `order:poll` | Consulta de respaldo al software de despacho externo (con ack) |

| Evento (servidor → cliente) | Descripción |
|---|---|
| `courier:location` | Posición en vivo del repartidor hacia el canal de la orden |

Flujo: el repartidor emite `courier:location` → el servidor la persiste en `courier_locations` y la reenvía a todos los clientes suscritos a esa orden → la app mueve el marcador del repartidor sobre el mapa.

---

## Despliegue gratis en Render (con PostgreSQL en Neon)

> ✅ **Ya está desplegado y funcionando:**
> - **API:** https://dispatch-api-xkii.onrender.com (`/health`, plan free de Render)
> - **Base de datos:** Neon PostgreSQL (`postgresql://...ep-super-shape-awxb8xmo-pooler...neon.tech/neondb`)
> - **Repo:** https://github.com/daje302/dispatch-api
> - **Cuentas de prueba:** `demo@dispatch.app / Demo1234!` (cliente) y `repartidor@dispatch.app / Repartidor123!` (repartidor)
> - Verificado end-to-end: registro/login, planes, creación de pedidos, asignación a repartidor y Socket.io en tiempo real.

El backend tiene un **Dockerfile** y un **render.yaml** listos para el plan gratuito. Para re-desplegar a otro espacio: cambia `https://<tu-servicio>.onrender.com` por el dominio que quieras usar.

### 1. Base de datos (Neon, gratis)
1. Regístrate en https://neon.tech y crea un proyecto.
2. Copia la **connection string** (ej. `postgresql://user:pass@ep-xxx.region.aws.neon.tech/dbname?sslmode=require`).
3. Ábrela en https://neon.tech/console → SQL y pega el contenido de `backend/src/db/schema.sql`, o en local: `DATABASE_URL="..." npm run db:init && npm run db:seed`.

### 2. API (Render, gratis)
1. Sube este proyecto a un repositorio en GitHub.
2. En https://dashboard.render.com → **New + Blueprint** → selecciona el repo.
3. Se crea el servicio `dispatch-api`; define estas variables en el Dashboard:
   - `DATABASE_URL` → la de Neon
   - `JWT_SECRET` → cualquier texto largo
   - `APP_URL` → `https://<tu-servicio>.onrender.com`
   - `STRIPE_SECRET_KEY` y `STRIPE_WEBHOOK_SECRET` → opcionales; sin ellas el registro y pedidos funcionan igual (solo las suscripciones requieren Stripe)
4. Tu API quedará en `https://<tu-servicio>.onrender.com` (con HTTPS). El health check usa `/health`.

### 3. Stripe en producción
1. `stripe login` y en el dashboard crea los **Prices** (o ejecuta el seed con las claves).
2. En Stripe → **Webhooks** → añade endpoint `https://<tu-servicio>.onrender.com/webhook/stripe` con los eventos `checkout.session.completed`, `customer.subscription.updated/deleted`, `invoice.paid`, `invoice.payment_failed`. Copia `whsec_...` a `STRIPE_WEBHOOK_SECRET`.

### 4. Apuntar la app al servidor
```bash
cd mobile
flutter run --dart-define=API_BASE_URL=https://<tu-servicio>.onrender.com \
            --dart-define=SOCKET_URL=https://<tu-servicio>.onrender.com
# para el APK del celular:
flutter build apk --debug \
  --dart-define=API_BASE_URL=https://<tu-servicio>.onrender.com \
  --dart-define=SOCKET_URL=https://<tu-servicio>.onrender.com
```

> Nota: en el plan gratuito de Render el servicio se **duerme tras 15 min de inactividad**; la primera petición tarda ~30-50s en reactivarlo. Stripe reintenta los webhooks, así que no se pierden pagos.

---

## Base de datos

Tablas principales: `users`, `plans`, `subscriptions`, `orders`, `courier_locations`.

- **users**: cuenta, rol (`CUSTOMER/COURIER/ADMIN`), nivel de suscripción, ID de cliente Stripe.
- **plans**: niveles `FREE/BASIC/PRO` con precio mensual y `stripe_price_id`.
- **subscriptions**: estado Stripe (`active/past_due/canceled`) y periodo de facturación.
- **orders**: rutas, estado y referencia externa del software de despacho.
- **courier_locations**: historial de ubicaciones para análisis y seguimiento.

---

## Siguientes pasos sugeridos

- Reemplazar los tiles de OSM por Google Maps (`google_maps_flutter`) en producción.
- Geocodificación inversa (convertir lat/lng → dirección) con un servicio como Nominatim/Google.
- Pool de repartidores y asignación automática por proximidad.
- Notificaciones push (FCM/APNs) al cambiar el estado del pedido.
- Despliegue: contenedores Docker del backend + CI/CD, y Stripe con claves de producción.
última verificación de auto-deploy con repo privado

-- =============================================================
-- DispatchMVP · Esquema PostgreSQL
-- Gestiona cuentas de usuario, niveles de suscripción, órdenes
-- de delivery y ubicaciones en tiempo real de los repartidores.
-- =============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto"; -- gen_random_uuid()

-- --- Enumeraciones --------------------------------------------

CREATE TYPE user_role AS ENUM ('CUSTOMER', 'COURIER', 'ADMIN');
CREATE TYPE plan_tier AS ENUM ('FREE', 'BASIC', 'PRO');
CREATE TYPE order_status AS ENUM (
  'PENDING',
  'DISPATCHED',
  'IN_TRANSIT',
  'DELIVERED',
  'CANCELLED'
);

-- --- Tablas ---------------------------------------------------

-- Niveles de suscripción ofrecidos por la plataforma.
CREATE TABLE plans (
  id                  SERIAL PRIMARY KEY,
  tier                plan_tier NOT NULL UNIQUE,
  name                TEXT NOT NULL,
  description         TEXT NOT NULL DEFAULT '',
  price_monthly_cents INTEGER NOT NULL DEFAULT 0,
  features            JSONB NOT NULL DEFAULT '[]',
  stripe_price_id     TEXT,               -- ID del Price en Stripe
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Cuentas de usuario (clientes y repartidores).
CREATE TABLE users (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email              TEXT NOT NULL UNIQUE,
  password_hash      TEXT NOT NULL,
  full_name          TEXT NOT NULL,
  phone              TEXT,
  role               user_role NOT NULL DEFAULT 'CUSTOMER',
  plan_tier          plan_tier NOT NULL DEFAULT 'FREE',
  stripe_customer_id TEXT UNIQUE,         -- cliente en Stripe
  stripe_pm_id       TEXT,                -- método de pago por defecto
  is_active          BOOLEAN NOT NULL DEFAULT TRUE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Suscripciones activas/periodos facturados.
CREATE TABLE subscriptions (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_id                INTEGER NOT NULL REFERENCES plans(id),
  stripe_subscription_id TEXT UNIQUE,
  status                 TEXT NOT NULL DEFAULT 'incomplete', -- estado Stripe
  current_period_start   TIMESTAMPTZ,
  current_period_end     TIMESTAMPTZ,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Órdenes de delivery.
CREATE TABLE orders (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES users(id),
  courier_id       UUID REFERENCES users(id),
  status           order_status NOT NULL DEFAULT 'PENDING',
  pickup_address   TEXT NOT NULL,
  dropoff_address  TEXT NOT NULL,
  pickup_lat       DOUBLE PRECISION NOT NULL,
  pickup_lng       DOUBLE PRECISION NOT NULL,
  dropoff_lat      DOUBLE PRECISION NOT NULL,
  dropoff_lng      DOUBLE PRECISION NOT NULL,
  price_cents      INTEGER NOT NULL DEFAULT 0,
  external_id      TEXT,                 -- ID de la orden en el software de despacho
  external_ref     TEXT,                 -- referencia/etiqueta devuelta por el tercero
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Última ubicación conocida de cada repartidor (historial).
CREATE TABLE courier_locations (
  id          BIGSERIAL PRIMARY KEY,
  courier_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lat         DOUBLE PRECISION NOT NULL,
  lng         DOUBLE PRECISION NOT NULL,
  heading     DOUBLE PRECISION NOT NULL DEFAULT 0,
  speed_kmh   DOUBLE PRECISION NOT NULL DEFAULT 0,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- --- Índices --------------------------------------------------

CREATE INDEX idx_users_email           ON users(email);
CREATE INDEX idx_orders_user           ON orders(user_id);
CREATE INDEX idx_orders_courier        ON orders(courier_id);
CREATE INDEX idx_orders_status         ON orders(status);
CREATE INDEX idx_subscriptions_user    ON subscriptions(user_id);
CREATE INDEX idx_courier_locations_usr ON courier_locations(courier_id, recorded_at DESC);

-- --- Triggers de updated_at ----------------------------------

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated        BEFORE UPDATE ON users        FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_subscriptions_updated BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_orders_updated       BEFORE UPDATE ON orders       FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- --- Seed: planes de suscripción ------------------------------

INSERT INTO plans (tier, name, description, price_monthly_cents, features) VALUES
  ('FREE',  'Gratis',   'Despachos ocasionales sin costo', 0, '["Hasta 3 despachos/mes", "Seguimiento básico"]'),
  ('BASIC', 'Básico',   'Para envíos frecuentes',           9900, '["Despachos ilimitados", "Seguimiento en tiempo real", "Soporte por email"]'),
  ('PRO',   'Profesional', 'Para negocios que envían a diario', 24900, '["Despachos ilimitados", "Seguimiento en tiempo real", "Precios preferenciales", "Soporte prioritario 24/7", "Reportes avanzados"]')
ON CONFLICT (tier) DO NOTHING;

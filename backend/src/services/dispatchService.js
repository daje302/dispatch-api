import { config } from '../config.js';

/**
 * Capa de integración con software de despacho de terceros.
 *
 * Cada proveedor implementa la misma interfaz:
 *   createTask({ pickup, dropoff, metadata }) -> { externalId, ref }
 *   getTaskStatus(externalId)                 -> { status, courierLat, courierLng }
 *   cancelTask(externalId)                    -> { externalId, cancelled: true }
 *
 * Configura el proveedor con la variable DISPATCH_PROVIDER:
 *   - 'mock':   simula el despacho localmente (desarrollo)
 *   - 'rest':   conecta a cualquier API REST de despacho (Onfleet, Shipbubble,
 *               DispatchTrack, Bringg, etc.) mediante DISPATCH_BASE_URL y
 *               DISPATCH_API_KEY. Ajusta los endpoints según el proveedor.
 */

const MOCK_STATUSES = ['DISPATCHED', 'IN_TRANSIT', 'DELIVERED'];

function createMockProvider() {
  let counter = 0;
  return {
    name: 'mock',
    async createTask({ pickup, dropoff, metadata = {} }) {
      counter += 1;
      const externalId = `MOCK-${Date.now()}-${counter}`;
      console.log('[dispatch:mock] Nueva tarea', externalId, pickup, dropoff);
      return { externalId, ref: `mock-${counter}` };
    },
    async getTaskStatus(externalId) {
      // Simula un repartidor que avanza en línea recta hacia el destino.
      const fakeCourier = { courierLat: 19.4, courierLng: -99.16 };
      return {
        status: MOCK_STATUSES[Math.floor(Math.random() * MOCK_STATUSES.length)],
        courierLat: fakeCourier.courierLat,
        courierLng: fakeCourier.courierLng,
      };
    },
    async cancelTask(externalId) {
      console.log('[dispatch:mock] Cancelando tarea', externalId);
      return { externalId, cancelled: true };
    },
  };
}

/**
 * Proveedor REST genérico.
 * Adapta los endpoints al proveedor real (modifica los paths según su API).
 * Ejemplo típico: POST /tasks, GET /tasks/:id, PUT /tasks/:id/cancel.
 */
function createRestProvider() {
  const base = config.dispatch.baseUrl.replace(/\/$/, '');
  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Basic ${Buffer.from(config.dispatch.apiKey + ':').toString('base64')}`,
  };

  async function request(path, options = {}) {
    const res = await fetch(`${base}${path}`, { ...options, headers });
    if (!res.ok) {
      throw new Error(`[dispatch:rest] ${res.status} ${await res.text()}`);
    }
    return res.json();
  }

  return {
    name: config.dispatch.provider,
    async createTask({ pickup, dropoff, metadata = {} }) {
      const body = await request('/tasks', {
        method: 'POST',
        body: JSON.stringify({
          destination: {
            address: dropoff.address,
            lat: dropoff.lat,
            lng: dropoff.lng,
            notes: dropoff.notes,
          },
          pickup: {
            address: pickup.address,
            lat: pickup.lat,
            lng: pickup.lng,
          },
          metadata,
        }),
      });
      return { externalId: body.id || body.taskId, ref: body.ref || body.notes };
    },
    async getTaskStatus(externalId) {
      const body = await request(`/tasks/${externalId}`);
      return {
        status: body.status,
        courierLat: body.courier?.location?.lat ?? body.latitude,
        courierLng: body.courier?.location?.lng ?? body.longitude,
      };
    },
    async cancelTask(externalId) {
      await request(`/tasks/${externalId}/cancel`, { method: 'PUT' });
      return { externalId, cancelled: true };
    },
  };
}

export function getDispatchProvider() {
  const provider = config.dispatch.provider;
  if (provider === 'rest' || provider === 'onfleet') return createRestProvider();
  return createMockProvider();
}
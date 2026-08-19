import { db } from '../db/index.js';
import { ApiError } from '../middleware/error.js';
import { getDispatchProvider } from './dispatchService.js';

const provider = getDispatchProvider();

export async function createOrder(userId, data) {
  const required = [
    'pickup_address',
    'dropoff_address',
    'pickup_lat',
    'pickup_lng',
    'dropoff_lat',
    'dropoff_lng',
  ];
  for (const field of required) {
    if (data[field] === undefined || data[field] === null || data[field] === '') {
      throw new ApiError(400, `Campo requerido: ${field}`);
    }
  }

  // Despacho en el software de terceros.
  const task = await provider.createTask({
    pickup: {
      address: data.pickup_address,
      lat: data.pickup_lat,
      lng: data.pickup_lng,
    },
    dropoff: {
      address: data.dropoff_address,
      lat: data.dropoff_lat,
      lng: data.dropoff_lng,
    },
    metadata: { userId },
  });

  const { rows } = await db.query(
    `INSERT INTO orders
       (user_id, pickup_address, dropoff_address, pickup_lat, pickup_lng,
        dropoff_lat, dropoff_lng, price_cents, external_id, external_ref)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING *`,
    [
      userId,
      data.pickup_address,
      data.dropoff_address,
      data.pickup_lat,
      data.pickup_lng,
      data.dropoff_lat,
      data.dropoff_lng,
      data.price_cents || 0,
      task.externalId,
      task.ref,
    ]
  );
  return rows[0];
}

export async function listMyOrders(userId) {
  const { rows } = await db.query(
    `SELECT o.*, c.full_name AS courier_name
     FROM orders o
     LEFT JOIN users c ON c.id = o.courier_id
     WHERE o.user_id = $1
     ORDER BY o.created_at DESC`,
    [userId]
  );
  return rows;
}

export async function getOrderById(orderId, userId) {
  const { rows } = await db.query(
    `SELECT o.*, c.full_name AS courier_name, c.phone AS courier_phone
     FROM orders o
     LEFT JOIN users c ON c.id = o.courier_id
     WHERE o.id = $1 AND o.user_id = $2`,
    [orderId, userId]
  );
  if (rows.length === 0) throw new ApiError(404, 'Orden no encontrada');
  return rows[0];
}

export async function updateOrderStatus(orderId, status) {
  const allowed = ['PENDING', 'DISPATCHED', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED'];
  if (!allowed.includes(status)) throw new ApiError(400, 'Estado inválido');

  const { rows } = await db.query(
    'UPDATE orders SET status = $2, updated_at = NOW() WHERE id = $1 RETURNING *',
    [orderId, status]
  );
  if (rows.length === 0) throw new ApiError(404, 'Orden no encontrada');
  return rows[0];
}

export async function cancelOrder(orderId, userId) {
  const order = await getOrderById(orderId, userId);
  if (['DELIVERED', 'CANCELLED'].includes(order.status)) {
    throw new ApiError(400, `La orden ya está ${order.status.toLowerCase()}`);
  }
  if (order.external_id) {
    try {
      await provider.cancelTask(order.external_id);
    } catch (err) {
      console.warn('[order] No se pudo cancelar en el proveedor externo:', err.message);
    }
  }
  return updateOrderStatus(orderId, 'CANCELLED');
}

export async function listPendingCourierOrders() {
  const { rows } = await db.query(
    `SELECT * FROM orders WHERE status = 'PENDING' ORDER BY created_at ASC`
  );
  return rows;
}

export async function assignOrderToCourier(orderId, courierId) {
  const { rows } = await db.query(
    `UPDATE orders SET courier_id = $2, status = 'DISPATCHED', updated_at = NOW()
     WHERE id = $1 AND status = 'PENDING' RETURNING *`,
    [orderId, courierId]
  );
  if (rows.length === 0) throw new ApiError(409, 'La orden ya fue asignada');
  return rows[0];
}
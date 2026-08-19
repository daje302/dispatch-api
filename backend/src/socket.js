import { Server } from 'socket.io';
import jwt from 'jsonwebtoken';
import { config } from './config.js';
import { db } from './db/index.js';
import { getDispatchProvider } from './services/dispatchService.js';

const provider = getDispatchProvider();

/**
 * WebSocket para geolocalización en tiempo real.
 *
 *  - COURIER emite:      courier:location  { lat, lng, heading, speedKmh, orderId }
 *  - Servidor persiste y reenvía a clientes del canal `order:{orderId}`.
 *  - Cualquier cliente puede pedir: order:subscribe { orderId }
 *  - El servidor consulta el proveedor de despacho externo como respaldo
 *    (order:poll) para sincronizar el estado y ubicación oficiales.
 */
export function attachSocket(server) {
  const io = new Server(server, {
    cors: { origin: '*' },
  });

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token) return next(new Error('auth_required'));
    try {
      const payload = jwt.verify(token, config.jwtSecret);
      socket.data.userId = payload.sub;
      next();
    } catch {
      next(new Error('auth_invalid'));
    }
  });

  io.on('connection', (socket) => {
    const userId = socket.data.userId;
    console.log('[socket] conectado', userId);

    socket.on('courier:location', async (payload) => {
      const { lat, lng, heading = 0, speedKmh = 0, orderId } = payload || {};
      if (typeof lat !== 'number' || typeof lng !== 'number') return;

      await db.query(
        `INSERT INTO courier_locations (courier_id, lat, lng, heading, speed_kmh)
         VALUES ($1, $2, $3, $4, $5)`,
        [userId, lat, lng, heading, speedKmh]
      );

      if (orderId) {
        io.to(`order:${orderId}`).emit('courier:location', {
          orderId,
          lat,
          lng,
          heading,
          speedKmh,
          recordedAt: new Date().toISOString(),
        });
      }
    });

    socket.on('order:subscribe', (payload) => {
      const orderId = payload?.orderId;
      if (!orderId) return;
      socket.join(`order:${orderId}`);
      console.log('[socket] suscripción a orden', orderId, 'por', userId);
    });

    socket.on('order:unsubscribe', (payload) => {
      if (payload?.orderId) socket.leave(`order:${payload.orderId}`);
    });

    // Consulta de respaldo al proveedor de despacho (sincronización manual).
    socket.on('order:poll', async (payload, ack) => {
      const orderId = payload?.orderId;
      if (!orderId) return;
      const { rows } = await db.query(
        'SELECT external_id, status FROM orders WHERE id = $1',
        [orderId]
      );
      if (rows.length === 0) return ack?.({ error: 'order_not_found' });

      let location = null;
      if (rows[0].external_id) {
        try {
          location = await provider.getTaskStatus(rows[0].external_id);
        } catch (err) {
          console.warn('[socket] poll fallido:', err.message);
        }
      }
      ack?.({ status: rows[0].status, location });
    });

    socket.on('disconnect', () => {
      console.log('[socket] desconectado', userId);
    });
  });

  return io;
}
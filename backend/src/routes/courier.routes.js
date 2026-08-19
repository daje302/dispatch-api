import { Router } from 'express';
import { authenticate, authorize } from '../middleware/auth.js';
import { db } from '../db/index.js';
import { listPendingCourierOrders } from '../services/orderService.js';

const router = Router();

router.get(
  '/pending',
  authenticate,
  authorize('COURIER'),
  async (req, res, next) => {
    try {
      res.json({ orders: await listPendingCourierOrders() });
    } catch (err) {
      next(err);
    }
  }
);

// El repartidor actualiza su ubicación (también se hace vía WebSocket).
router.post(
  '/location',
  authenticate,
  authorize('COURIER'),
  async (req, res, next) => {
    try {
      const { lat, lng, heading = 0, speedKmh = 0 } = req.body;
      if (typeof lat !== 'number' || typeof lng !== 'number') {
        return res.status(400).json({ error: 'lat y lng son requeridos' });
      }
      await db.query(
        `INSERT INTO courier_locations (courier_id, lat, lng, heading, speed_kmh)
         VALUES ($1, $2, $3, $4, $5)`,
        [req.user.id, lat, lng, heading, speedKmh]
      );
      res.status(201).json({ ok: true });
    } catch (err) {
      next(err);
    }
  }
);

export default router;
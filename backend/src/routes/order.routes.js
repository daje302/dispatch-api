import { Router } from 'express';
import { authenticate, authorize } from '../middleware/auth.js';
import {
  createOrder,
  listMyOrders,
  getOrderById,
  cancelOrder,
  assignOrderToCourier,
} from '../services/orderService.js';

const router = Router();

router.post('/', authenticate, async (req, res, next) => {
  try {
    const order = await createOrder(req.user.id, req.body);
    res.status(201).json({ order });
  } catch (err) {
    next(err);
  }
});

router.get('/mine', authenticate, async (req, res, next) => {
  try {
    res.json({ orders: await listMyOrders(req.user.id) });
  } catch (err) {
    next(err);
  }
});

router.get('/:id', authenticate, async (req, res, next) => {
  try {
    res.json({ order: await getOrderById(req.params.id, req.user.id) });
  } catch (err) {
    next(err);
  }
});

router.post('/:id/cancel', authenticate, async (req, res, next) => {
  try {
    res.json({ order: await cancelOrder(req.params.id, req.user.id) });
  } catch (err) {
    next(err);
  }
});

router.post(
  '/:id/assign',
  authenticate,
  authorize('COURIER'),
  async (req, res, next) => {
    try {
      res.json({
        order: await assignOrderToCourier(req.params.id, req.user.id),
      });
    } catch (err) {
      next(err);
    }
  }
);

export default router;
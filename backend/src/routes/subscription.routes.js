import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import {
  listPlans,
  createCheckoutSession,
  cancelSubscription,
} from '../services/stripeService.js';

const router = Router();

router.get('/plans', async (req, res, next) => {
  try {
    res.json({ plans: await listPlans() });
  } catch (err) {
    next(err);
  }
});

router.post('/checkout', authenticate, async (req, res, next) => {
  try {
    const { tier } = req.body;
    if (!tier) return res.status(400).json({ error: 'Campo requerido: tier' });
    const session = await createCheckoutSession(req.user, tier);
    res.json(session);
  } catch (err) {
    next(err);
  }
});

router.post('/cancel', authenticate, async (req, res, next) => {
  try {
    res.json(await cancelSubscription(req.user));
  } catch (err) {
    next(err);
  }
});

export default router;
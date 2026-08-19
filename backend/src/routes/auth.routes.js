import { Router } from 'express';
import { register, login, getProfile } from '../services/authService.js';
import { authenticate } from '../middleware/auth.js';

const router = Router();

router.post('/register', async (req, res, next) => {
  try {
    const result = await register(req.body);
    res.status(201).json(result);
  } catch (err) {
    next(err);
  }
});

router.post('/login', async (req, res, next) => {
  try {
    const result = await login(req.body);
    res.json(result);
  } catch (err) {
    next(err);
  }
});

router.get('/me', authenticate, async (req, res, next) => {
  try {
    res.json(await getProfile(req.user.id));
  } catch (err) {
    next(err);
  }
});

export default router;
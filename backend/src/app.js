import express from 'express';
import cors from 'cors';
import authRoutes from './routes/auth.routes.js';
import subscriptionRoutes from './routes/subscription.routes.js';
import orderRoutes from './routes/order.routes.js';
import courierRoutes from './routes/courier.routes.js';
import webhookRoutes from './routes/webhook.routes.js';
import { notFound, errorHandler } from './middleware/error.js';

export function createApp() {
  const app = express();

  app.use(cors());

  // Webhooks de Stripe requieren el body en crudo para verificar la firma.
  // Deben registrarse ANTES de express.json() para que el body no se consuma.
  app.use('/webhook', express.raw({ type: 'application/json' }), webhookRoutes);

  app.use(express.json());

  app.get('/health', (req, res) => {
    res.json({ status: 'ok', uptime: process.uptime() });
  });

  app.use('/api/auth', authRoutes);
  app.use('/api/subscriptions', subscriptionRoutes);
  app.use('/api/orders', orderRoutes);
  app.use('/api/couriers', courierRoutes);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}
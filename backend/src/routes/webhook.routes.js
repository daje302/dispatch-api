import { Router } from 'express';
import Stripe from 'stripe';
import { config } from '../config.js';
import { handleWebhookEvent } from '../services/stripeService.js';

const router = Router();
const stripe = config.stripe.secretKey ? new Stripe(config.stripe.secretKey) : null;

// Este body se lee en crudo (express.raw) para verificar la firma.
router.post('/stripe', async (req, res) => {
  if (!stripe || !config.stripe.webhookSecret) {
    return res.status(503).send('Stripe no configurado');
  }
  const sig = req.headers['stripe-signature'];
  let event;
  try {
    event = stripe.webhooks.constructEvent(
      req.body,
      sig,
      config.stripe.webhookSecret
    );
  } catch (err) {
    console.error('[webhook] Firma inválida:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  try {
    await handleWebhookEvent(event);
  } catch (err) {
    console.error('[webhook] Error procesando evento:', err.message);
    return res.status(500).send('Webhook processing error');
  }

  res.json({ received: true });
});

export default router;
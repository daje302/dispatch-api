import Stripe from 'stripe';
import { db } from '../db/index.js';
import { config } from '../config.js';
import { ApiError } from '../middleware/error.js';

// Si no hay clave configurada, Stripe queda desactivado (el resto funciona).
const stripe = config.stripe.secretKey ? new Stripe(config.stripe.secretKey) : null;

function requireStripe() {
  if (!stripe) {
    throw new ApiError(
      503,
      'Stripe no está configurado (falta STRIPE_SECRET_KEY en el entorno)'
    );
  }
  return stripe;
}

export async function listPlans() {
  const { rows } = await db.query(
    `SELECT id, tier, name, description, price_monthly_cents, features, stripe_price_id
     FROM plans WHERE is_active = TRUE ORDER BY price_monthly_cents ASC`
  );
  return rows;
}

export async function createCheckoutSession(user, tier) {
  const { rows } = await db.query(
    'SELECT * FROM plans WHERE tier = $1 AND is_active = TRUE',
    [tier]
  );
  if (rows.length === 0) throw new ApiError(404, 'Plan no encontrado');
  const plan = rows[0];
  if (plan.price_monthly_cents === 0) {
    throw new ApiError(400, 'El plan gratuito no requiere suscripción');
  }
  if (!plan.stripe_price_id) {
    throw new ApiError(409, 'El plan aún no tiene un precio configurado en Stripe (ejecuta el seed)');
  }

  const session = await requireStripe().checkout.sessions.create({
    mode: 'subscription',
    customer: user.stripe_customer_id,
    line_items: [{ price: plan.stripe_price_id, quantity: 1 }],
    success_url: `${config.appUrl}/checkout/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${config.appUrl}/checkout/cancel`,
    metadata: { user_id: user.id, tier },
    subscription_data: {
      metadata: { user_id: user.id, tier },
    },
  });

  return { url: session.url, sessionId: session.id };
}

export async function cancelSubscription(user) {
  const { rows } = await db.query(
    `SELECT stripe_subscription_id FROM subscriptions
     WHERE user_id = $1 AND status = 'active'
     ORDER BY created_at DESC LIMIT 1`,
    [user.id]
  );
  if (rows.length === 0) throw new ApiError(404, 'No hay suscripción activa');

  const sub = await requireStripe().subscriptions.cancel(rows[0].stripe_subscription_id);
  await db.query(
    `UPDATE subscriptions SET status = $2, updated_at = NOW()
     WHERE stripe_subscription_id = $1`,
    [sub.id, sub.status]
  );
  await db.query(
    'UPDATE users SET plan_tier = $2 WHERE id = $1',
    [user.id, 'FREE']
  );
  return { status: sub.status };
}

/**
 * Procesa los eventos de webhook de Stripe para mantener sincronizadas
 * las suscripciones y el nivel del usuario en nuestra base de datos.
 */
export async function handleWebhookEvent(event) {
  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object;
      if (session.mode !== 'subscription') break;
      const { user_id } = session.metadata || {};
      const subId = session.subscription;
      const tier = session.metadata?.tier;
      if (user_id && subId && tier) {
        await upsertSubscription(user_id, subId, tier, session.customer);
      }
      break;
    }
    case 'customer.subscription.created':
    case 'customer.subscription.updated': {
      const sub = event.data.object;
      const userId = sub.metadata?.user_id;
      const price = sub.items?.data?.[0]?.price;
      const tier = price?.metadata?.tier || price?.metadata?.plan_id;
      if (userId && sub.id) {
        await upsertSubscription(userId, sub.id, tier, sub.customer);
      }
      break;
    }
    case 'customer.subscription.deleted': {
      const sub = event.data.object;
      await db.query(
        "UPDATE subscriptions SET status = 'canceled', updated_at = NOW() WHERE stripe_subscription_id = $1",
        [sub.id]
      );
      const userId = sub.metadata?.user_id;
      if (userId) {
        await db.query(
          'UPDATE users SET plan_tier = $2, updated_at = NOW() WHERE id = $1',
          [userId, 'FREE']
        );
      }
      break;
    }
    case 'invoice.payment_failed': {
      const invoice = event.data.object;
      const subId = invoice.subscription;
      if (subId) {
        await db.query(
          "UPDATE subscriptions SET status = 'past_due', updated_at = NOW() WHERE stripe_subscription_id = $1",
          [subId]
        );
      }
      break;
    }
    case 'invoice.paid': {
      const invoice = event.data.object;
      const subId = invoice.subscription;
      if (subId) {
        await db.query(
          "UPDATE subscriptions SET status = 'active', updated_at = NOW() WHERE stripe_subscription_id = $1",
          [subId]
        );
      }
      break;
    }
    default:
      break;
  }
  return { received: true };
}

async function upsertSubscription(userId, stripeSubId, tier, stripeCustomerId) {
  const planRow = await db.query('SELECT id, tier FROM plans WHERE tier = $1', [
    tier || 'BASIC',
  ]);
  const planId = planRow.rows[0]?.id;

  const sub = await requireStripe().subscriptions.retrieve(stripeSubId);

  await db.query(
    `INSERT INTO subscriptions
       (user_id, plan_id, stripe_subscription_id, status, current_period_start, current_period_end)
     VALUES ($1, $2, $3, $4, $5, $6)
     ON CONFLICT (stripe_subscription_id) DO UPDATE SET
       plan_id = EXCLUDED.plan_id,
       status = EXCLUDED.status,
       current_period_start = EXCLUDED.current_period_start,
       current_period_end = EXCLUDED.current_period_end,
       updated_at = NOW()`,
    [
      userId,
      planId,
      stripeSubId,
      sub.status,
      sub.current_period_start ? new Date(sub.current_period_start * 1000) : null,
      sub.current_period_end ? new Date(sub.current_period_end * 1000) : null,
    ]
  );

  await db.query(
    'UPDATE users SET plan_tier = $2, stripe_customer_id = COALESCE(stripe_customer_id, $3), updated_at = NOW() WHERE id = $1',
    [userId, tier, stripeCustomerId]
  );
}
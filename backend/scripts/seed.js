import bcrypt from 'bcryptjs';
import Stripe from 'stripe';
import { db } from '../src/db/index.js';
import { config } from '../src/config.js';

const stripe = new Stripe(config.stripe.secretKey);

const looksLikePlaceholder = (key) => key.includes('xxxx') || key.includes('pk_test_xxx');

async function syncStripePrices() {
  if (looksLikePlaceholder(config.stripe.secretKey)) {
    console.warn('⚠ SKIP Stripe: usa una clave sk_test real para crear los prices.');
    return;
  }
  const { rows: plans } = await db.query(
    "SELECT id, tier, price_monthly_cents FROM plans WHERE tier <> 'FREE'"
  );
  for (const plan of plans) {
    if (plan.stripe_price_id) continue;
    try {
      const price = await stripe.prices.create({
        currency: 'usd',
        unit_amount: plan.price_monthly_cents,
        recurring: { interval: 'month' },
        product_data: {
          name: `Plan ${plan.tier}`,
          metadata: { plan_id: String(plan.id), tier: plan.tier },
        },
      });
      await db.query('UPDATE plans SET stripe_price_id = $1 WHERE id = $2', [
        price.id,
        plan.id,
      ]);
      console.log(`✔ Price creado para ${plan.tier}: ${price.id}`);
    } catch (err) {
      console.warn(`✖ No se pudo crear el price de ${plan.tier}: ${err.message}`);
    }
  }
}

async function seedUser() {
  const email = 'demo@dispatch.app';
  const { rows } = await db.query('SELECT id FROM users WHERE email = $1', [email]);
  if (rows.length > 0) return;

  const passwordHash = await bcrypt.hash('Demo1234!', 10);
  await db.query(
    `INSERT INTO users (email, password_hash, full_name, phone, role, plan_tier)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [email, passwordHash, 'Usuario Demo', '+525500000000', 'CUSTOMER', 'FREE']
  );
  console.log(`✔ Usuario demo creado: ${email} / Demo1234!`);
}

try {
  await syncStripePrices();
  await seedUser();
  console.log('✔ Seed completado.');
} catch (err) {
  console.error('✖ Error en seed:', err.message);
  process.exitCode = 1;
} finally {
  await db.pool.end();
}
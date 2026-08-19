import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import Stripe from 'stripe';
import { db } from '../db/index.js';
import { config } from '../config.js';
import { ApiError } from '../middleware/error.js';

const stripe = config.stripe.secretKey ? new Stripe(config.stripe.secretKey) : null;

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function signToken(userId) {
  return jwt.sign({ sub: userId }, config.jwtSecret, {
    expiresIn: config.jwtExpiresIn,
  });
}

export async function register({ email, password, fullName, phone, role }) {
  if (!EMAIL_RE.test(email)) throw new ApiError(400, 'Email inválido');
  if (!password || password.length < 8) {
    throw new ApiError(400, 'La contraseña debe tener al menos 8 caracteres');
  }
  if (!fullName) throw new ApiError(400, 'El nombre es requerido');

  const normalized = email.toLowerCase().trim();
  const existing = await db.query('SELECT id FROM users WHERE email = $1', [
    normalized,
  ]);
  if (existing.rows.length > 0) {
    throw new ApiError(409, 'El email ya está registrado');
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const userRole = ['CUSTOMER', 'COURIER'].includes(role) ? role : 'CUSTOMER';

  // El cliente se crea en Stripe para habilitar cobros recurrentes.
  // En desarrollo sin claves reales, se omite sin bloquear el registro.
  let stripeCustomerId = null;
  try {
    const stripeCustomer = await stripe.customers.create({
      email: normalized,
      name: fullName,
      metadata: { app: 'dispatch-mvp' },
    });
    stripeCustomerId = stripeCustomer.id;
  } catch (err) {
    console.warn('[stripe] No se pudo crear el cliente (continúa sin Stripe):', err.message);
  }

  const { rows } = await db.query(
    `INSERT INTO users (email, password_hash, full_name, phone, role, stripe_customer_id)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, email, full_name, phone, role, plan_tier`,
    [normalized, passwordHash, fullName, phone || null, userRole, stripeCustomerId]
  );

  return { user: rows[0], token: signToken(rows[0].id) };
}

export async function login({ email, password }) {
  const normalized = email.toLowerCase().trim();
  const { rows } = await db.query(
    'SELECT * FROM users WHERE email = $1',
    [normalized]
  );
  if (rows.length === 0) {
    throw new ApiError(401, 'Credenciales inválidas');
  }
  const user = rows[0];
  if (!user.is_active) throw new ApiError(403, 'Cuenta desactivada');
  const ok = await bcrypt.compare(password, user.password_hash);
  if (!ok) throw new ApiError(401, 'Credenciales inválidas');

  const safe = {
    id: user.id,
    email: user.email,
    full_name: user.full_name,
    phone: user.phone,
    role: user.role,
    plan_tier: user.plan_tier,
  };
  return { user: safe, token: signToken(user.id) };
}

export async function getProfile(userId) {
  const { rows } = await db.query(
    `SELECT u.id, u.email, u.full_name, u.phone, u.role, u.plan_tier,
            s.status AS subscription_status,
            s.current_period_end
     FROM users u
     LEFT JOIN subscriptions s ON s.user_id = u.id AND s.status = 'active'
     WHERE u.id = $1`,
    [userId]
  );
  if (rows.length === 0) throw new ApiError(404, 'Usuario no encontrado');
  return rows[0];
}
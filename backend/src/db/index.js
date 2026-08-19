import pg from 'pg';
import { config } from '../config.js';

const { Pool } = pg;

// Habilitar SSL cuando la BD lo pida (Neon, Supabase, etc.).
const needsSsl =
  config.databaseUrl.includes('sslmode=require') ||
  config.databaseUrl.includes('sslmode=verify-full') ||
  process.env.PGSSL === 'true';

export const pool = new Pool({
  connectionString: config.databaseUrl,
  ...(needsSsl ? { ssl: { rejectUnauthorized: false } } : {}),
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  console.error('[db] Error inesperado en el pool:', err.message);
});

export async function query(text, params) {
  const start = Date.now();
  const res = await pool.query(text, params);
  const duration = Date.now() - start;
  if (config.env !== 'production') {
    console.log('[db]', text.slice(0, 80), duration + 'ms');
  }
  return res;
}

export const db = {
  query,
  pool,
};
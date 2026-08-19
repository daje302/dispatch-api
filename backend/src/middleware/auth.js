import jwt from 'jsonwebtoken';
import { config } from '../config.js';
import { db } from '../db/index.js';

export async function authenticate(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ error: 'Token requerido' });
  }

  let payload;
  try {
    payload = jwt.verify(token, config.jwtSecret);
  } catch {
    return res.status(401).json({ error: 'Token inválido o expirado' });
  }

  const { rows } = await db.query(
    'SELECT id, email, full_name, phone, role, plan_tier FROM users WHERE id = $1',
    [payload.sub]
  );
  if (rows.length === 0) {
    return res.status(401).json({ error: 'Usuario no encontrado' });
  }

  req.user = rows[0];
  next();
}

export function authorize(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Permisos insuficientes' });
    }
    next();
  };
}
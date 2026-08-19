import 'dotenv/config';

function required(name, fallback = null) {
  const value = process.env[name] ?? fallback;
  if (value === null || value === undefined || value === '') {
    throw new Error(`Falta la variable de entorno ${name}`);
  }
  return value;
}

export const config = {
  env: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 4000),
  jwtSecret: required('JWT_SECRET'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  databaseUrl: process.env.DATABASE_URL || 'postgresql://dispatch:dispatch123@localhost:5432/dispatch_db',
  appUrl: process.env.APP_URL || 'http://localhost:4000',
  stripe: {
    secretKey: process.env.STRIPE_SECRET_KEY || '',
    webhookSecret: process.env.STRIPE_WEBHOOK_SECRET || '',
    priceBasic: process.env.STRIPE_PRICE_BASIC || null,
    pricePro: process.env.STRIPE_PRICE_PRO || null,
  },
  dispatch: {
    provider: process.env.DISPATCH_PROVIDER || 'mock',
    baseUrl: process.env.DISPATCH_BASE_URL || '',
    apiKey: process.env.DISPATCH_API_KEY || '',
  },
};

export const isProd = config.env === 'production';
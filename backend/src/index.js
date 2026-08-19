import { createServer } from 'node:http';
import { createApp } from './app.js';
import { attachSocket } from './socket.js';
import { config } from './config.js';
import { db } from './db/index.js';

async function bootstrap() {
  await db.pool.query('SELECT 1');
  console.log('✔ Conexión a PostgreSQL establecida');

  const app = createApp();
  const server = createServer(app);
  attachSocket(server);

  server.listen(config.port, () => {
    console.log(`✔ API escuchando en http://localhost:${config.port}`);
    console.log(`  Proveedor de despacho: ${config.dispatch.provider}`);
  });
}

bootstrap().catch((err) => {
  console.error('✖ No se pudo iniciar el servidor:', err.message);
  process.exit(1);
});
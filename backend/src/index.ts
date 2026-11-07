import { loadConfig } from './config.js';
import { createPool } from './db.js';
import { LocalKms } from './kms.js';
import { assembleServices, buildServer } from './http/server.js';

async function main() {
  const config = loadConfig();
  const db = createPool(config);
  const kms = new LocalKms(config.KMS_MASTER_KEY_B64);
  const services = assembleServices(config, db, kms);
  await services.attachments.ensureBucket().catch((err) => {
    console.warn('S3 bucket pre-flight failed:', err);
  });
  const server = await buildServer(config, services);
  await server.listen({ port: config.PORT, host: '0.0.0.0' });
  const shutdown = async (signal: string) => {
    server.log.info({ signal }, 'shutting down');
    await server.close();
    await db.end();
    process.exit(0);
  };
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

main().catch((err) => {
  console.error('Fatal boot error:', err);
  process.exit(1);
});

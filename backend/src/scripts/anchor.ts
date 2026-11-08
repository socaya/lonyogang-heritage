import { loadConfig } from '../config.js';
import { createPool } from '../db.js';
import { createKeyStore } from '../services/keystore.js';
import { assembleServices } from '../http/server.js';

/** Operator cron entry point. Walks every account's audit chain, verifies it
 *  and anchors the tip hash through the configured notary. Intended for a
 *  weekly schedule (`0 2 * * SUN`). */
async function main() {
  const config = loadConfig();
  const pool = createPool(config);
  const kms = createKeyStore({
    provider: config.KMS_PROVIDER,
    localMasterKeyB64: config.KMS_MASTER_KEY_B64,
    awsKeyId: config.KMS_AWS_KEY_ID,
    awsRegion: config.KMS_AWS_REGION,
  });
  const services = assembleServices(config, pool, kms);
  try {
    const summary = await services.transparency.anchorAllAccounts();
    process.stdout.write(
      `Anchored ${summary.anchored} accounts (${summary.verified} verified)\n`,
    );
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import sss from 'shamirs-secret-sharing';
import type { Db } from '../db.js';
import { queryOne } from '../db.js';
import type { KeyStore } from './keystore.js';
import type { AuditService } from './audit.js';

/**
 * Server-assisted recovery. Splits the user's **vault wrap key** (not the
 * passphrase) into three Shamir shares with threshold 2. One share lives on
 * the primary device, one is KMS-sealed on the server, one is handed to the
 * user as a printable sheet. Reconstructing the wrap key requires any two
 * shares — losing a single share is survivable.
 */
export class RecoveryService {
  constructor(
    private readonly db: Db,
    private readonly kms: KeyStore,
    private readonly audit: AuditService,
  ) {}

  /** Generates a fresh wrap key, splits it, stores the server share and the
   *  printable share's hash, and returns the device + printable shares so the
   *  client can distribute them. The server never retains the wrap key itself. */
  async enroll(accountId: string): Promise<{
    wrapKey: string;
    deviceShare: string;
    printableShare: string;
  }> {
    const wrapKey = randomBytes(32);
    const shares = sss.split(wrapKey, { shares: 3, threshold: 2 });
    const [deviceShare, serverShare, printableShare] = shares;
    if (!deviceShare || !serverShare || !printableShare) {
      throw new Error('Shamir split did not produce three shares');
    }
    const sealedServerShare = await this.kms.seal(serverShare, Buffer.from(accountId, 'utf8'));
    const printableHash = createHash('sha256').update(printableShare).digest();
    await this.db.query(
      `insert into vault_envelopes (account_id, wrapped_content_key, server_recovery_share, recovery_sheet_hash, version)
       values ($1, $2, $3, $4, 1)
       on conflict (account_id) do update
         set server_recovery_share = excluded.server_recovery_share,
             recovery_sheet_hash = excluded.recovery_sheet_hash,
             rotated_at = now()`,
      [accountId, Buffer.alloc(0), sealedServerShare, printableHash],
    );
    await this.audit.record({
      accountId,
      actor: { kind: 'user', id: accountId },
      action: 'recovery.enrolled',
      resource: `account:${accountId}`,
    });
    return {
      wrapKey: wrapKey.toString('base64'),
      deviceShare: deviceShare.toString('base64'),
      printableShare: printableShare.toString('base64'),
    };
  }

  /** Redeems the server share after re-authentication. The caller must prove
   *  possession of the printable share by supplying it; the server verifies
   *  its hash against the stored one. Returns the server's share so the
   *  client can reconstruct the wrap key locally. */
  async redeem(input: {
    accountId: string;
    printableShare: string;
  }): Promise<{ serverShare: string }> {
    const row = await queryOne<{ server_recovery_share: Buffer; recovery_sheet_hash: Buffer }>(
      this.db,
      `select server_recovery_share, recovery_sheet_hash
         from vault_envelopes where account_id = $1`,
      [input.accountId],
    );
    if (!row || !row.server_recovery_share || !row.recovery_sheet_hash) {
      throw new Error('No recovery material is enrolled for this account');
    }
    const suppliedBuf = Buffer.from(input.printableShare, 'base64');
    const suppliedHash = createHash('sha256').update(suppliedBuf).digest();
    if (suppliedHash.length !== row.recovery_sheet_hash.length ||
        !timingSafeEqual(suppliedHash, row.recovery_sheet_hash)) {
      await this.audit.record({
        accountId: input.accountId,
        actor: { kind: 'user', id: input.accountId },
        action: 'recovery.redeem_failed',
        resource: `account:${input.accountId}`,
      });
      throw new Error('Printable share did not match');
    }
    const serverShare = await this.kms.unseal(
      row.server_recovery_share,
      Buffer.from(input.accountId, 'utf8'),
    );
    await this.audit.record({
      accountId: input.accountId,
      actor: { kind: 'user', id: input.accountId },
      action: 'recovery.redeemed',
      resource: `account:${input.accountId}`,
    });
    return { serverShare: serverShare.toString('base64') };
  }

  /** For tests: reconstructs the wrap key from any two base64 shares. */
  static combine(shares: string[]): Buffer {
    const bufs = shares.map((s) => Buffer.from(s, 'base64'));
    return sss.combine(bufs);
  }
}

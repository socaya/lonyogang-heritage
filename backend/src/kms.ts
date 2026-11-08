import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

/**
 * Local KMS stand-in: AES-256-GCM envelope encryption using a single master
 * key loaded from configuration. In production this would be backed by a
 * cloud KMS/HSM; the interface is the same so services can be ported without
 * rewriting call sites.
 */
export class LocalKms {
  private readonly masterKey: Buffer;

  constructor(masterKeyB64: string) {
    const key = Buffer.from(masterKeyB64, 'base64');
    if (key.length !== 32) {
      throw new Error('KMS master key must decode to exactly 32 bytes');
    }
    this.masterKey = key;
  }

  /** Encrypts plaintext and returns a self-describing envelope (nonce || tag || ct). */
  seal(plaintext: Buffer | Uint8Array, aad: Buffer | Uint8Array = Buffer.alloc(0)): Buffer {
    const nonce = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.masterKey, nonce);
    if (aad.length) cipher.setAAD(Buffer.from(aad));
    const ct = Buffer.concat([cipher.update(Buffer.from(plaintext)), cipher.final()]);
    const tag = cipher.getAuthTag();
    return Buffer.concat([nonce, tag, ct]);
  }

  /** Inverse of [seal]. Throws on authentication failure. */
  unseal(envelope: Buffer | Uint8Array, aad: Buffer | Uint8Array = Buffer.alloc(0)): Buffer {
    const buf = Buffer.from(envelope);
    if (buf.length < 12 + 16) {
      throw new Error('Envelope is too short to contain nonce+tag');
    }
    const nonce = buf.subarray(0, 12);
    const tag = buf.subarray(12, 28);
    const ct = buf.subarray(28);
    const decipher = createDecipheriv('aes-256-gcm', this.masterKey, nonce);
    if (aad.length) decipher.setAAD(Buffer.from(aad));
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(ct), decipher.final()]);
  }
}

/** Generates a random 32-byte key for test setup. */
export function generateMasterKeyBase64(): string {
  return randomBytes(32).toString('base64');
}

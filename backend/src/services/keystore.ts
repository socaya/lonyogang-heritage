import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import {
  DecryptCommand,
  GenerateDataKeyCommand,
  KMSClient,
} from '@aws-sdk/client-kms';
import { LocalKms } from '../kms.js';

/**
 * Pluggable envelope-encryption surface. All services that handle long-lived
 * secrets (TOTP seeds, bank credentials, Shamir recovery shares) go through
 * this interface instead of calling `LocalKms` directly, so a deployment can
 * switch from the in-process AES master key to a managed KMS/HSM by changing
 * `KMS_PROVIDER`.
 *
 * The AAD parameter is optional but strongly recommended: pass an identifier
 * for the owning resource (account id, connection id) so a stolen envelope
 * cannot be reused outside its context.
 */
export interface KeyStore {
  seal(plaintext: Buffer | Uint8Array, aad?: Buffer | Uint8Array): Promise<Buffer>;
  unseal(envelope: Buffer | Uint8Array, aad?: Buffer | Uint8Array): Promise<Buffer>;
}

/** Thin async facade around the existing LocalKms. Behaviour is identical. */
export class LocalKeyStore implements KeyStore {
  constructor(private readonly kms: LocalKms) {}
  async seal(plaintext: Buffer | Uint8Array, aad?: Buffer | Uint8Array): Promise<Buffer> {
    return this.kms.seal(plaintext, aad ?? Buffer.alloc(0));
  }
  async unseal(envelope: Buffer | Uint8Array, aad?: Buffer | Uint8Array): Promise<Buffer> {
    return this.kms.unseal(envelope, aad ?? Buffer.alloc(0));
  }
}

/**
 * AWS KMS envelope encryption. Each `seal` call asks KMS for a fresh 32-byte
 * data key (encrypted blob + plaintext). We AES-256-GCM encrypt the payload
 * under the plaintext key, zero it out, and persist
 *   [u32 keyLen][keyBlob][u8 aadLen][aad][12-byte nonce][16-byte tag][ct]
 *
 * Unseal reverses the frame, calls KMS.Decrypt to recover the data key, then
 * AES-GCM-decrypts.
 */
export class AwsKmsKeyStore implements KeyStore {
  private readonly client: KMSClient;

  constructor(
    private readonly keyId: string,
    options: { region?: string; client?: KMSClient } = {},
  ) {
    this.client = options.client ?? new KMSClient({ region: options.region });
  }

  async seal(plaintext: Buffer | Uint8Array, aad: Buffer | Uint8Array = Buffer.alloc(0)): Promise<Buffer> {
    const response = await this.client.send(
      new GenerateDataKeyCommand({
        KeyId: this.keyId,
        KeySpec: 'AES_256',
        EncryptionContext: this.encryptionContext(aad),
      }),
    );
    const plaintextKey = Buffer.from(response.Plaintext ?? []);
    const blob = Buffer.from(response.CiphertextBlob ?? []);
    if (plaintextKey.length !== 32) throw new Error('KMS GenerateDataKey returned an unexpected key length');
    try {
      const nonce = randomBytes(12);
      const cipher = createCipheriv('aes-256-gcm', plaintextKey, nonce);
      const aadBuf = Buffer.from(aad);
      if (aadBuf.length) cipher.setAAD(aadBuf);
      const ct = Buffer.concat([cipher.update(Buffer.from(plaintext)), cipher.final()]);
      const tag = cipher.getAuthTag();
      return this.encodeFrame(blob, aadBuf, nonce, tag, ct);
    } finally {
      plaintextKey.fill(0);
    }
  }

  async unseal(envelope: Buffer | Uint8Array, aad: Buffer | Uint8Array = Buffer.alloc(0)): Promise<Buffer> {
    const frame = this.decodeFrame(Buffer.from(envelope));
    const aadBuf = Buffer.from(aad);
    if (!aadBuf.equals(frame.aad)) throw new Error('Envelope AAD does not match');
    const decrypted = await this.client.send(
      new DecryptCommand({
        CiphertextBlob: frame.keyBlob,
        EncryptionContext: this.encryptionContext(frame.aad),
      }),
    );
    const plaintextKey = Buffer.from(decrypted.Plaintext ?? []);
    try {
      const decipher = createDecipheriv('aes-256-gcm', plaintextKey, frame.nonce);
      if (frame.aad.length) decipher.setAAD(frame.aad);
      decipher.setAuthTag(frame.tag);
      return Buffer.concat([decipher.update(frame.ct), decipher.final()]);
    } finally {
      plaintextKey.fill(0);
    }
  }

  private encryptionContext(aad: Buffer | Uint8Array): Record<string, string> {
    const ctx: Record<string, string> = { service: 'lonyogang-heritage' };
    if (aad.length) ctx['aad'] = Buffer.from(aad).toString('base64');
    return ctx;
  }

  private encodeFrame(keyBlob: Buffer, aad: Buffer, nonce: Buffer, tag: Buffer, ct: Buffer): Buffer {
    const keyLen = Buffer.alloc(4);
    keyLen.writeUInt32BE(keyBlob.length, 0);
    const aadLen = Buffer.from([aad.length]);
    return Buffer.concat([keyLen, keyBlob, aadLen, aad, nonce, tag, ct]);
  }

  private decodeFrame(buf: Buffer): {
    keyBlob: Buffer;
    aad: Buffer;
    nonce: Buffer;
    tag: Buffer;
    ct: Buffer;
  } {
    if (buf.length < 4 + 1 + 12 + 16) throw new Error('Envelope is truncated');
    const keyLen = buf.readUInt32BE(0);
    let offset = 4;
    const keyBlob = buf.subarray(offset, offset + keyLen);
    offset += keyLen;
    const aadLen = buf.readUInt8(offset);
    offset += 1;
    const aad = buf.subarray(offset, offset + aadLen);
    offset += aadLen;
    const nonce = buf.subarray(offset, offset + 12);
    offset += 12;
    const tag = buf.subarray(offset, offset + 16);
    offset += 16;
    const ct = buf.subarray(offset);
    return { keyBlob, aad, nonce, tag, ct };
  }
}

/** Factory used by server.ts to pick an adapter based on configuration. */
export function createKeyStore(options: {
  provider: 'local' | 'aws';
  localMasterKeyB64: string;
  awsKeyId?: string;
  awsRegion?: string;
}): KeyStore {
  if (options.provider === 'aws') {
    if (!options.awsKeyId) throw new Error('KMS_AWS_KEY_ID must be set when KMS_PROVIDER=aws');
    return new AwsKmsKeyStore(options.awsKeyId, { region: options.awsRegion });
  }
  return new LocalKeyStore(new LocalKms(options.localMasterKeyB64));
}

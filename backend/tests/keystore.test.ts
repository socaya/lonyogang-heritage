import { describe, expect, it } from 'vitest';
import { AwsKmsKeyStore, LocalKeyStore } from '../src/services/keystore.js';
import { generateMasterKeyBase64, LocalKms } from '../src/kms.js';

/**
 * Pure-unit tests for the keystore adapters. The AWS adapter uses a fake
 * KMSClient that implements only the two commands the keystore depends on;
 * this proves the envelope framing is correct without needing real cloud
 * credentials in CI.
 */

class FakeKmsClient {
  private readonly keys = new Map<string, Buffer>();
  constructor(private readonly keyId: string) {}

  async send(command: unknown): Promise<unknown> {
    const name = (command as { constructor: { name: string } }).constructor.name;
    if (name === 'GenerateDataKeyCommand') {
      const plaintext = Buffer.alloc(32, 7);
      const id = Buffer.from(crypto.getRandomValues(new Uint8Array(16))).toString('hex');
      this.keys.set(id, plaintext);
      return {
        Plaintext: plaintext,
        CiphertextBlob: Buffer.from(id, 'utf8'),
        KeyId: this.keyId,
      };
    }
    if (name === 'DecryptCommand') {
      const input = (command as unknown as { input: { CiphertextBlob: Uint8Array } }).input;
      const id = Buffer.from(input.CiphertextBlob).toString('utf8');
      const plaintext = this.keys.get(id);
      if (!plaintext) throw new Error('Unknown data-key id');
      return { Plaintext: plaintext, KeyId: this.keyId };
    }
    throw new Error(`Unexpected command: ${name}`);
  }
}

describe('LocalKeyStore', () => {
  it('round-trips a payload with an AAD check', async () => {
    const store = new LocalKeyStore(new LocalKms(generateMasterKeyBase64()));
    const aad = Buffer.from('account:123', 'utf8');
    const sealed = await store.seal(Buffer.from('secret-material'), aad);
    const opened = await store.unseal(sealed, aad);
    expect(opened.toString('utf8')).toBe('secret-material');
  });

  it('rejects an envelope opened with the wrong AAD', async () => {
    const store = new LocalKeyStore(new LocalKms(generateMasterKeyBase64()));
    const sealed = await store.seal(Buffer.from('x'), Buffer.from('a'));
    await expect(store.unseal(sealed, Buffer.from('b'))).rejects.toThrow();
  });
});

describe('AwsKmsKeyStore', () => {
  it('seals and unseals through the fake KMSClient', async () => {
    const fake = new FakeKmsClient('arn:aws:kms:test');
    const store = new AwsKmsKeyStore('arn:aws:kms:test', { client: fake as unknown as never });
    const aad = Buffer.from('bank:connection:42', 'utf8');
    const sealed = await store.seal(Buffer.from('oauth-token-xyz'), aad);
    const opened = await store.unseal(sealed, aad);
    expect(opened.toString('utf8')).toBe('oauth-token-xyz');
  });

  it('rejects an envelope whose AAD was substituted', async () => {
    const fake = new FakeKmsClient('arn:aws:kms:test');
    const store = new AwsKmsKeyStore('arn:aws:kms:test', { client: fake as unknown as never });
    const sealed = await store.seal(Buffer.from('x'), Buffer.from('one'));
    await expect(store.unseal(sealed, Buffer.from('two'))).rejects.toThrow('AAD does not match');
  });
});

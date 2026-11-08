import { createHash, randomBytes } from 'node:crypto';
import { importPKCS8, importSPKI, SignJWT, jwtVerify, type JWTPayload } from 'jose';
import type { AppConfig } from '../config.js';

export interface AccessTokenPayload extends JWTPayload {
  sub: string;
  sid: string;
  did: string;
  scope: string;
}

/**
 * Issues and verifies JWT access tokens plus hashes refresh tokens.
 *
 * - Access tokens are short-lived Ed25519-signed JWTs (EdDSA alg) carrying
 *   account id, session id, device id and a coarse scope.
 * - Refresh tokens are opaque 32-byte random strings handed back to the
 *   client as hex; the server stores only sha256(refresh) so the database
 *   leaking can't by itself grant session continuity.
 */
export class TokenService {
  private privateKeyPromise: Promise<CryptoKey> | undefined;
  private publicKeyPromise: Promise<CryptoKey> | undefined;

  constructor(private readonly config: AppConfig) {}

  private async privateKey() {
    this.privateKeyPromise ??= importPKCS8(this.config.JWT_PRIVATE_KEY_PEM, 'EdDSA');
    return this.privateKeyPromise;
  }

  private async publicKey() {
    this.publicKeyPromise ??= importSPKI(this.config.JWT_PUBLIC_KEY_PEM, 'EdDSA');
    return this.publicKeyPromise;
  }

  async signAccess(input: {
    accountId: string;
    sessionId: string;
    deviceId: string;
    scope?: string;
  }): Promise<string> {
    const key = await this.privateKey();
    return new SignJWT({ did: input.deviceId, sid: input.sessionId, scope: input.scope ?? 'default' })
      .setProtectedHeader({ alg: 'EdDSA', typ: 'JWT' })
      .setIssuer('lonyogang-heritage')
      .setAudience('lonyogang-client')
      .setSubject(input.accountId)
      .setIssuedAt()
      .setExpirationTime(`${this.config.JWT_ACCESS_TTL_SECONDS}s`)
      .sign(key);
  }

  async verifyAccess(token: string): Promise<AccessTokenPayload> {
    const key = await this.publicKey();
    const { payload } = await jwtVerify<AccessTokenPayload>(token, key, {
      issuer: 'lonyogang-heritage',
      audience: 'lonyogang-client',
    });
    if (!payload.sub || !payload['sid'] || !payload['did']) {
      throw new Error('Access token is missing required claims');
    }
    return payload as AccessTokenPayload;
  }

  /** Returns a fresh opaque refresh token and the SHA-256 hash we persist. */
  issueRefresh(): { token: string; hash: Buffer } {
    const token = randomBytes(32).toString('hex');
    const hash = createHash('sha256').update(token).digest();
    return { token, hash };
  }

  /** Hashes a client-presented refresh token for an equality lookup. */
  hashRefresh(token: string): Buffer {
    return createHash('sha256').update(token).digest();
  }
}

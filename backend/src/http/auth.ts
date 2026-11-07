import type { FastifyReply, FastifyRequest } from 'fastify';
import type { TokenService, AccessTokenPayload } from '../services/tokens.js';

declare module 'fastify' {
  interface FastifyRequest {
    auth?: {
      accountId: string;
      sessionId: string;
      deviceId: string;
      scope: string;
    };
  }
}

/** Reads a Bearer token from the Authorization header, verifies it with the
 *  configured JWK and attaches the authenticated principal to the request.
 *  Returns 401 on any failure so no handler ever sees a half-authenticated
 *  request. */
export function requireAuth(tokens: TokenService) {
  return async function (request: FastifyRequest, reply: FastifyReply): Promise<void> {
    const header = request.headers.authorization;
    if (!header || !header.toLowerCase().startsWith('bearer ')) {
      await reply.code(401).send({ error: 'unauthenticated', message: 'Missing bearer token' });
      return reply;
    }
    const token = header.slice(7).trim();
    try {
      const payload = (await tokens.verifyAccess(token)) as AccessTokenPayload;
      request.auth = {
        accountId: payload.sub,
        sessionId: payload.sid,
        deviceId: payload.did,
        scope: payload.scope,
      };
    } catch {
      await reply.code(401).send({ error: 'unauthenticated', message: 'Invalid token' });
      return reply;
    }
  };
}

import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { IdentityService } from '../../services/identity.js';
import type { PasskeyService } from '../../services/passkeys.js';
import { requireAuth } from '../auth.js';

const emailSchema = z.string().email().max(254);

// Per-endpoint rate-limit overrides for auth-sensitive paths. All sit
// below the global 180/min so a credential-stuffing attacker hitting a
// single endpoint is throttled much earlier than a well-behaved client
// doing routine traffic.
const signUpLimit = { rateLimit: { max: 5, timeWindow: '1 hour' } };
const verifyLimit = { rateLimit: { max: 10, timeWindow: '1 minute' } };
const resendLimit = { rateLimit: { max: 3, timeWindow: '1 minute' } };
const sessionLimit = { rateLimit: { max: 10, timeWindow: '1 minute' } };
// Refresh is cheap on the happy path but a leaked refresh token is a
// password-equivalent; cap it so a stolen token can't be exchanged into
// an unlimited supply of access tokens.
const refreshLimit = { rateLimit: { max: 30, timeWindow: '1 minute' } };
const resetBeginLimit = { rateLimit: { max: 5, timeWindow: '1 hour' } };
const resetCompleteLimit = { rateLimit: { max: 10, timeWindow: '1 minute' } };
const passkeyAuthLimit = { rateLimit: { max: 15, timeWindow: '1 minute' } };

export async function registerIdentityRoutes(
  app: FastifyInstance,
  deps: { identity: IdentityService; passkeys: PasskeyService },
): Promise<void> {
  const auth = requireAuth(deps.identity.tokens);

  // ---- Accounts ----
  app.post('/identity/accounts', { config: signUpLimit }, async (req, reply) => {
    const body = z
      .object({
        email: emailSchema,
        password: z.string().min(10).max(1024),
        phone: z.string().min(6).max(32).optional(),
        displayName: z.string().min(1).max(120).optional(),
      })
      .parse(req.body);
    try {
      const result = await deps.identity.signUp(body);
      // In production we would email the code. Returning it in the response
      // only makes sense when NODE_ENV=development or in integration tests.
      return reply.code(201).send(result);
    } catch (err) {
      return reply.code(400).send(toError(err));
    }
  });

  app.post('/identity/accounts/verify', { config: verifyLimit }, async (req, reply) => {
    const body = z
      .object({
        accountId: z.string().uuid(),
        channel: z.enum(['email', 'phone']),
        code: z.string().min(1),
      })
      .parse(req.body);
    try {
      const result = await deps.identity.verify(body);
      return reply.send(result);
    } catch (err) {
      return reply.code(400).send(toError(err));
    }
  });

  app.post('/identity/accounts/verify/resend', { config: resendLimit }, async (req, reply) => {
    const body = z
      .object({
        accountId: z.string().uuid(),
        channel: z.enum(['email', 'phone']),
      })
      .parse(req.body);
    try {
      await deps.identity.resendVerification(body);
      return reply.code(202).send({ status: 'accepted' });
    } catch (err) {
      return reply.code(400).send(toError(err));
    }
  });

  // ---- Password sessions ----
  app.post('/identity/sessions', { config: sessionLimit }, async (req, reply) => {
    const body = z
      .object({
        email: emailSchema,
        password: z.string().min(1),
        totpCode: z.string().min(6).max(8).optional(),
        deviceId: z.string().uuid(),
      })
      .parse(req.body);
    try {
      const result = await deps.identity.signIn({ ...body, userAgent: req.headers['user-agent'] });
      return reply.send(result);
    } catch (err) {
      return reply.code(401).send(toError(err));
    }
  });

  app.post('/identity/sessions/refresh', { config: refreshLimit }, async (req, reply) => {
    const body = z.object({ refreshToken: z.string().min(32) }).parse(req.body);
    try {
      const result = await deps.identity.refreshSession(body.refreshToken);
      return reply.send(result);
    } catch (err) {
      return reply.code(401).send(toError(err));
    }
  });

  app.delete('/identity/sessions/:sessionId', { preHandler: auth }, async (req, reply) => {
    const params = z.object({ sessionId: z.string().uuid() }).parse(req.params);
    await deps.identity.revokeSession(params.sessionId, req.auth!.accountId);
    return reply.code(204).send();
  });

  app.get('/identity/sessions', { preHandler: auth }, async (req) => {
    const rows = await deps.identity.listSessions(req.auth!.accountId);
    return { sessions: rows };
  });

  // Revoke every live session except the one the caller is currently
  // using. Fast path for "sign out everywhere else" after a lost device
  // or a suspicious location on the SessionsScreen.
  app.post('/identity/sessions/revoke-others', { preHandler: auth }, async (req) => {
    const current = req.auth!.sessionId;
    const revoked = await deps.identity.revokeAllSessionsExcept(
      req.auth!.accountId,
      current,
    );
    return { revoked };
  });

  // ---- TOTP ----
  app.post('/identity/totp', { preHandler: auth }, async (req) => {
    return deps.identity.enrollTotp(req.auth!.accountId);
  });

  // ---- Password reset ----
  app.post('/identity/password/reset/begin', { config: resetBeginLimit }, async (req, reply) => {
    const body = z.object({ email: emailSchema }).parse(req.body);
    // Always 202 to avoid leaking account existence. The server dispatches
    // the reset code through the configured OtpDispatcher; the response
    // intentionally never carries the code.
    await deps.identity.beginPasswordReset(body.email);
    return reply.code(202).send({ status: 'accepted' });
  });

  app.post('/identity/password/reset/complete', { config: resetCompleteLimit }, async (req, reply) => {
    const body = z
      .object({ email: emailSchema, token: z.string().min(8), newPassword: z.string().min(10).max(1024) })
      .parse(req.body);
    try {
      await deps.identity.completePasswordReset(body);
      return reply.code(204).send();
    } catch (err) {
      return reply.code(400).send(toError(err));
    }
  });

  // ---- Passkeys ----
  app.post('/identity/passkeys/registration', { preHandler: auth }, async (req) => {
    const body = z.object({ friendlyName: z.string().min(1).max(64).optional() }).parse(req.body);
    return deps.passkeys.registrationOptions(req.auth!.accountId, body.friendlyName);
  });

  app.post('/identity/passkeys/registration/verify', { preHandler: auth }, async (req) => {
    const body = z
      .object({
        response: z.any(),
        friendlyName: z.string().min(1).max(64).optional(),
      })
      .parse(req.body);
    const result = await deps.passkeys.finishRegistration({
      accountId: req.auth!.accountId,
      response: body.response,
      friendlyName: body.friendlyName,
    });
    return result;
  });

  app.post('/identity/passkeys/authentication', { config: passkeyAuthLimit }, async (req) => {
    const body = z.object({ email: emailSchema.optional() }).parse(req.body);
    return deps.passkeys.authenticationOptions(body.email);
  });

  app.post('/identity/passkeys/authentication/verify', { config: passkeyAuthLimit }, async (req, reply) => {
    const body = z
      .object({ response: z.any(), deviceId: z.string().uuid() })
      .parse(req.body);
    try {
      const { accountId } = await deps.passkeys.verifyAuthentication({ response: body.response });
      const session = await deps.identity.openSession(accountId, body.deviceId, req.headers['user-agent']);
      return reply.send(session);
    } catch (err) {
      return reply.code(401).send(toError(err));
    }
  });

  app.delete('/identity/passkeys/:credentialId', { preHandler: auth }, async (req, reply) => {
    const params = z.object({ credentialId: z.string().min(1) }).parse(req.params);
    try {
      await deps.passkeys.remove(req.auth!.accountId, params.credentialId);
      return reply.code(204).send();
    } catch (err) {
      return reply.code(404).send(toError(err));
    }
  });
}

function toError(err: unknown): { error: string; message: string } {
  if (err && typeof err === 'object' && 'code' in err) {
    return {
      error: String((err as { code: unknown }).code ?? 'bad_request'),
      message: (err as { message?: string }).message ?? 'Request rejected',
    };
  }
  return { error: 'bad_request', message: err instanceof Error ? err.message : String(err) };
}

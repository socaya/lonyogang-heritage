import type { AppConfig } from '../config.js';

/**
 * Hand-written OpenAPI 3.1 schema that mirrors the routes registered in
 * `src/http/routes/*.ts`. Kept in sync manually rather than generated so
 * reviewers can treat the schema as a contract and tests can diff it
 * against the live routes list. See `tests/openapi.test.ts` for the drift
 * guard.
 */
export function buildOpenApi(config: AppConfig): Record<string, unknown> {
  return {
    openapi: '3.1.0',
    info: {
      title: 'LonyoGang Heritage backend',
      version: '0.5.0-dev',
      description:
        'Online services backing the LonyoGang Heritage Flutter client. ' +
        'See docs/ONLINE_SERVICE_PLAN.md for the design plan and ' +
        'docs/COMPLIANCE_UG_DPPA_2019.md for the privacy posture.',
      contact: {
        name: 'LonyoGang Heritage DPO',
        email: 'privacy@lonyogang.com',
      },
    },
    servers: [{ url: `http://localhost:${config.PORT}`, description: 'Local' }],
    tags: [
      { name: 'health', description: 'Service liveness and readiness.' },
      { name: 'identity', description: 'Accounts, sessions, TOTP, passkeys.' },
      { name: 'sync', description: 'Zero-knowledge event sync and attachments.' },
      { name: 'audit', description: 'Merkle-chained audit log and transparency.' },
      { name: 'recovery', description: 'Shamir vault-key recovery.' },
      { name: 'fx', description: 'Offline-friendly FX reference rates.' },
      { name: 'bank', description: 'Open-banking connector framework.' },
      { name: 'billing', description: 'Subscription state and processor webhooks.' },
      { name: 'push', description: 'OS push notification tokens.' },
    ],
    components: {
      securitySchemes: {
        bearer: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      },
      schemas: {
        Error: {
          type: 'object',
          required: ['error'],
          properties: {
            error: { type: 'string' },
            message: { type: 'string' },
          },
        },
        SessionResult: {
          type: 'object',
          required: ['accessToken', 'refreshToken', 'sessionId', 'expiresAt'],
          properties: {
            accessToken: { type: 'string' },
            refreshToken: { type: 'string' },
            sessionId: { type: 'string', format: 'uuid' },
            expiresAt: { type: 'string', format: 'date-time' },
          },
        },
        SyncEvent: {
          type: 'object',
          required: ['id', 'deviceId', 'payloadType', 'payload'],
          properties: {
            id: { type: 'string', minLength: 16, maxLength: 40 },
            deviceId: { type: 'string', format: 'uuid' },
            payloadType: { type: 'string' },
            payload: { type: 'string', description: 'Base64-encoded AES-GCM ciphertext.' },
            prevHash: { type: 'string', nullable: true },
            integrity: { type: 'object', additionalProperties: true, nullable: true },
            createdAt: { type: 'string', format: 'date-time' },
          },
        },
      },
    },
    paths: {
      '/me': {
        get: {
          tags: ['identity'],
          security: [{ bearer: [] }],
          summary: 'Return the authenticated owner profile',
          responses: { '200': { description: 'Account profile.' } },
        },
        patch: {
          tags: ['identity'],
          security: [{ bearer: [] }],
          summary: 'Update display name, phone and marketing consent',
          responses: { '200': { description: 'Updated profile.' } },
        },
        delete: {
          tags: ['identity'],
          security: [{ bearer: [] }],
          summary: 'Exercise right to erasure (requires password re-auth)',
          requestBody: {
            required: true,
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  required: ['password'],
                  properties: {
                    password: { type: 'string', minLength: 1, maxLength: 1024 },
                  },
                },
              },
            },
          },
          responses: {
            '204': { description: 'Account tombstoned.' },
            '401': { description: 'Password re-auth failed.' },
            '429': { description: 'Rate limit (3/hour) hit.' },
          },
        },
      },
      '/me/export': {
        get: {
          tags: ['identity'],
          security: [{ bearer: [] }],
          summary: 'Portable JSON export (right of access)',
          responses: { '200': { description: 'Export bundle.' } },
        },
      },
      '/healthz': {
        get: {
          tags: ['health'],
          summary: 'Deep health check',
          responses: {
            '200': {
              description: 'All critical dependencies responded within SLO.',
              content: {
                'application/json': {
                  schema: {
                    type: 'object',
                    required: ['status', 'checks'],
                    properties: {
                      status: { type: 'string', enum: ['ok', 'degraded', 'fail'] },
                      checks: {
                        type: 'object',
                        additionalProperties: {
                          type: 'object',
                          required: ['status'],
                          properties: {
                            status: { type: 'string', enum: ['ok', 'degraded', 'fail'] },
                            latencyMs: { type: 'number' },
                            error: { type: 'string', nullable: true },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
            '503': { description: 'A critical dependency is unavailable.' },
          },
        },
      },
      '/identity/accounts': {
        post: {
          tags: ['identity'],
          summary: 'Create an account and dispatch verification codes',
          requestBody: {
            required: true,
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  required: ['email', 'password'],
                  properties: {
                    email: { type: 'string', format: 'email' },
                    password: { type: 'string', minLength: 10 },
                    phone: { type: 'string', nullable: true },
                    displayName: { type: 'string', nullable: true },
                  },
                },
              },
            },
          },
          responses: {
            '201': {
              description: 'Account created and codes dispatched.',
              content: {
                'application/json': {
                  schema: {
                    type: 'object',
                    required: ['accountId', 'dispatched'],
                    properties: {
                      accountId: { type: 'string', format: 'uuid' },
                      dispatched: {
                        type: 'object',
                        properties: {
                          email: { type: 'boolean' },
                          phone: { type: 'boolean' },
                        },
                      },
                    },
                  },
                },
              },
            },
            '400': { $ref: '#/components/responses/BadRequest' },
          },
        },
      },
      '/identity/accounts/verify': {
        post: {
          tags: ['identity'],
          summary: 'Verify an OTP code for a channel',
          requestBody: { required: true, content: { 'application/json': { schema: { type: 'object' } } } },
          responses: { '200': { description: 'Verification result.' } },
        },
      },
      '/identity/accounts/verify/resend': {
        post: {
          tags: ['identity'],
          summary: 'Dispatch a fresh OTP code for a pending channel',
          responses: { '202': { description: 'Dispatcher invoked.' } },
        },
      },
      '/identity/sessions': {
        post: {
          tags: ['identity'],
          summary: 'Email + password (+ optional TOTP) sign-in',
          responses: {
            '200': {
              description: 'Session issued.',
              content: { 'application/json': { schema: { $ref: '#/components/schemas/SessionResult' } } },
            },
            '401': { description: 'Bad credentials or TOTP.' },
          },
        },
        get: {
          tags: ['identity'],
          security: [{ bearer: [] }],
          summary: "List this account's active sessions",
          responses: { '200': { description: 'Session list.' } },
        },
      },
      '/identity/sessions/refresh': {
        post: {
          tags: ['identity'],
          summary: 'Rotate access + refresh tokens',
          responses: { '200': { description: 'New session pair.' } },
        },
      },
      '/identity/sessions/{sessionId}': {
        delete: {
          tags: ['identity'],
          security: [{ bearer: [] }],
          summary: 'Revoke a specific session',
          responses: { '204': { description: 'Revoked.' } },
        },
      },
      '/identity/totp': {
        post: {
          tags: ['identity'],
          security: [{ bearer: [] }],
          summary: 'Enroll a TOTP second factor; returns seed + otpauth URI',
          responses: { '200': { description: 'Seed + otpauth URI.' } },
        },
      },
      '/identity/password/reset/begin': {
        post: {
          tags: ['identity'],
          summary: 'Request a password reset code (always 202 to avoid enumeration)',
          requestBody: {
            required: true,
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  required: ['email'],
                  properties: {
                    email: { type: 'string', format: 'email' },
                  },
                },
              },
            },
          },
          responses: {
            '202': { description: 'Accepted (regardless of whether the email resolves).' },
            '429': { description: 'Rate limit (5/hour) hit.' },
          },
        },
      },
      '/identity/password/reset/complete': {
        post: {
          tags: ['identity'],
          summary: 'Complete a password reset with the emailed token',
          requestBody: {
            required: true,
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  required: ['email', 'token', 'newPassword'],
                  properties: {
                    email: { type: 'string', format: 'email' },
                    token: { type: 'string', minLength: 8 },
                    newPassword: { type: 'string', minLength: 10 },
                  },
                },
              },
            },
          },
          responses: {
            '204': { description: 'Password updated; sessions revoked.' },
            '400': { description: 'Token expired or did not match.' },
            '429': { description: 'Rate limit (10/min) hit.' },
          },
        },
      },
      '/identity/passkeys/registration/verify': {
        post: {
          tags: ['identity'],
          security: [{ bearer: [] }],
          summary: 'Verify a WebAuthn registration response',
          responses: { '200': { description: 'Credential registered.' } },
        },
      },
      '/identity/passkeys/authentication/verify': {
        post: {
          tags: ['identity'],
          summary: 'Verify a WebAuthn authentication response and open a session',
          responses: { '200': { description: 'Access + refresh issued.' } },
        },
      },
      '/identity/passkeys/{credentialId}': {
        delete: {
          tags: ['identity'],
          security: [{ bearer: [] }],
          summary: 'Remove a registered passkey',
          responses: { '204': { description: 'Removed.' } },
        },
      },
      '/identity/passkeys/registration': {
        post: {
          tags: ['identity'],
          security: [{ bearer: [] }],
          summary: 'WebAuthn registration challenge',
          responses: { '200': { description: 'PublicKeyCredentialCreationOptions.' } },
        },
      },
      '/identity/passkeys/authentication': {
        post: {
          tags: ['identity'],
          summary: 'WebAuthn authentication challenge',
          responses: { '200': { description: 'PublicKeyCredentialRequestOptions.' } },
        },
      },
      '/sync/events': {
        post: {
          tags: ['sync'],
          security: [{ bearer: [] }],
          summary: 'Ingest a batch of encrypted events',
          responses: {
            '200': { description: 'Batch accepted; returns number inserted.' },
            '422': { description: 'Plaintext integrity assertion rejected the batch.' },
          },
        },
        get: {
          tags: ['sync'],
          security: [{ bearer: [] }],
          summary: 'Pull encrypted events after a received-at cursor',
          responses: {
            '200': {
              description: 'List of events (up to 2000).',
              content: {
                'application/json': {
                  schema: {
                    type: 'object',
                    properties: {
                      events: {
                        type: 'array',
                        items: { $ref: '#/components/schemas/SyncEvent' },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
      '/sync/attachments': {
        post: {
          tags: ['sync'],
          security: [{ bearer: [] }],
          summary: 'Request a presigned attachment upload URL',
          responses: { '201': { description: 'Upload URL issued.' } },
        },
      },
      '/sync/attachments/{id}/commit': {
        post: {
          tags: ['sync'],
          security: [{ bearer: [] }],
          summary: 'Commit a completed attachment upload (runs virus scan)',
          responses: { '204': { description: 'Attachment committed.' } },
        },
      },
      '/sync/attachments/{id}': {
        get: {
          tags: ['sync'],
          security: [{ bearer: [] }],
          summary: 'Request a presigned attachment download URL',
          responses: { '200': { description: 'Download URL issued.' } },
        },
        delete: {
          tags: ['sync'],
          security: [{ bearer: [] }],
          summary: 'Delete a stored attachment (object + db row)',
          responses: { '204': { description: 'Deleted.' } },
        },
      },
      '/sync/envelope': {
        get: {
          tags: ['sync'],
          security: [{ bearer: [] }],
          summary: 'Fetch the account vault envelope (recovery material)',
          responses: { '200': { description: 'Envelope bytes.' } },
        },
        put: {
          tags: ['sync'],
          security: [{ bearer: [] }],
          summary: 'Replace the account vault envelope',
          responses: { '204': { description: 'Envelope stored.' } },
        },
      },
      '/bank/connections/{id}': {
        delete: {
          tags: ['bank'],
          security: [{ bearer: [] }],
          summary: 'Revoke a bank aggregation link',
          responses: { '204': { description: 'Revoked.' } },
        },
      },
      '/bank/pending-imports': {
        get: {
          tags: ['bank'],
          security: [{ bearer: [] }],
          summary: 'List transactions pulled from bank feeds not yet posted as events',
          responses: { '200': { description: 'Pending imports.' } },
        },
      },
      '/push/tokens/{deviceId}/{platform}': {
        delete: {
          tags: ['push'],
          security: [{ bearer: [] }],
          summary: 'Drop a push token for this device + platform',
          responses: { '204': { description: 'Token dropped.' } },
        },
      },
      '/ops/push/send': {
        post: {
          tags: ['ops'],
          summary: 'Internal ops push (requires x-ops-token header)',
          responses: {
            '200': { description: 'Delivery attempted.' },
            '401': { description: 'Missing or wrong ops token.' },
            '503': { description: 'Ops push disabled on this deployment.' },
          },
        },
      },
      '/audit/entries': {
        get: {
          tags: ['audit'],
          security: [{ bearer: [] }],
          summary: 'Recent audit entries for the authenticated account',
          responses: { '200': { description: 'Audit entry list.' } },
        },
      },
      '/audit/chain': {
        get: {
          tags: ['audit'],
          security: [{ bearer: [] }],
          summary: 'Verify the Merkle chain integrity',
          responses: { '200': { description: 'Integrity report.' } },
        },
      },
      '/audit/anchors': {
        get: {
          tags: ['audit'],
          security: [{ bearer: [] }],
          summary: 'Historical transparency anchors',
          responses: { '200': { description: 'Anchors list.' } },
        },
      },
      '/audit/anchors/run': {
        post: {
          tags: ['audit'],
          security: [{ bearer: [] }],
          summary: 'Roll a fresh transparency anchor for this account',
          responses: { '200': { description: 'Anchor result.' } },
        },
      },
      '/recovery/enroll': {
        post: {
          tags: ['recovery'],
          security: [{ bearer: [] }],
          summary: 'Enroll a Shamir 2-of-3 recovery split',
          responses: { '200': { description: 'Shares returned to the client.' } },
        },
      },
      '/recovery/redeem': {
        post: {
          tags: ['recovery'],
          security: [{ bearer: [] }],
          summary: 'Exchange the printable share for the server share (requires password re-auth)',
          requestBody: {
            required: true,
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  required: ['printableShare', 'password'],
                  properties: {
                    printableShare: { type: 'string', minLength: 16 },
                    password: { type: 'string', minLength: 1, maxLength: 1024 },
                  },
                },
              },
            },
          },
          responses: {
            '200': { description: 'Server share returned.' },
            '400': { description: 'Share could not be validated.' },
            '401': { description: 'Password re-auth failed.' },
            '429': { description: 'Rate limit (5/hour) hit.' },
          },
        },
      },
      '/fx/rates': {
        get: {
          tags: ['fx'],
          summary: 'Signed FX reference rates',
          responses: { '200': { description: 'Rate list.' } },
        },
      },
      '/bank/providers': {
        get: {
          tags: ['bank'],
          summary: 'Registered bank aggregation providers',
          responses: { '200': { description: 'Provider list.' } },
        },
      },
      '/bank/connections': {
        post: {
          tags: ['bank'],
          security: [{ bearer: [] }],
          summary: 'Link a bank connection using an OAuth-issued token',
          responses: { '200': { description: 'Connection record.' } },
        },
      },
      '/bank/connections/{id}/sync': {
        post: {
          tags: ['bank'],
          security: [{ bearer: [] }],
          summary: 'Pull new transactions for a connection',
          responses: { '200': { description: 'Imported count.' } },
        },
      },
      '/billing/subscription': {
        get: {
          tags: ['billing'],
          security: [{ bearer: [] }],
          summary: 'Current subscription tier and status',
          responses: { '200': { description: 'Subscription record.' } },
        },
      },
      '/webhooks/flutterwave': {
        post: {
          tags: ['billing'],
          summary: 'Flutterwave subscription webhook',
          responses: { '204': { description: 'Event stored.' } },
        },
      },
      '/webhooks/stripe': {
        post: {
          tags: ['billing'],
          summary: 'Stripe webhook (HMAC verified)',
          responses: { '204': { description: 'Event stored.' } },
        },
      },
      '/push/tokens': {
        post: {
          tags: ['push'],
          security: [{ bearer: [] }],
          summary: 'Register an FCM/APNs device token',
          responses: { '204': { description: 'Token upserted.' } },
        },
      },
    },
  };
}

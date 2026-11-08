import { z } from 'zod';

const required = (name: string) =>
  z
    .string({ required_error: `${name} is required` })
    .min(1, `${name} cannot be empty`);

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(8080),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),

  DATABASE_URL: required('DATABASE_URL'),

  JWT_PRIVATE_KEY_PEM: required('JWT_PRIVATE_KEY_PEM'),
  JWT_PUBLIC_KEY_PEM: required('JWT_PUBLIC_KEY_PEM'),
  JWT_ACCESS_TTL_SECONDS: z.coerce.number().int().positive().default(900),
  JWT_REFRESH_TTL_SECONDS: z.coerce.number().int().positive().default(2_592_000),

  PASSWORD_PEPPER: required('PASSWORD_PEPPER'),

  RP_ID: required('RP_ID'),
  RP_NAME: required('RP_NAME'),
  RP_ORIGIN: required('RP_ORIGIN'),

  S3_ENDPOINT: z.string().optional(),
  S3_REGION: z.string().default('us-east-1'),
  S3_ACCESS_KEY: z.string().optional(),
  S3_SECRET_KEY: z.string().optional(),
  S3_BUCKET: z.string().default('lonyogang-attachments'),

  KMS_MASTER_KEY_B64: required('KMS_MASTER_KEY_B64'),

  FX_PROVIDER: z.enum(['exchangerate_host', 'bou', 'mock']).default('exchangerate_host'),
  FX_CACHE_TTL_SECONDS: z.coerce.number().int().positive().default(1800),

  FLUTTERWAVE_SECRET_HASH: z.string().optional(),
  STRIPE_WEBHOOK_SECRET: z.string().optional(),

  FCM_PROJECT_ID: z.string().optional(),
  FCM_SERVICE_ACCOUNT_JSON: z.string().optional(),
  APNS_TEAM_ID: z.string().optional(),
  APNS_KEY_ID: z.string().optional(),
  APNS_PRIVATE_KEY_PEM: z.string().optional(),
  APNS_BUNDLE_ID: z.string().default('com.lonyogang.heritage'),

  // Transactional email (SendGrid/SES/Mailgun/anything SMTP).
  SMTP_HOST: z.string().optional(),
  SMTP_PORT: z.coerce.number().int().positive().default(587),
  SMTP_USER: z.string().optional(),
  SMTP_PASS: z.string().optional(),
  SMTP_FROM: z.string().optional(),
  SMTP_SECURE: z.coerce.boolean().optional(),

  // Africa's Talking SMS gateway.
  AFRICASTALKING_USERNAME: z.string().optional(),
  AFRICASTALKING_API_KEY: z.string().optional(),
  AFRICASTALKING_SENDER_ID: z.string().optional(),

  // Cloud KMS selection and target key id.
  KMS_PROVIDER: z.enum(['local', 'aws']).default('local'),
  KMS_AWS_KEY_ID: z.string().optional(),
  KMS_AWS_REGION: z.string().optional(),

  // ClamAV TCP endpoint for attachment virus scanning. When unset the
  // commit path uses the Noop scanner.
  CLAMAV_HOST: z.string().optional(),
  CLAMAV_PORT: z.coerce.number().int().positive().default(3310),

  // Transparency anchor notary. `in_memory` keeps anchors local only;
  // `opentimestamps` submits each tip hash to the public OTS calendars.
  TRANSPARENCY_NOTARY: z.enum(['in_memory', 'opentimestamps']).default('in_memory'),

  // Shared secret required by /ops/* endpoints (push send, admin tools).
  // The ops caller presents it in the `x-ops-token` header. Leave blank to
  // disable the ops surface entirely.
  OPS_SHARED_SECRET: z.string().optional(),
});

export type AppConfig = z.infer<typeof schema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsed = schema.safeParse(env);
  if (!parsed.success) {
    const summary = parsed.error.errors.map((e) => `${e.path.join('.')}: ${e.message}`).join('\n');
    throw new Error(`Invalid configuration:\n${summary}`);
  }
  return parsed.data;
}

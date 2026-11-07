import pino from 'pino';
import type { AppConfig } from './config.js';

export function createLogger(config: AppConfig) {
  return pino({
    level: config.LOG_LEVEL,
    base: { service: 'lonyogang-backend' },
    redact: {
      paths: [
        'req.headers.authorization',
        'req.headers.cookie',
        '*.password',
        '*.password_hash',
        '*.totp_secret',
        '*.refresh_token',
        '*.access_token',
        '*.wrapped_content_key',
      ],
      censor: '[redacted]',
    },
  });
}

export type AppLogger = ReturnType<typeof createLogger>;

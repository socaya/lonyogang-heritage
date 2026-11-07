import nodemailer, { type Transporter } from 'nodemailer';
import { request } from 'undici';

export type OtpChannel = 'email' | 'phone';

export interface OtpDeliveryRequest {
  accountId: string;
  channel: OtpChannel;
  code: string;
  destination: string;
  purpose: 'signup' | 'password_reset';
}

export interface OtpDispatcher {
  send(req: OtpDeliveryRequest): Promise<void>;
}

/** No-network dispatcher used by tests and local development. Records every
 *  delivery in an in-memory ring so tests can assert on and retrieve codes
 *  without the service returning them in HTTP responses. */
export class ConsoleOtpDispatcher implements OtpDispatcher {
  readonly dispatched: OtpDeliveryRequest[] = [];
  async send(req: OtpDeliveryRequest): Promise<void> {
    this.dispatched.push(req);
  }
  /** Retrieves the most recent OTP for an account + channel. */
  latestCode(accountId: string, channel: OtpChannel): string | null {
    for (let i = this.dispatched.length - 1; i >= 0; i -= 1) {
      const entry = this.dispatched[i]!;
      if (entry.accountId === accountId && entry.channel === channel) {
        return entry.code;
      }
    }
    return null;
  }
  clear(): void {
    this.dispatched.length = 0;
  }
}

/** Transactional email dispatcher that talks to SendGrid, SES, Mailgun or
 *  any SMTP endpoint via nodemailer. */
export class SmtpOtpDispatcher implements OtpDispatcher {
  private transporter: Transporter;
  constructor(
    private readonly options: {
      host: string;
      port: number;
      user?: string;
      pass?: string;
      from: string;
      subject?: string;
      secure?: boolean;
    },
  ) {
    this.transporter = nodemailer.createTransport({
      host: options.host,
      port: options.port,
      secure: options.secure ?? options.port === 465,
      auth: options.user && options.pass ? { user: options.user, pass: options.pass } : undefined,
    });
  }

  async send(req: OtpDeliveryRequest): Promise<void> {
    if (req.channel !== 'email') return;
    const subject =
      this.options.subject ??
      (req.purpose === 'password_reset'
        ? 'Reset your LonyoGang account'
        : 'Verify your LonyoGang account');
    const bodyLines =
      req.purpose === 'password_reset'
        ? [
            'Use this code to reset your LonyoGang password.',
            '',
            `Code: ${req.code}`,
            '',
            'It expires in 30 minutes. If you did not request this, ignore the message.',
          ]
        : [
            'Welcome to LonyoGang Heritage.',
            '',
            `Your verification code is ${req.code}.`,
            '',
            'It expires in 15 minutes.',
          ];
    await this.transporter.sendMail({
      from: this.options.from,
      to: req.destination,
      subject,
      text: bodyLines.join('\n'),
    });
  }
}

/** Africa's Talking SMS dispatcher. Targets the public REST API at
 *  https://api.africastalking.com/version1/messaging. */
export class AfricasTalkingSmsDispatcher implements OtpDispatcher {
  constructor(
    private readonly options: {
      username: string;
      apiKey: string;
      senderId?: string;
      endpoint?: string;
    },
  ) {}

  async send(req: OtpDeliveryRequest): Promise<void> {
    if (req.channel !== 'phone') return;
    const endpoint = this.options.endpoint ?? 'https://api.africastalking.com/version1/messaging';
    const params = new URLSearchParams({
      username: this.options.username,
      to: req.destination,
      message: `LonyoGang code: ${req.code}`,
    });
    if (this.options.senderId) params.set('from', this.options.senderId);
    const { statusCode, body } = await request(endpoint, {
      method: 'POST',
      headers: {
        apiKey: this.options.apiKey,
        accept: 'application/json',
        'content-type': 'application/x-www-form-urlencoded',
      },
      body: params.toString(),
    });
    if (statusCode < 200 || statusCode >= 300) {
      throw new Error(`Africa's Talking HTTP ${statusCode}: ${await body.text()}`);
    }
    await body.dump();
  }
}

/** Composite: routes `email` to [emailChild] and `phone` to [smsChild]. */
export class CompositeOtpDispatcher implements OtpDispatcher {
  constructor(private readonly options: { email?: OtpDispatcher; sms?: OtpDispatcher }) {}
  async send(req: OtpDeliveryRequest): Promise<void> {
    const child = req.channel === 'email' ? this.options.email : this.options.sms;
    if (!child) return; // Delivery disabled for this channel.
    await child.send(req);
  }
}

import net from 'node:net';

export interface VirusScanResult {
  clean: boolean;
  signature?: string;
  scanner: string;
}

export interface VirusScanner {
  readonly name: string;
  scan(bytes: Buffer): Promise<VirusScanResult>;
}

/** Noop scanner used by tests and development when ClamAV is not present. */
export class NoopVirusScanner implements VirusScanner {
  readonly name = 'noop';
  async scan(): Promise<VirusScanResult> {
    return { clean: true, scanner: this.name };
  }
}

/**
 * Real ClamAV TCP INSTREAM scanner. Speaks the documented protocol:
 *   send "zINSTREAM\0"
 *   stream { 4-byte big-endian chunk length || chunk bytes } repeatedly
 *   terminate with a 4-byte zero length
 *   read the response until a NUL byte; parse "stream: OK" vs
 *   "stream: <sig> FOUND".
 */
export class ClamAvScanner implements VirusScanner {
  readonly name = 'clamav';
  constructor(
    private readonly options: {
      host: string;
      port: number;
      connectTimeoutMs?: number;
      replyTimeoutMs?: number;
      chunkSize?: number;
      maxBytes?: number;
    },
  ) {}

  async scan(bytes: Buffer): Promise<VirusScanResult> {
    const maxBytes = this.options.maxBytes ?? 25 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      throw new Error(`scan payload exceeds ${maxBytes} bytes`);
    }
    const chunkSize = this.options.chunkSize ?? 64 * 1024;
    const connectTimeoutMs = this.options.connectTimeoutMs ?? 5_000;
    const replyTimeoutMs = this.options.replyTimeoutMs ?? 60_000;

    return new Promise<VirusScanResult>((resolve, reject) => {
      const socket = net.createConnection({ host: this.options.host, port: this.options.port });
      const chunks: Buffer[] = [];
      let settled = false;
      const complete = (res: VirusScanResult | Error) => {
        if (settled) return;
        settled = true;
        socket.destroy();
        if (res instanceof Error) reject(res);
        else resolve(res);
      };
      const connectTimer = setTimeout(() => complete(new Error('clamav connect timeout')), connectTimeoutMs);
      const replyTimer = setTimeout(() => complete(new Error('clamav reply timeout')), replyTimeoutMs);
      socket.once('error', (err) => complete(err));
      socket.once('close', () => {
        clearTimeout(connectTimer);
        clearTimeout(replyTimer);
        if (settled) return;
        const response = Buffer.concat(chunks).toString('utf8').replace(/\0$/, '').trim();
        const match = response.match(/^stream:\s*(.*)$/);
        if (!match) {
          complete(new Error(`clamav unexpected reply: ${response}`));
          return;
        }
        const body = match[1]!;
        if (body === 'OK') {
          complete({ clean: true, scanner: this.name });
          return;
        }
        const found = body.match(/^(.*?) FOUND$/);
        if (found) {
          complete({ clean: false, signature: found[1], scanner: this.name });
          return;
        }
        complete(new Error(`clamav error reply: ${body}`));
      });
      socket.on('data', (chunk) => chunks.push(Buffer.from(chunk)));
      socket.once('ready', () => {
        clearTimeout(connectTimer);
        socket.write(Buffer.from('zINSTREAM\0'));
        for (let i = 0; i < bytes.length; i += chunkSize) {
          const slice = bytes.subarray(i, Math.min(bytes.length, i + chunkSize));
          const lenBuf = Buffer.alloc(4);
          lenBuf.writeUInt32BE(slice.length, 0);
          socket.write(lenBuf);
          socket.write(slice);
        }
        const terminator = Buffer.alloc(4);
        terminator.writeUInt32BE(0, 0);
        socket.write(terminator);
      });
    });
  }
}

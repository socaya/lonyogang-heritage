import net from 'node:net';
import { describe, expect, it } from 'vitest';
import { ClamAvScanner, NoopVirusScanner } from '../src/services/virus_scanner.js';

/** Minimal in-process server that speaks enough of the ClamAV INSTREAM wire
 *  protocol to exercise the scanner end-to-end. The test "infected" payload
 *  is detected by scanning the concatenated chunks for the token `INFECTED`. */
async function startFakeClamAv() {
  const server = net.createServer((socket) => {
    let buffer = Buffer.alloc(0);
    let readingCommand = true;
    const chunks: Buffer[] = [];
    socket.on('data', (data) => {
      buffer = Buffer.concat([buffer, Buffer.from(data)]);
      if (readingCommand) {
        const nul = buffer.indexOf(0);
        if (nul < 0) return;
        const command = buffer.subarray(0, nul).toString('utf8');
        buffer = buffer.subarray(nul + 1);
        if (command !== 'zINSTREAM') {
          socket.end(Buffer.from('UNKNOWN COMMAND\0'));
          return;
        }
        readingCommand = false;
      }
      while (buffer.length >= 4) {
        const chunkLen = buffer.readUInt32BE(0);
        if (chunkLen === 0) {
          const payload = Buffer.concat(chunks);
          if (payload.includes(Buffer.from('INFECTED', 'utf8'))) {
            socket.end(Buffer.from('stream: Win.Test.EICAR_HDB-1 FOUND\0'));
          } else {
            socket.end(Buffer.from('stream: OK\0'));
          }
          return;
        }
        if (buffer.length < 4 + chunkLen) return;
        chunks.push(buffer.subarray(4, 4 + chunkLen));
        buffer = buffer.subarray(4 + chunkLen);
      }
    });
    socket.on('error', () => socket.destroy());
  });
  await new Promise<void>((resolve) => server.listen(0, resolve));
  const address = server.address();
  if (!address || typeof address === 'string') throw new Error('No port bound');
  return {
    host: '127.0.0.1',
    port: address.port,
    close: () => new Promise<void>((r) => server.close(() => r())),
  };
}

describe('NoopVirusScanner', () => {
  it('always reports clean', async () => {
    const scanner = new NoopVirusScanner();
    const result = await scanner.scan(Buffer.from('anything'));
    expect(result.clean).toBe(true);
    expect(result.scanner).toBe('noop');
  });
});

describe('ClamAvScanner (fake backend)', () => {
  it('reports a clean payload as OK', async () => {
    const fake = await startFakeClamAv();
    try {
      const scanner = new ClamAvScanner({ host: fake.host, port: fake.port });
      const result = await scanner.scan(Buffer.from('harmless-document'));
      expect(result.clean).toBe(true);
      expect(result.scanner).toBe('clamav');
    } finally {
      await fake.close();
    }
  });

  it('surfaces the matching signature for an infected payload', async () => {
    const fake = await startFakeClamAv();
    try {
      const scanner = new ClamAvScanner({ host: fake.host, port: fake.port });
      const result = await scanner.scan(Buffer.from('this document is INFECTED!'));
      expect(result.clean).toBe(false);
      expect(result.signature).toBe('Win.Test.EICAR_HDB-1');
    } finally {
      await fake.close();
    }
  });
});

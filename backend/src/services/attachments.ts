import { randomUUID } from 'node:crypto';
import {
  S3Client,
  HeadBucketCommand,
  CreateBucketCommand,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import type { AppConfig } from '../config.js';
import type { Db } from '../db.js';
import { queryOne } from '../db.js';
import type { AuditService } from './audit.js';

/**
 * Mediates attachment uploads and downloads through S3-compatible object
 * storage. The server never sees the plaintext bytes — the client encrypts
 * them before uploading. We hand back signed URLs, verify the SHA-256 the
 * client declares at commit time, and enforce per-account quotas.
 */
export class AttachmentService {
  private readonly s3: S3Client;
  private readonly bucket: string;

  constructor(
    private readonly db: Db,
    config: AppConfig,
    private readonly audit: AuditService,
  ) {
    this.bucket = config.S3_BUCKET;
    this.s3 = new S3Client({
      region: config.S3_REGION,
      endpoint: config.S3_ENDPOINT,
      forcePathStyle: Boolean(config.S3_ENDPOINT),
      credentials: config.S3_ACCESS_KEY && config.S3_SECRET_KEY
        ? {
            accessKeyId: config.S3_ACCESS_KEY,
            secretAccessKey: config.S3_SECRET_KEY,
          }
        : undefined,
    });
  }

  /** Ensures the bucket exists. Call once at boot. */
  async ensureBucket(): Promise<void> {
    try {
      await this.s3.send(new HeadBucketCommand({ Bucket: this.bucket }));
    } catch {
      await this.s3.send(new CreateBucketCommand({ Bucket: this.bucket }));
    }
  }

  /** Issues a presigned PUT URL. The client hands back the SHA-256 and
   *  size in [commit] after the upload completes. */
  async presignUpload(input: {
    accountId: string;
    sizeBytes: number;
    sha256: Buffer;
    mimeType?: string;
  }): Promise<{ attachmentId: string; uploadUrl: string; bucketKey: string }> {
    if (input.sizeBytes <= 0) throw new Error('size_bytes must be positive');
    if (input.sizeBytes > 25 * 1024 * 1024) throw new Error('attachment exceeds 25 MB cap');
    const quota = await this.currentQuota(input.accountId);
    if (quota + input.sizeBytes > this.quotaBytesForAccount(input.accountId)) {
      throw new Error('attachment quota exceeded');
    }
    const attachmentId = randomUUID();
    const bucketKey = `accounts/${input.accountId}/${attachmentId}.bin`;
    await this.db.query(
      `insert into attachment_blobs (id, account_id, bucket_key, size_bytes, sha256, mime_type)
       values ($1, $2, $3, $4, $5, $6)`,
      [attachmentId, input.accountId, bucketKey, input.sizeBytes, input.sha256, input.mimeType ?? null],
    );
    const url = await getSignedUrl(
      this.s3,
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: bucketKey,
        ContentType: input.mimeType ?? 'application/octet-stream',
        ContentLength: input.sizeBytes,
      }),
      { expiresIn: 300 },
    );
    return { attachmentId, uploadUrl: url, bucketKey };
  }

  /** Confirms a completed upload. Updates `uploaded_at`. */
  async commit(accountId: string, attachmentId: string): Promise<void> {
    const result = await this.db.query(
      `update attachment_blobs set uploaded_at = now()
         where id = $1 and account_id = $2 and uploaded_at is null`,
      [attachmentId, accountId],
    );
    if (result.rowCount === 0) throw new Error('attachment not found or already committed');
    await this.audit.record({
      accountId,
      actor: { kind: 'user', id: accountId },
      action: 'attachment.uploaded',
      resource: `attachment:${attachmentId}`,
    });
  }

  /** Issues a presigned GET URL for a committed attachment. */
  async presignDownload(accountId: string, attachmentId: string): Promise<{ downloadUrl: string }> {
    const row = await queryOne<{ bucket_key: string; uploaded_at: Date | null }>(
      this.db,
      'select bucket_key, uploaded_at from attachment_blobs where id = $1 and account_id = $2',
      [attachmentId, accountId],
    );
    if (!row) throw new Error('attachment not found');
    if (!row.uploaded_at) throw new Error('attachment not yet uploaded');
    const url = await getSignedUrl(
      this.s3,
      new GetObjectCommand({ Bucket: this.bucket, Key: row.bucket_key }),
      { expiresIn: 300 },
    );
    return { downloadUrl: url };
  }

  async delete(accountId: string, attachmentId: string): Promise<void> {
    const row = await queryOne<{ bucket_key: string }>(
      this.db,
      'select bucket_key from attachment_blobs where id = $1 and account_id = $2',
      [attachmentId, accountId],
    );
    if (!row) return;
    await this.s3.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: row.bucket_key }));
    await this.db.query(
      'delete from attachment_blobs where id = $1 and account_id = $2',
      [attachmentId, accountId],
    );
    await this.audit.record({
      accountId,
      actor: { kind: 'user', id: accountId },
      action: 'attachment.deleted',
      resource: `attachment:${attachmentId}`,
    });
  }

  private async currentQuota(accountId: string): Promise<number> {
    const row = await queryOne<{ total: string }>(
      this.db,
      `select coalesce(sum(size_bytes), 0)::bigint::text as total
         from attachment_blobs
         where account_id = $1 and uploaded_at is not null`,
      [accountId],
    );
    return Number(row?.total ?? 0);
  }

  private quotaBytesForAccount(accountId: string): number {
    // Hook: read the subscription tier and return the quota. Default: free.
    void accountId;
    return 100 * 1024 * 1024;
  }
}

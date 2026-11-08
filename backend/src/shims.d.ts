/**
 * Minimal ambient types for third-party JS modules that do not ship their
 * own TypeScript declarations. We only declare the surface our services
 * actually use — expanding the shim as new APIs are introduced.
 */

declare module 'shamirs-secret-sharing' {
  export interface SplitOptions {
    shares: number;
    threshold: number;
  }

  /** Splits [secret] into [shares] parts, any [threshold] of which can be
   *  recombined with [combine] to recover the original. */
  export function split(secret: Buffer | Uint8Array, options: SplitOptions): Buffer[];

  /** Reconstructs the original secret from any subset of the shares
   *  returned by [split] that meets the threshold. */
  export function combine(shares: Array<Buffer | Uint8Array>): Buffer;

  const _default: { split: typeof split; combine: typeof combine };
  export default _default;
}

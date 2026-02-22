import { z } from "zod";

export const pairingPayloadSchema = z.object({
  /** Schema version */
  v: z.literal(1),
  /** Host IP address */
  h: z.string().min(1),
  /** SSH port */
  p: z.number().int().min(1).max(65535),
  /** Username */
  u: z.string().min(1),
  /** Hostname (display name) */
  n: z.string().min(1),
  /** Base64 host key wire bytes */
  hk: z.string().min(1),
  /** Key type (e.g. ssh-ed25519) */
  kt: z.string().min(1),
  /** SHA256 fingerprint */
  fp: z.string().startsWith("SHA256:"),
  /** Pairing URL */
  pu: z.string().url(),
  /** Pairing token (64 hex chars) */
  pt: z.string().length(64),
});

export type PairingPayload = z.infer<typeof pairingPayloadSchema>;

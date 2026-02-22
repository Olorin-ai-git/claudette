import crypto from "node:crypto";
import fs from "node:fs/promises";
import type { HostKeyInfo } from "../types/environment-info.js";

/**
 * Reads an OpenSSH public host key file and computes the SHA256 fingerprint.
 *
 * The fingerprint is computed as SHA256(wireBytes) where wireBytes is the
 * base64-decoded key data from the .pub file. This matches the iOS
 * KnownHost.fingerprintSHA256 computation: SHA256.hash(data: publicKeyData)
 * where publicKeyData is the same wire-format bytes.
 */
export async function readHostKey(hostKeyPath: string): Promise<HostKeyInfo> {
  const content = await fs.readFile(hostKeyPath, "utf-8");
  const parts = content.trim().split(/\s+/);

  // OpenSSH pub key format: <key-type> <base64-wire-bytes> [comment]
  const minimumParts = 2;
  if (parts.length < minimumParts) {
    throw new Error(`Invalid host key format in ${hostKeyPath}`);
  }

  const keyType = parts[0];
  const wireBase64 = parts[1];
  const wireBytes = Buffer.from(wireBase64, "base64");

  // SHA256 of the wire-format bytes, base64-encoded — matches iOS KnownHost
  const hash = crypto.createHash("sha256").update(wireBytes).digest();
  const fingerprint = "SHA256:" + hash.toString("base64");

  return {
    keyType,
    wireBase64,
    fingerprint,
  };
}

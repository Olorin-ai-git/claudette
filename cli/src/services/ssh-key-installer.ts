import fs from "node:fs/promises";
import path from "node:path";
import type { Logger } from "../logger.js";

/** Matches standard OpenSSH public key formats */
const SSH_KEY_PATTERN =
  /^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)\s+[A-Za-z0-9+/]+=*(\s+.*)?$/;

const DIR_PERMISSIONS = 0o700;
const FILE_PERMISSIONS = 0o600;

export async function installPublicKey(
  publicKey: string,
  authorizedKeysPath: string,
  log: Logger,
): Promise<void> {
  const trimmed = publicKey.trim();

  if (!SSH_KEY_PATTERN.test(trimmed)) {
    throw new Error(
      "Invalid OpenSSH public key format. Expected: ssh-ed25519 AAAA...",
    );
  }

  const sshDir = path.dirname(authorizedKeysPath);

  // Ensure .ssh directory exists with correct permissions
  await fs.mkdir(sshDir, { recursive: true, mode: DIR_PERMISSIONS });

  // Ensure authorized_keys exists
  try {
    await fs.access(authorizedKeysPath);
  } catch {
    await fs.writeFile(authorizedKeysPath, "", { mode: FILE_PERMISSIONS });
    log.debug(`Created ${authorizedKeysPath}`);
  }

  // Check for duplicate — compare key type + key data (ignore comment)
  const existing = await fs.readFile(authorizedKeysPath, "utf-8");
  const keyParts = trimmed.split(/\s+/);
  const keyIdentifier = keyParts.slice(0, 2).join(" ");

  if (existing.includes(keyIdentifier)) {
    log.debug("Key already present in authorized_keys, skipping");
    return;
  }

  // Append key with trailing newline
  const separator = existing.length > 0 && !existing.endsWith("\n") ? "\n" : "";
  await fs.appendFile(authorizedKeysPath, separator + trimmed + "\n", {
    mode: FILE_PERMISSIONS,
  });

  // Ensure file permissions are correct even if file existed with wrong perms
  await fs.chmod(authorizedKeysPath, FILE_PERMISSIONS);

  log.debug("Public key appended to authorized_keys");
}

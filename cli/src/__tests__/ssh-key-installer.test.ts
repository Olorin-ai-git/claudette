import { describe, it, expect, afterEach } from "vitest";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { installPublicKey } from "../services/ssh-key-installer.js";
import type { Logger } from "../logger.js";

const noopLogger: Logger = {
  info: () => {},
  success: () => {},
  warn: () => {},
  error: () => {},
  debug: () => {},
  blank: () => {},
  header: () => {},
};

const VALID_ED25519_KEY =
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl user@host";
const VALID_RSA_KEY =
  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7 user@host";
const VALID_ECDSA_KEY =
  "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTY= user@host";

describe("installPublicKey", () => {
  let tmpDir: string;

  afterEach(async () => {
    if (tmpDir) {
      await fs.rm(tmpDir, { recursive: true, force: true });
    }
  });

  function authKeysPath(): string {
    return path.join(tmpDir, ".ssh", "authorized_keys");
  }

  async function setup(): Promise<string> {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "sshkey-test-"));
    return authKeysPath();
  }

  it("rejects invalid key format", async () => {
    const akPath = await setup();
    await expect(
      installPublicKey("not a valid key", akPath, noopLogger),
    ).rejects.toThrow("Invalid OpenSSH public key format");
  });

  it("accepts valid ed25519 key", async () => {
    const akPath = await setup();
    await installPublicKey(VALID_ED25519_KEY, akPath, noopLogger);
    const content = await fs.readFile(akPath, "utf-8");
    expect(content).toContain("ssh-ed25519");
  });

  it("accepts valid rsa key", async () => {
    const akPath = await setup();
    await installPublicKey(VALID_RSA_KEY, akPath, noopLogger);
    const content = await fs.readFile(akPath, "utf-8");
    expect(content).toContain("ssh-rsa");
  });

  it("accepts valid ecdsa key", async () => {
    const akPath = await setup();
    await installPublicKey(VALID_ECDSA_KEY, akPath, noopLogger);
    const content = await fs.readFile(akPath, "utf-8");
    expect(content).toContain("ecdsa-sha2-nistp256");
  });

  it("creates directory and file if missing", async () => {
    const akPath = await setup();
    // Neither .ssh dir nor authorized_keys exist yet
    await installPublicKey(VALID_ED25519_KEY, akPath, noopLogger);
    const stat = await fs.stat(akPath);
    expect(stat.isFile()).toBe(true);
  });

  it("detects duplicate keys and skips", async () => {
    const akPath = await setup();
    await installPublicKey(VALID_ED25519_KEY, akPath, noopLogger);
    await installPublicKey(VALID_ED25519_KEY, akPath, noopLogger);
    const content = await fs.readFile(akPath, "utf-8");
    const matches = content.match(/ssh-ed25519/g);
    expect(matches).toHaveLength(1);
  });

  it("appends key with proper newline handling", async () => {
    const akPath = await setup();
    // Install first key
    await installPublicKey(VALID_ED25519_KEY, akPath, noopLogger);
    // Install second different key
    await installPublicKey(VALID_RSA_KEY, akPath, noopLogger);
    const content = await fs.readFile(akPath, "utf-8");
    const lines = content.split("\n").filter((l) => l.length > 0);
    expect(lines).toHaveLength(2);
    expect(lines[0]).toContain("ssh-ed25519");
    expect(lines[1]).toContain("ssh-rsa");
  });
});

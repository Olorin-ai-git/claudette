import { describe, it, expect, afterEach } from "vitest";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { readHostKey } from "../services/host-key-reader.js";

describe("readHostKey", () => {
  let tmpDir: string;

  afterEach(async () => {
    if (tmpDir) {
      await fs.rm(tmpDir, { recursive: true, force: true });
    }
  });

  async function writeTmpKey(content: string): Promise<string> {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "hostkey-test-"));
    const keyPath = path.join(tmpDir, "host_key.pub");
    await fs.writeFile(keyPath, content);
    return keyPath;
  }

  it("reads a valid host key file", async () => {
    const keyPath = await writeTmpKey(
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl host@example",
    );
    const info = await readHostKey(keyPath);
    expect(info.keyType).toBe("ssh-ed25519");
    expect(info.wireBase64).toBe(
      "AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl",
    );
    expect(info.fingerprint).toMatch(/^SHA256:/);
  });

  it("computes correct SHA256 fingerprint", async () => {
    const wireBase64 =
      "AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    const keyPath = await writeTmpKey(`ssh-ed25519 ${wireBase64} comment`);
    const info = await readHostKey(keyPath);

    const expectedHash = crypto
      .createHash("sha256")
      .update(Buffer.from(wireBase64, "base64"))
      .digest();
    const expectedFingerprint = "SHA256:" + expectedHash.toString("base64");

    expect(info.fingerprint).toBe(expectedFingerprint);
  });

  it("throws on invalid format (single token)", async () => {
    const keyPath = await writeTmpKey("just-one-token");
    await expect(readHostKey(keyPath)).rejects.toThrow("Invalid host key format");
  });

  it("throws on missing file", async () => {
    await expect(readHostKey("/nonexistent/path/key.pub")).rejects.toThrow();
  });
});

import { describe, it, expect, beforeEach } from "vitest";
import { loadConfig } from "../config.js";

describe("loadConfig", () => {
  const envBackup: Record<string, string | undefined> = {};

  beforeEach(() => {
    // Save and clear relevant env vars
    const keys = [
      "CLAUDETTE_SSH_PORT",
      "CLAUDETTE_TOKEN_TTL_MS",
      "CLAUDETTE_HOST_KEY_PATH",
      "CLAUDETTE_AUTHORIZED_KEYS_PATH",
      "CLAUDETTE_DEBUG",
    ];
    for (const key of keys) {
      envBackup[key] = process.env[key];
      delete process.env[key];
    }
  });

  beforeEach(() => {
    // Restore env vars after each test
    return () => {
      for (const [key, value] of Object.entries(envBackup)) {
        if (value === undefined) {
          delete process.env[key];
        } else {
          process.env[key] = value;
        }
      }
    };
  });

  it("returns default values when no overrides given", () => {
    const config = loadConfig();
    expect(config.sshPort).toBe(22);
    expect(config.tokenTtlMs).toBe(300_000);
    expect(config.hostKeyPath).toBe("/etc/ssh/ssh_host_ed25519_key.pub");
    expect(config.debug).toBe(false);
  });

  it("accepts port override", () => {
    const config = loadConfig({ sshPort: 2222 });
    expect(config.sshPort).toBe(2222);
  });

  it("accepts debug override", () => {
    const config = loadConfig({ debug: true });
    expect(config.debug).toBe(true);
  });

  it("throws on port 0", () => {
    expect(() => loadConfig({ sshPort: 0 })).toThrow();
  });

  it("throws on port 65536", () => {
    expect(() => loadConfig({ sshPort: 65536 })).toThrow();
  });

  it("throws on negative port", () => {
    expect(() => loadConfig({ sshPort: -1 })).toThrow();
  });

  it("coerces debug from string 'true'", () => {
    process.env.CLAUDETTE_DEBUG = "true";
    const config = loadConfig();
    expect(config.debug).toBe(true);
  });

  it("coerces debug from string '1'", () => {
    process.env.CLAUDETTE_DEBUG = "1";
    const config = loadConfig();
    expect(config.debug).toBe(true);
  });

  it("coerces debug from boolean true via override", () => {
    const config = loadConfig({ debug: true });
    expect(config.debug).toBe(true);
  });
});

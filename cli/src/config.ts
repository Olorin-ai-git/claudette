import os from "node:os";
import path from "node:path";
import { z } from "zod";

const configSchema = z.object({
  sshPort: z.coerce.number().int().min(1).max(65535),
  tokenTtlMs: z.coerce.number().int().min(60_000),
  hostKeyPath: z.string().min(1),
  authorizedKeysPath: z.string().min(1),
  debug: z.preprocess(
    (val) => val === true || val === "true" || val === "1",
    z.boolean(),
  ),
});

export type AppConfig = z.infer<typeof configSchema>;

export interface ConfigOverrides {
  sshPort?: number;
  debug?: boolean;
}

export function loadConfig(overrides?: ConfigOverrides): AppConfig {
  const defaultSshPort = 22;
  const defaultTokenTtlMs = 300_000;
  const defaultHostKeyPath = "/etc/ssh/ssh_host_ed25519_key.pub";
  const defaultAuthorizedKeysPath = path.join(
    os.homedir(),
    ".ssh",
    "authorized_keys",
  );

  return configSchema.parse({
    sshPort:
      overrides?.sshPort ?? process.env.CLAUDETTE_SSH_PORT ?? defaultSshPort,
    tokenTtlMs: process.env.CLAUDETTE_TOKEN_TTL_MS ?? defaultTokenTtlMs,
    hostKeyPath: process.env.CLAUDETTE_HOST_KEY_PATH ?? defaultHostKeyPath,
    authorizedKeysPath:
      process.env.CLAUDETTE_AUTHORIZED_KEYS_PATH ?? defaultAuthorizedKeysPath,
    debug: overrides?.debug ?? process.env.CLAUDETTE_DEBUG ?? false,
  });
}

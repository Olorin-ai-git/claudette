import chalk from "chalk";
import ora from "ora";
import { type AppConfig, loadConfig } from "../config.js";
import { createLogger, type Logger } from "../logger.js";
import { generateToken } from "../utils/crypto.js";
import {
  detectEnvironment,
  findIssues,
} from "../services/environment-detector.js";
import { resolveIssues } from "../services/issue-resolver.js";
import { readHostKey } from "../services/host-key-reader.js";
import { startPairingServer } from "../services/pairing-server.js";
import { displayQrCode } from "../services/qr-generator.js";
import { installPublicKey } from "../services/ssh-key-installer.js";
import {
  pairingPayloadSchema,
  type PairingPayload,
} from "../types/pairing-payload.js";
import type { EnvironmentInfo } from "../types/environment-info.js";

export interface SetupOptions {
  port?: number;
  ip?: string;
  skipChecks?: boolean;
  debug?: boolean;
}

function displayEnvironment(env: EnvironmentInfo, log: Logger): void {
  log.success(`Detected: ${env.username}@${env.hostname}`);

  if (env.sshEnabled) {
    log.success(`Remote Login: enabled (port ${String(env.sshPort)})`);
  } else {
    log.error("Remote Login: disabled");
  }

  if (env.tailscaleIp) {
    log.success(`Tailscale: ${env.tailscaleIp}`);
  } else if (env.tailscaleInstalled) {
    log.warn("Tailscale: installed but no IPv4 address (not logged in?)");
  } else {
    log.warn("Tailscale: not installed");
  }

  if (env.localIp) {
    log.info(chalk.dim(`Local IP: ${env.localIp}`));
  }

  if (env.tmuxPath) {
    log.success(`tmux: ${env.tmuxPath}`);
  } else {
    log.error("tmux: not found");
  }

  if (env.claudePath) {
    log.success(`Claude Code: ${env.claudePath}`);
  } else {
    log.warn("Claude Code: not found");
  }

  if (env.hostKey) {
    log.success(`Host key: ${env.hostKey.fingerprint}`);
  } else {
    log.error("Host key: not found");
  }
}

function formatCountdown(ms: number): string {
  const totalSeconds = Math.ceil(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${String(minutes)}:${String(seconds).padStart(2, "0")}`;
}

export async function runSetup(options: SetupOptions): Promise<void> {
  const config: AppConfig = loadConfig({
    sshPort: options.port,
    debug: options.debug,
  });

  const log = createLogger(config.debug);

  log.header("Claudette Setup");

  // Step 1: Detect environment
  const spinner = ora({ text: "Detecting environment...", indent: 2 }).start();

  let env: EnvironmentInfo;
  try {
    env = await detectEnvironment(config, log);
    spinner.stop();
  } catch (err) {
    spinner.fail("Environment detection failed");
    log.error(String(err));
    process.exitCode = 1;
    return;
  }

  // Step 2: Display results
  displayEnvironment(env, log);

  // Step 3: Resolve issues
  if (!options.skipChecks) {
    const issues = findIssues(env);

    if (issues.length > 0) {
      log.blank();
      log.header("Issues to resolve");

      const allResolved = await resolveIssues(issues, log);
      if (!allResolved) {
        process.exitCode = 1;
        return;
      }

      // Re-detect after resolutions (SSH may have been enabled, tmux installed, etc.)
      const recheckSpinner = ora({
        text: "Re-checking environment...",
        indent: 2,
      }).start();
      env = await detectEnvironment(config, log);
      recheckSpinner.stop();

      // Verify critical requirements met
      if (!env.sshEnabled) {
        log.error("Remote Login is still disabled. Cannot continue.");
        process.exitCode = 1;
        return;
      }
      if (!env.tmuxPath) {
        log.error("tmux is still not installed. Cannot continue.");
        process.exitCode = 1;
        return;
      }
    }
  }

  // Step 4: Determine IP to use
  const ip = options.ip ?? env.tailscaleIp ?? env.localIp;
  if (!ip) {
    log.error("Could not determine an IP address. Use --ip to specify one.");
    process.exitCode = 1;
    return;
  }

  // Step 5: Read host key (may need re-read if SSH was just enabled)
  let hostKey = env.hostKey;
  if (!hostKey) {
    try {
      hostKey = await readHostKey(config.hostKeyPath);
    } catch {
      log.error(
        `Cannot read host key at ${config.hostKeyPath}. Ensure SSH is enabled.`,
      );
      process.exitCode = 1;
      return;
    }
  }

  // Step 6: Generate token and start pairing server
  const token = generateToken();
  log.debug(`Pairing token: ${token}`);

  const pairingServer = await startPairingServer({
    token,
    ttlMs: config.tokenTtlMs,
    log,
  });

  // Step 7: Build and display QR payload
  const payload: PairingPayload = pairingPayloadSchema.parse({
    v: 1,
    h: ip,
    p: config.sshPort,
    u: env.username,
    n: env.hostname,
    hk: hostKey.wireBase64,
    kt: hostKey.keyType,
    fp: hostKey.fingerprint,
    pu: `http://${ip}:${String(pairingServer.port)}/pair`,
    pt: token,
  });

  log.blank();
  await displayQrCode(payload, log);

  // Step 8: Wait for pairing with countdown
  const ttlSeconds = Math.ceil(config.tokenTtlMs / 1000);
  let remainingMs = config.tokenTtlMs;
  const countdownInterval = 1000;

  const waitSpinner = ora({
    text: `Waiting for pairing... (expires in ${formatCountdown(remainingMs)})`,
    indent: 2,
  }).start();

  const countdownTimer = setInterval(() => {
    remainingMs -= countdownInterval;
    if (remainingMs > 0) {
      waitSpinner.text = `Waiting for pairing... (expires in ${formatCountdown(remainingMs)})`;
    }
  }, countdownInterval);

  try {
    const result = await pairingServer.waitForPairing();
    clearInterval(countdownTimer);
    waitSpinner.succeed("Pairing request received!");

    // Step 9: Install the public key
    const installSpinner = ora({
      text: "Installing SSH key...",
      indent: 2,
    }).start();

    try {
      await installPublicKey(result.publicKey, config.authorizedKeysPath, log);
      installSpinner.succeed(
        `Pairing complete! Key installed for device "${result.deviceName}".`,
      );
    } catch (err) {
      installSpinner.fail("Failed to install SSH key");
      log.error(String(err));
      process.exitCode = 1;
    }
  } catch (err) {
    clearInterval(countdownTimer);
    waitSpinner.fail("Pairing timed out or failed");
    log.error(String(err));
    process.exitCode = 1;
  } finally {
    pairingServer.close();
  }
}

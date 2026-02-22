import os from "node:os";
import type { AppConfig } from "../config.js";
import type { Logger } from "../logger.js";
import type {
  EnvironmentInfo,
  EnvironmentIssue,
} from "../types/environment-info.js";
import {
  getLocalIp,
  getTailscaleIp,
  isTailscaleInstalled,
} from "../utils/network.js";
import { commandExists, exec } from "../utils/shell.js";
import { readHostKey } from "./host-key-reader.js";

async function detectSshEnabled(): Promise<boolean> {
  try {
    const { stdout } = await exec("sudo", ["systemsetup", "-getremotelogin"]);
    return stdout.toLowerCase().includes("on");
  } catch {
    // Fallback: check if sshd is running
    try {
      const { stdout } = await exec("launchctl", ["list", "com.openssh.sshd"]);
      return stdout.length > 0;
    } catch {
      return false;
    }
  }
}

export async function detectEnvironment(
  config: AppConfig,
  log: Logger,
): Promise<EnvironmentInfo> {
  log.debug("Starting environment detection");

  const [
    sshEnabled,
    tailscaleIp,
    tailscaleInstalled,
    localIp,
    tmuxPath,
    claudePath,
    hostKey,
  ] = await Promise.all([
    detectSshEnabled(),
    getTailscaleIp(),
    isTailscaleInstalled(),
    Promise.resolve(getLocalIp()),
    commandExists("tmux"),
    commandExists("claude"),
    readHostKey(config.hostKeyPath).catch((err) => {
      log.debug(`Host key read failed: ${String(err)}`);
      return null;
    }),
  ]);

  return {
    username: os.userInfo().username,
    hostname: os.hostname(),
    sshEnabled,
    sshPort: config.sshPort,
    tailscaleIp,
    tailscaleInstalled,
    localIp,
    tmuxPath,
    claudePath,
    hostKey,
  };
}

export function findIssues(env: EnvironmentInfo): EnvironmentIssue[] {
  const issues: EnvironmentIssue[] = [];

  if (!env.sshEnabled) {
    issues.push({
      id: "ssh_disabled",
      label: "Remote Login (SSH) is disabled",
      severity: "error",
    });
  }

  if (!env.tailscaleInstalled) {
    issues.push({
      id: "tailscale_missing",
      label:
        "Tailscale is not installed (connection limited to same WiFi network)",
      severity: "warning",
    });
  }

  if (!env.tmuxPath) {
    issues.push({
      id: "tmux_missing",
      label: "tmux is not installed (required for persistent sessions)",
      severity: "error",
    });
  }

  if (!env.claudePath) {
    issues.push({
      id: "claude_missing",
      label: "Claude Code is not installed",
      severity: "warning",
    });
  }

  if (!env.hostKey) {
    issues.push({
      id: "no_host_key",
      label: "SSH host key not found",
      severity: "error",
    });
  }

  return issues;
}

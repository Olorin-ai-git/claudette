import readline from "node:readline/promises";
import chalk from "chalk";
import type { Logger } from "../logger.js";
import type { EnvironmentIssue } from "../types/environment-info.js";
import { exec } from "../utils/shell.js";

async function askYesNo(
  rl: readline.Interface,
  question: string,
): Promise<boolean> {
  const answer = await rl.question(chalk.yellow(`  ? ${question} (y/n) `));
  return answer.trim().toLowerCase().startsWith("y");
}

async function resolveSshDisabled(
  rl: readline.Interface,
  log: Logger,
): Promise<boolean> {
  log.warn("Remote Login (SSH) must be enabled for Claudette to connect.");
  log.blank();

  const useCommand = await askYesNo(
    rl,
    "Enable Remote Login via terminal? (requires sudo)",
  );

  if (useCommand) {
    try {
      await exec("sudo", ["systemsetup", "-setremotelogin", "on"]);
      log.success("Remote Login enabled.");
      return true;
    } catch (err) {
      log.error(`Failed to enable Remote Login: ${String(err)}`);
      log.info(
        "You can enable it manually: System Settings > General > Sharing > Remote Login",
      );
      return false;
    }
  }

  log.info(
    "Please enable Remote Login manually: System Settings > General > Sharing > Remote Login",
  );
  log.info("Then re-run this setup.");
  return false;
}

async function resolveTailscaleMissing(
  rl: readline.Interface,
  log: Logger,
): Promise<boolean> {
  log.warn(
    "Tailscale is not installed. Tailscale is an industry-standard mesh VPN",
  );
  log.info(
    "used by hundreds of thousands of developers. It gives your devices stable",
  );
  log.info(
    "IP addresses that work from anywhere \u2014 not just your home WiFi.",
  );
  log.blank();
  log.info(
    chalk.dim(
      "Without Tailscale, Claudette will only work when your phone and Mac",
    ),
  );
  log.info(
    chalk.dim(
      "are on the same WiFi network. Tailscale removes that limitation.",
    ),
  );
  log.blank();

  const install = await askYesNo(rl, "Would you like to install Tailscale?");

  if (install) {
    const useBrew = await askYesNo(rl, "Install via Homebrew? (recommended)");

    if (useBrew) {
      try {
        log.info(
          "Installing Tailscale via Homebrew (this may take a moment)...",
        );
        await exec("brew", ["install", "--cask", "tailscale"], {
          timeout: 120_000,
        });
        log.success(
          "Tailscale installed. Please open it from Applications and sign in.",
        );
        log.info(
          "After signing in, re-run this setup to use your Tailscale IP.",
        );
        return false; // Need to re-run after Tailscale login
      } catch (err) {
        log.error(`Homebrew install failed: ${String(err)}`);
        log.info(
          "You can download Tailscale from: https://tailscale.com/download/mac",
        );
        return false;
      }
    }

    log.info("Download Tailscale from: https://tailscale.com/download/mac");
    log.info("After installing and signing in, re-run this setup.");
    return false;
  }

  // User declined installation
  log.blank();
  log.warn(
    chalk.bold(
      "Without Tailscale, your connection will be limited to WiFi only.",
    ),
  );

  const proceed = await askYesNo(
    rl,
    "Continue with WiFi-only setup? (your local IP will be used)",
  );

  if (proceed) {
    log.info("Proceeding with local WiFi IP. You can install Tailscale later.");
    return true; // Continue without Tailscale — use local IP
  }

  log.info("Setup cancelled. Install Tailscale and re-run when ready.");
  return false;
}

async function resolveTmuxMissing(
  rl: readline.Interface,
  log: Logger,
): Promise<boolean> {
  log.warn("tmux is required for persistent terminal sessions.");
  const install = await askYesNo(rl, "Install tmux via Homebrew?");

  if (install) {
    try {
      log.info("Installing tmux...");
      await exec("brew", ["install", "tmux"], { timeout: 120_000 });
      log.success("tmux installed.");
      return true;
    } catch (err) {
      log.error(`Failed to install tmux: ${String(err)}`);
      return false;
    }
  }

  log.info("Please install tmux (e.g. `brew install tmux`) and re-run.");
  return false;
}

async function resolveClaudeMissing(
  rl: readline.Interface,
  log: Logger,
): Promise<boolean> {
  log.warn("Claude Code is not installed (optional, but recommended).");
  const install = await askYesNo(rl, "Install Claude Code via npm?");

  if (install) {
    try {
      log.info("Installing Claude Code...");
      await exec("npm", ["install", "-g", "@anthropic-ai/claude-code"], {
        timeout: 120_000,
      });
      log.success("Claude Code installed.");
      return true;
    } catch (err) {
      log.error(`Failed to install Claude Code: ${String(err)}`);
      log.info(
        "You can install it manually: npm install -g @anthropic-ai/claude-code",
      );
      return true; // Non-blocking, continue anyway
    }
  }

  log.info(
    "You can install it later: npm install -g @anthropic-ai/claude-code",
  );
  return true; // Non-blocking
}

export async function resolveIssues(
  issues: EnvironmentIssue[],
  log: Logger,
): Promise<boolean> {
  if (issues.length === 0) return true;

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  try {
    for (const issue of issues) {
      log.blank();
      let resolved = false;

      switch (issue.id) {
        case "ssh_disabled":
          resolved = await resolveSshDisabled(rl, log);
          break;
        case "tailscale_missing":
          resolved = await resolveTailscaleMissing(rl, log);
          break;
        case "tmux_missing":
          resolved = await resolveTmuxMissing(rl, log);
          break;
        case "claude_missing":
          resolved = await resolveClaudeMissing(rl, log);
          break;
        case "no_host_key":
          log.error(
            "SSH host key not found. Ensure Remote Login is enabled and try again.",
          );
          resolved = false;
          break;
      }

      if (!resolved && issue.severity === "error") {
        log.blank();
        log.error("Cannot continue until this issue is resolved.");
        return false;
      }
    }

    return true;
  } finally {
    rl.close();
  }
}

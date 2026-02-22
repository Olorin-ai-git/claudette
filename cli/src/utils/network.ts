import os from "node:os";
import { exec } from "./shell.js";

export async function getTailscaleIp(): Promise<string | null> {
  try {
    const { stdout } = await exec("tailscale", ["ip", "-4"]);
    const ip = stdout.trim().split("\n")[0];
    return ip || null;
  } catch {
    return null;
  }
}

export async function isTailscaleInstalled(): Promise<boolean> {
  try {
    await exec("which", ["tailscale"]);
    return true;
  } catch {
    return false;
  }
}

const PREFERRED_INTERFACES = ["en0", "en1"];

export function getLocalIp(): string | null {
  const interfaces = os.networkInterfaces();
  const orderedNames = [
    ...PREFERRED_INTERFACES,
    ...Object.keys(interfaces).filter((n) => !PREFERRED_INTERFACES.includes(n)),
  ];

  for (const name of orderedNames) {
    const iface = interfaces[name];
    if (!iface) continue;
    for (const info of iface) {
      if (info.family === "IPv4" && !info.internal) {
        return info.address;
      }
    }
  }
  return null;
}

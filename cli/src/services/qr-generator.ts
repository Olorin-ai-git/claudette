import QRCode from "qrcode";
import chalk from "chalk";
import type { PairingPayload } from "../types/pairing-payload.js";
import type { Logger } from "../logger.js";

export async function displayQrCode(
  payload: PairingPayload,
  log: Logger,
): Promise<void> {
  const json = JSON.stringify(payload);
  log.debug(`QR payload (${String(json.length)} bytes): ${json}`);

  const qrString = await QRCode.toString(json, {
    type: "utf8",
    errorCorrectionLevel: "M",
    margin: 2,
  });

  process.stdout.write("\n");
  for (const line of qrString.split("\n")) {
    if (line.trim()) {
      process.stdout.write("  " + line + "\n");
    }
  }
  process.stdout.write("\n");

  log.info("Scan this QR code with the Claudette app to pair.\n");

  // Manual fallback for accessibility
  log.info(chalk.dim("Or configure manually:"));
  log.info(chalk.dim(`  Host: ${payload.h}`));
  log.info(chalk.dim(`  Port: ${String(payload.p)}`));
  log.info(chalk.dim(`  User: ${payload.u}`));
  log.info(chalk.dim(`  Fingerprint: ${payload.fp}`));
}

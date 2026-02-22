import http from "node:http";
import type { Logger } from "../logger.js";
import { constantTimeEqual } from "../utils/crypto.js";

export interface PairingResult {
  publicKey: string;
  deviceName: string;
}

interface PairingServerOptions {
  token: string;
  ttlMs: number;
  log: Logger;
}

export interface PairingServer {
  port: number;
  waitForPairing(): Promise<PairingResult>;
  close(): void;
}

export function startPairingServer(
  options: PairingServerOptions,
): Promise<PairingServer> {
  const { token, ttlMs, log } = options;

  return new Promise((resolveStart, rejectStart) => {
    let paired = false;
    let pairingResolve: ((result: PairingResult) => void) | null = null;
    let pairingReject: ((err: Error) => void) | null = null;

    const server = http.createServer((req, res) => {
      res.setHeader("Access-Control-Allow-Origin", "*");
      res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
      res.setHeader("Access-Control-Allow-Headers", "Content-Type");

      if (req.method === "OPTIONS") {
        res.writeHead(204);
        res.end();
        return;
      }

      if (req.method !== "POST" || req.url !== "/pair") {
        res.writeHead(404, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Not found" }));
        return;
      }

      let body = "";
      req.on("data", (chunk: Buffer) => {
        body += chunk.toString();
      });

      req.on("end", () => {
        try {
          const data = JSON.parse(body) as Record<string, unknown>;

          if (
            typeof data.token !== "string" ||
            typeof data.publicKey !== "string"
          ) {
            res.writeHead(400, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "Missing token or publicKey" }));
            return;
          }

          if (!constantTimeEqual(data.token, token)) {
            log.debug("Pairing attempt with invalid token");
            res.writeHead(403, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "Invalid token" }));
            return;
          }

          if (paired) {
            res.writeHead(409, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "Already paired" }));
            return;
          }

          paired = true;
          res.writeHead(200, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ success: true }));

          log.debug("Pairing request accepted");

          const result: PairingResult = {
            publicKey: data.publicKey,
            deviceName:
              typeof data.deviceName === "string"
                ? data.deviceName
                : "Unknown device",
          };

          pairingResolve?.(result);
        } catch {
          res.writeHead(400, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: "Invalid JSON" }));
        }
      });
    });

    server.on("error", (err) => {
      rejectStart(err);
    });

    // Listen on port 0 to get a random available port
    server.listen(0, () => {
      const addr = server.address();
      const port = typeof addr === "object" && addr ? addr.port : 0;

      log.debug(`Pairing server listening on port ${String(port)}`);

      // Auto-shutdown after TTL expires
      const ttlTimer = setTimeout(() => {
        if (!paired) {
          log.debug("Pairing server TTL expired");
          pairingReject?.(new Error("Pairing timed out"));
          server.close();
        }
      }, ttlMs);

      resolveStart({
        port,

        waitForPairing(): Promise<PairingResult> {
          return new Promise<PairingResult>((resolve, reject) => {
            if (paired) {
              reject(new Error("Already paired"));
              return;
            }
            pairingResolve = resolve;
            pairingReject = reject;
          });
        },

        close() {
          clearTimeout(ttlTimer);
          server.close();
        },
      });
    });
  });
}

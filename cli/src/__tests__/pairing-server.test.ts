import { describe, it, expect, afterEach } from "vitest";
import { startPairingServer, type PairingServer } from "../services/pairing-server.js";
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

const TEST_TOKEN = "a".repeat(64);

async function makeRequest(
  port: number,
  method: string,
  urlPath: string,
  body?: unknown,
): Promise<{ status: number; body: Record<string, unknown> }> {
  const res = await fetch(`http://127.0.0.1:${port}${urlPath}`, {
    method,
    headers: { "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = (await res.json()) as Record<string, unknown>;
  return { status: res.status, body: json };
}

describe("pairing-server", () => {
  let server: PairingServer | null = null;

  afterEach(() => {
    server?.close();
    server = null;
  });

  it("starts on a random port", async () => {
    server = await startPairingServer({
      token: TEST_TOKEN,
      ttlMs: 60_000,
      log: noopLogger,
    });
    expect(server.port).toBeGreaterThan(0);
  });

  it("returns success for valid pairing", async () => {
    server = await startPairingServer({
      token: TEST_TOKEN,
      ttlMs: 60_000,
      log: noopLogger,
    });

    const pairingPromise = server.waitForPairing();

    const res = await makeRequest(server.port, "POST", "/pair", {
      token: TEST_TOKEN,
      publicKey: "ssh-ed25519 AAAA test",
      deviceName: "test-device",
    });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const result = await pairingPromise;
    expect(result.publicKey).toBe("ssh-ed25519 AAAA test");
    expect(result.deviceName).toBe("test-device");
  });

  it("returns 403 for invalid token", async () => {
    server = await startPairingServer({
      token: TEST_TOKEN,
      ttlMs: 60_000,
      log: noopLogger,
    });

    const res = await makeRequest(server.port, "POST", "/pair", {
      token: "wrong-token",
      publicKey: "ssh-ed25519 AAAA test",
    });

    expect(res.status).toBe(403);
    expect(res.body.error).toBe("Invalid token");
  });

  it("returns 400 for invalid JSON", async () => {
    server = await startPairingServer({
      token: TEST_TOKEN,
      ttlMs: 60_000,
      log: noopLogger,
    });

    const res = await fetch(`http://127.0.0.1:${server.port}/pair`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "not valid json{{{",
    });

    expect(res.status).toBe(400);
    const json = (await res.json()) as Record<string, unknown>;
    expect(json.error).toBe("Invalid JSON");
  });

  it("returns 400 for missing fields", async () => {
    server = await startPairingServer({
      token: TEST_TOKEN,
      ttlMs: 60_000,
      log: noopLogger,
    });

    const res = await makeRequest(server.port, "POST", "/pair", {
      token: TEST_TOKEN,
      // publicKey is missing
    });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe("Missing token or publicKey");
  });

  it("returns 409 on double pairing", async () => {
    server = await startPairingServer({
      token: TEST_TOKEN,
      ttlMs: 60_000,
      log: noopLogger,
    });

    const pairingPromise = server.waitForPairing();

    await makeRequest(server.port, "POST", "/pair", {
      token: TEST_TOKEN,
      publicKey: "ssh-ed25519 AAAA test",
    });

    await pairingPromise;

    const res = await makeRequest(server.port, "POST", "/pair", {
      token: TEST_TOKEN,
      publicKey: "ssh-ed25519 AAAA test2",
    });

    expect(res.status).toBe(409);
    expect(res.body.error).toBe("Already paired");
  });

  it("returns 204 for OPTIONS (CORS)", async () => {
    server = await startPairingServer({
      token: TEST_TOKEN,
      ttlMs: 60_000,
      log: noopLogger,
    });

    const res = await fetch(`http://127.0.0.1:${server.port}/pair`, {
      method: "OPTIONS",
    });

    expect(res.status).toBe(204);
  });

  it("returns 404 for non-/pair path", async () => {
    server = await startPairingServer({
      token: TEST_TOKEN,
      ttlMs: 60_000,
      log: noopLogger,
    });

    const res = await makeRequest(server.port, "POST", "/other", {
      token: TEST_TOKEN,
      publicKey: "ssh-ed25519 AAAA test",
    });

    expect(res.status).toBe(404);
    expect(res.body.error).toBe("Not found");
  });
});

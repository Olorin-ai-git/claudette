import { describe, it, expect } from "vitest";
import { pairingPayloadSchema } from "../types/pairing-payload.js";

function validPayload() {
  return {
    v: 1,
    h: "192.168.1.100",
    p: 22,
    u: "testuser",
    n: "test-host",
    hk: "AAAAC3NzaC1lZDI1NTE5AAAAIG==",
    kt: "ssh-ed25519",
    fp: "SHA256:abc123def456",
    pu: "http://192.168.1.100:12345/pair",
    pt: "a".repeat(64),
  };
}

describe("pairingPayloadSchema", () => {
  it("accepts a valid payload", () => {
    const result = pairingPayloadSchema.safeParse(validPayload());
    expect(result.success).toBe(true);
  });

  it("rejects missing fields", () => {
    const { h: _h, ...incomplete } = validPayload();
    const result = pairingPayloadSchema.safeParse(incomplete);
    expect(result.success).toBe(false);
  });

  it("rejects port 0", () => {
    const result = pairingPayloadSchema.safeParse({ ...validPayload(), p: 0 });
    expect(result.success).toBe(false);
  });

  it("rejects port 65536", () => {
    const result = pairingPayloadSchema.safeParse({ ...validPayload(), p: 65536 });
    expect(result.success).toBe(false);
  });

  it("rejects token with wrong length", () => {
    const result = pairingPayloadSchema.safeParse({ ...validPayload(), pt: "short" });
    expect(result.success).toBe(false);
  });

  it("rejects fingerprint without SHA256: prefix", () => {
    const result = pairingPayloadSchema.safeParse({
      ...validPayload(),
      fp: "MD5:abc123",
    });
    expect(result.success).toBe(false);
  });

  it("rejects invalid URL", () => {
    const result = pairingPayloadSchema.safeParse({
      ...validPayload(),
      pu: "not-a-url",
    });
    expect(result.success).toBe(false);
  });
});

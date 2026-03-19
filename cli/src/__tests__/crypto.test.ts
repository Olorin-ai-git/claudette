import { describe, it, expect } from "vitest";
import { generateToken, constantTimeEqual } from "../utils/crypto.js";

describe("generateToken", () => {
  it("returns a 64-character hex string", () => {
    const token = generateToken();
    expect(token).toHaveLength(64);
    expect(token).toMatch(/^[0-9a-f]{64}$/);
  });

  it("returns unique values on each call", () => {
    const tokens = new Set(Array.from({ length: 10 }, () => generateToken()));
    expect(tokens.size).toBe(10);
  });
});

describe("constantTimeEqual", () => {
  it("returns true for matching strings", () => {
    expect(constantTimeEqual("hello", "hello")).toBe(true);
    expect(constantTimeEqual("", "")).toBe(true);
    expect(constantTimeEqual("abc123", "abc123")).toBe(true);
  });

  it("returns false for different strings of the same length", () => {
    expect(constantTimeEqual("hello", "world")).toBe(false);
    expect(constantTimeEqual("abc", "abd")).toBe(false);
  });

  it("returns false for strings of different lengths", () => {
    expect(constantTimeEqual("short", "longer string")).toBe(false);
    expect(constantTimeEqual("a", "ab")).toBe(false);
    expect(constantTimeEqual("", "x")).toBe(false);
  });
});

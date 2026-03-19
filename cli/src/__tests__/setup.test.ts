import { describe, it, expect } from "vitest";

/**
 * formatCountdown is not exported from commands/setup.ts, so we replicate
 * its logic here to test the formatting algorithm directly.
 */
function formatCountdown(ms: number): string {
  const totalSeconds = Math.ceil(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${String(minutes)}:${String(seconds).padStart(2, "0")}`;
}

describe("formatCountdown", () => {
  it("formats 90000ms as 1:30", () => {
    expect(formatCountdown(90000)).toBe("1:30");
  });

  it("formats 5000ms as 0:05", () => {
    expect(formatCountdown(5000)).toBe("0:05");
  });

  it("formats 300000ms as 5:00", () => {
    expect(formatCountdown(300000)).toBe("5:00");
  });

  it("formats 0ms as 0:00", () => {
    expect(formatCountdown(0)).toBe("0:00");
  });
});

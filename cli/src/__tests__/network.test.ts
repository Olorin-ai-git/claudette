import { describe, it, expect, vi, beforeEach } from "vitest";
import os from "node:os";

vi.mock("node:os", async () => {
  const actual = await vi.importActual<typeof import("node:os")>("node:os");
  return { ...actual, default: { ...actual, networkInterfaces: vi.fn() } };
});

import { getLocalIp } from "../utils/network.js";

const mockedNetworkInterfaces = vi.mocked(os.networkInterfaces);

beforeEach(() => {
  vi.restoreAllMocks();
});

describe("getLocalIp", () => {
  it("returns IPv4 address from preferred interfaces", () => {
    mockedNetworkInterfaces.mockReturnValue({
      en0: [
        {
          address: "192.168.1.100",
          netmask: "255.255.255.0",
          family: "IPv4",
          mac: "00:00:00:00:00:00",
          internal: false,
          cidr: "192.168.1.100/24",
        },
      ],
    });

    expect(getLocalIp()).toBe("192.168.1.100");
  });

  it("skips internal interfaces", () => {
    mockedNetworkInterfaces.mockReturnValue({
      lo0: [
        {
          address: "127.0.0.1",
          netmask: "255.0.0.0",
          family: "IPv4",
          mac: "00:00:00:00:00:00",
          internal: true,
          cidr: "127.0.0.1/8",
        },
      ],
    });

    expect(getLocalIp()).toBeNull();
  });

  it("returns null when no interfaces exist", () => {
    mockedNetworkInterfaces.mockReturnValue({});
    expect(getLocalIp()).toBeNull();
  });

  it("prefers en0/en1 over other interfaces", () => {
    mockedNetworkInterfaces.mockReturnValue({
      eth0: [
        {
          address: "10.0.0.50",
          netmask: "255.255.255.0",
          family: "IPv4",
          mac: "00:00:00:00:00:00",
          internal: false,
          cidr: "10.0.0.50/24",
        },
      ],
      en0: [
        {
          address: "192.168.1.100",
          netmask: "255.255.255.0",
          family: "IPv4",
          mac: "00:00:00:00:00:00",
          internal: false,
          cidr: "192.168.1.100/24",
        },
      ],
    });

    expect(getLocalIp()).toBe("192.168.1.100");
  });
});

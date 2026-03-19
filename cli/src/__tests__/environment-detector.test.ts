import { describe, it, expect } from "vitest";
import { findIssues } from "../services/environment-detector.js";
import type { EnvironmentInfo } from "../types/environment-info.js";

function completeEnv(): EnvironmentInfo {
  return {
    username: "testuser",
    hostname: "test-host",
    sshEnabled: true,
    sshPort: 22,
    tailscaleIp: "100.64.0.1",
    tailscaleInstalled: true,
    localIp: "192.168.1.100",
    tmuxPath: "/usr/bin/tmux",
    claudePath: "/usr/local/bin/claude",
    hostKey: {
      keyType: "ssh-ed25519",
      wireBase64: "AAAAC3NzaC1lZDI1NTE5AAAAIG==",
      fingerprint: "SHA256:abc123",
    },
  };
}

describe("findIssues", () => {
  it("returns no issues when everything is present", () => {
    const issues = findIssues(completeEnv());
    expect(issues).toHaveLength(0);
  });

  it("returns error when SSH is disabled", () => {
    const env = { ...completeEnv(), sshEnabled: false };
    const issues = findIssues(env);
    expect(issues).toContainEqual(
      expect.objectContaining({ id: "ssh_disabled", severity: "error" }),
    );
  });

  it("returns error when tmux is missing", () => {
    const env = { ...completeEnv(), tmuxPath: null };
    const issues = findIssues(env);
    expect(issues).toContainEqual(
      expect.objectContaining({ id: "tmux_missing", severity: "error" }),
    );
  });

  it("returns warning when tailscale is not installed", () => {
    const env = { ...completeEnv(), tailscaleInstalled: false };
    const issues = findIssues(env);
    expect(issues).toContainEqual(
      expect.objectContaining({ id: "tailscale_missing", severity: "warning" }),
    );
  });

  it("returns warning when claude is missing", () => {
    const env = { ...completeEnv(), claudePath: null };
    const issues = findIssues(env);
    expect(issues).toContainEqual(
      expect.objectContaining({ id: "claude_missing", severity: "warning" }),
    );
  });

  it("returns error when host key is missing", () => {
    const env = { ...completeEnv(), hostKey: null };
    const issues = findIssues(env);
    expect(issues).toContainEqual(
      expect.objectContaining({ id: "no_host_key", severity: "error" }),
    );
  });

  it("returns multiple issues at once", () => {
    const env: EnvironmentInfo = {
      ...completeEnv(),
      sshEnabled: false,
      tmuxPath: null,
      tailscaleInstalled: false,
      claudePath: null,
      hostKey: null,
    };
    const issues = findIssues(env);
    expect(issues).toHaveLength(5);

    const ids = issues.map((i) => i.id);
    expect(ids).toContain("ssh_disabled");
    expect(ids).toContain("tmux_missing");
    expect(ids).toContain("tailscale_missing");
    expect(ids).toContain("claude_missing");
    expect(ids).toContain("no_host_key");
  });
});

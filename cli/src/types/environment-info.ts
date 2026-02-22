export interface HostKeyInfo {
  keyType: string;
  wireBase64: string;
  fingerprint: string;
}

export interface EnvironmentInfo {
  username: string;
  hostname: string;
  sshEnabled: boolean;
  sshPort: number;
  tailscaleIp: string | null;
  tailscaleInstalled: boolean;
  localIp: string | null;
  tmuxPath: string | null;
  claudePath: string | null;
  hostKey: HostKeyInfo | null;
}

export interface EnvironmentIssue {
  id:
    | "ssh_disabled"
    | "tailscale_missing"
    | "tmux_missing"
    | "claude_missing"
    | "no_host_key";
  label: string;
  severity: "error" | "warning";
}

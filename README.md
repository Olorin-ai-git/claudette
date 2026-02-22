# Claudette

The SSH terminal built for Claude Code. Control AI coding sessions from your iPhone, iPad, or Android device.

**Website:** [claudettemobile.com](https://claudettemobile.com)

---

## What is Claudette?

Claudette is a purpose-built SSH terminal client that connects to your Mac and lets you drive [Claude Code](https://docs.anthropic.com/en/docs/claude-code) sessions from anywhere. Full terminal emulation, an extended keyboard row, one-tap commands, prompt snippets, and session persistence -- all designed for the developer who ships with AI.

## Platform Support

| Platform     | Status    | Store                                      |
| ------------ | --------- | ------------------------------------------ |
| iOS / iPadOS | Available | [App Store](https://claudettemobile.com)   |
| Android      | Available | [Google Play](https://claudettemobile.com) |

## Features

- **Full Terminal** -- SSH terminal with an extended keyboard row: Esc, Tab, Ctrl+C, pipe, brackets, and programming symbols
- **Multi-Tab Sessions** -- Multiple terminal tabs, each wrapped in its own tmux session
- **Commands, Skills & Agents** -- Browse and trigger your entire Claude Code toolkit with one tap
- **Prompt Snippets** -- Quick-access drawer organized by workflow: refactoring, debugging, Git, and more
- **CLAUDE.md Viewer** -- Review project instructions, token estimates, and character counts at a glance
- **Voice Input** -- Dictate prompts to Claude Code hands-free via the microphone overlay
- **File Browser & Editor** -- Browse and edit remote files over SFTP without leaving the app
- **Session Persistence** -- tmux-wrapped sessions survive app backgrounding and reconnect automatically
- **Host Key Verification** -- TOFU (Trust On First Use) fingerprint pinning for secure connections
- **Wake-on-LAN** -- Wake your Mac remotely before connecting
- **Bonjour Discovery** -- Automatically discover Macs on your local network

---

## Getting Started

### Prerequisites

Before connecting Claudette to your Mac, ensure you have:

| Requirement                 | Why                                           | How to check                       |
| --------------------------- | --------------------------------------------- | ---------------------------------- |
| **macOS** with Remote Login | Claudette connects via SSH                    | `sudo systemsetup -getremotelogin` |
| **tmux**                    | Keeps sessions alive when the app backgrounds | `which tmux`                       |
| **Network access**          | Your phone must reach your Mac                | Same WiFi, VPN, or Tailscale       |
| **Claude Code** (optional)  | The AI coding tool Claudette is built around  | `which claude`                     |

### Setup Options

There are two ways to set up your Mac. Choose the one that fits:

|                 | Manual Checklist            | CLI (`npx claudette-setup`) |
| --------------- | --------------------------- | --------------------------- |
| **Best for**    | Understanding each step     | Getting started fast        |
| **Time**        | ~5 minutes                  | ~1 minute                   |
| **Interactive** | No                          | Yes (prompts to fix issues) |
| **QR pairing**  | No (enter details manually) | Yes (scan to pair)          |

---

### Option A: Manual Checklist

This is the recommended path if you want to understand what Claudette needs and why.

#### Step 1: Enable Remote Login (SSH)

Open **System Settings > General > Sharing > Remote Login** and turn it on.

Or from the terminal:

```bash
sudo systemsetup -setremotelogin on
```

Verify it's enabled:

```bash
sudo systemsetup -getremotelogin
# Remote Login: On
```

#### Step 2: Install tmux

tmux is required for session persistence. Without it, sessions end when the app backgrounds.

```bash
brew install tmux
```

#### Step 3: Install Claude Code (optional)

If you plan to use Claudette for Claude Code sessions:

```bash
npm install -g @anthropic-ai/claude-code
```

#### Step 4: Find your Mac's IP address

**With Tailscale (recommended):**

Tailscale gives your Mac a stable IP that works from any network -- not just your home WiFi.

```bash
tailscale ip -4
# e.g. 100.64.0.1
```

If you don't have Tailscale, install it from [tailscale.com](https://tailscale.com/download/mac) or:

```bash
brew install --cask tailscale
```

**Without Tailscale (WiFi only):**

```bash
ipconfig getifaddr en0
# e.g. 192.168.1.42
```

Note: this IP only works when both devices are on the same WiFi network, and it may change.

#### Step 5: Note your host key fingerprint

You'll need this to verify the connection on first use:

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
# 256 SHA256:OO5gXA... user@host (ED25519)
```

#### Step 6: Configure the Claudette app

1. Open Claudette on your iPhone, iPad, or Android device
2. Tap **+** to add a new server profile
3. Enter your Mac's IP address, your username, and SSH port (default: 22)
4. Choose an authentication method:
   - **Generate Key** -- creates an Ed25519 key pair on-device (recommended)
   - **Import Key** -- import an existing PEM private key
   - **Password** -- use your macOS password
5. If you generated a key, copy the public key and append it to `~/.ssh/authorized_keys` on your Mac:
   ```bash
   echo "ssh-ed25519 AAAA..." >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```
6. Tap the server to connect
7. On first connection, verify the host key fingerprint matches Step 5
8. Tap **Trust** -- you're in

---

### Option B: Quick Setup with CLI

The `claudette-setup` CLI automates the entire checklist above into a single command. It detects your environment, fixes issues interactively, and produces a QR code your phone scans to pair instantly.

```bash
npx claudette-setup
```

What it does:

1. Detects your Mac's username, hostname, SSH status, IP, tmux, Claude Code, and host key
2. Offers to fix any issues (enable SSH, install tmux, install Tailscale)
3. Starts a one-time pairing server
4. Displays a QR code containing your connection details and host key fingerprint
5. Waits for your phone to scan and send its public key
6. Installs the key in `~/.ssh/authorized_keys` automatically

The CLI is purely a convenience tool. Everything it does can be done manually using the checklist above.

#### CLI Options

```
Usage: claudette-setup [options]

Options:
  -p, --port <number>   SSH port override
  --ip <address>        IP address override (skip auto-detection)
  --skip-checks         Skip environment checks
  --debug               Enable verbose debug output
  -h, --help            Display help
  -V, --version         Display version
```

#### Environment Variables

| Variable                         | Description                  | Default                             |
| -------------------------------- | ---------------------------- | ----------------------------------- |
| `CLAUDETTE_SSH_PORT`             | SSH port                     | `22`                                |
| `CLAUDETTE_TOKEN_TTL_MS`         | Pairing token lifetime in ms | `300000` (5 min)                    |
| `CLAUDETTE_HOST_KEY_PATH`        | Path to host public key      | `/etc/ssh/ssh_host_ed25519_key.pub` |
| `CLAUDETTE_AUTHORIZED_KEYS_PATH` | Path to authorized_keys      | `~/.ssh/authorized_keys`            |
| `CLAUDETTE_DEBUG`                | Enable debug logging         | `false`                             |

---

## Network Configuration

| Method              | Works from               | Stability                           | Setup                           |
| ------------------- | ------------------------ | ----------------------------------- | ------------------------------- |
| **Tailscale**       | Anywhere                 | Stable IP, survives network changes | Install on Mac + phone, sign in |
| **Same WiFi**       | Home only                | IP may change on DHCP renewal       | None                            |
| **VPN**             | Anywhere the VPN reaches | Depends on VPN provider             | Configure VPN on both devices   |
| **Port forwarding** | Anywhere                 | Stable if configured correctly      | Router config, security risk    |

**Tailscale is strongly recommended.** It's free for personal use, gives each device a stable IP address, and works from any network without port forwarding or firewall changes.

---

## Architecture

```
+-------------------+       SSH       +-------------------+
|  Claudette        | --------------- |  Your Mac         |
|  (iOS / Android)  |                 |                   |
|                   |                 |  +-------------+  |
|  Terminal UI      |                 |  | tmux session |  |
|  Extended keyboard|                 |  |  +- claude   |  |
|  Snippet drawer   |                 |  +-------------+  |
|  File browser     |                 |                   |
|  Agent visualizer |                 |  ~/.ssh/          |
+-------------------+                 |  authorized_keys  |
                                      +-------------------+
```

- **No cloud.** SSH connections go directly between your device and your Mac.
- **No relay servers.** Even with Tailscale, traffic is peer-to-peer (WireGuard).
- **No accounts.** Claudette has no backend, no user accounts, no sign-in.

---

## Security

- **Ed25519 keys** generated on-device, stored in iOS Keychain or Android Keystore
- **TOFU host key verification** pins fingerprints on first connect and warns on changes
- **No telemetry or analytics** -- the app makes no network requests except to your configured SSH servers
- **Open source** -- audit every line of code in this repository
- **CLI pairing** uses a 32-byte random token with constant-time comparison and 5-minute expiry

## Privacy

Claudette collects no data. All credentials stay in your device's secure storage. The app only connects to servers you explicitly configure. See [PRIVACY.md](PRIVACY.md) for the full policy.

---

## Project Structure

```
claudette/
  Claudette/              iOS app (Swift/SwiftUI)
  Claudette.xcodeproj/    Xcode project
  cli/                    Companion setup CLI (TypeScript)
  scripts/                Build and deployment scripts
  PRIVACY.md              Privacy policy
  LICENSE                 MIT license
```

The Android app lives in a separate repository: [claudette-android](https://github.com/Olorin-ai-git/claudette-android).

---

## Contributing

Contributions are welcome. Please file issues and pull requests on the [GitHub repository](https://github.com/Olorin-ai-git/claudette).

For bug reports, include:

- Your macOS version
- Your iOS/Android version
- Steps to reproduce
- Any error messages from `--debug` mode

---

## License

MIT -- see [LICENSE](LICENSE).

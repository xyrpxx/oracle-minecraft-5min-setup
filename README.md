# 🎮 Oracle Cloud Minecraft — 5-Minute Auto Setup

**Deploy a modded Minecraft server** (Forge 1.20.1 / Fabric / Vanilla / modpack) on **Oracle Cloud's Always Free** tier: 2 ARM OCPUs, **12 GB RAM**, 200 GB disk, **$0/month**, online 24/7 — no DevOps skills required.

**🇬🇧 English** | **[🇫🇷 Français (README complet)](README.fr.md)**

![License](https://img.shields.io/badge/license-MIT-green)
![Cost](https://img.shields.io/badge/cost-0%E2%82%AC/month-success)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue)
![Bash](https://img.shields.io/badge/shell-bash-4EAA25)
![Languages](https://img.shields.io/badge/UI-English%20%7C%20Fran%C3%A7ais-informational)

---

## 📑 Table of contents

- [What is this?](#-what-is-this)
- [What you need](#-what-you-need)
- [⚡ Quick start — the 3-step path](#-quick-start--the-3-step-path)
- [📚 Full installation tutorial (for anyone)](#-full-installation-tutorial-for-anyone)
  - [Step 0 — requirements check](#step-0--requirements-check-2-minutes)
  - [Step 1 — create your Oracle account](#step-1--create-your-oracle-account-10-minutes-once)
  - [Step 2 — create your virtual machine](#step-2--create-your-virtual-machine-10-minutes-once)
  - [Step 3 — run the installer](#step-3--run-the-installer-10-minutes)
  - [Step 4 — open the network ports (mandatory)](#step-4--open-the-network-ports-mandatory-3-minutes)
  - [Step 5 — connect with Minecraft](#step-5--connect-with-minecraft-1-minute)
  - [Step 6 — mods for every player](#step-6--mods-for-every-player)
  - [Step 7 — become the server admin](#step-7--become-the-server-admin)
- [What the installer does for you](#-what-the-installer-does-for-you)
- [Managing your server](#-managing-your-server)
- [Troubleshooting](#-troubleshooting)
- [FAQ](#-faq)
- [How it works (technical guarantees)](#-how-it-works-technical-guarantees)
- [Compatibility](#-compatibility)
- [Documentation](#-documentation)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🤔 What is this?

Hosting a modded Minecraft server normally costs **$15–30/month** (or free hosts with 1–2 GB RAM, queues and auto-shutdown). This project deploys yours on **Oracle Cloud's Always Free tier** — genuinely free, forever, no trial deadline — and automates *everything*:

| | Free hosts (Aternos…) | Paid host | **This project (OCI)** |
|---|---|---|---|
| RAM | 1–2 GB | 8 GB | **12 GB** |
| Price | Free | $15–30/mo | **$0/month** |
| Queue / auto-sleep | Yes | No | **No — 24/7** |
| Control | Limited | Medium | **Total** |
| Setup time | ~10 min | ~15 min | **~10 min (guided)** |

Real cost: Minecraft **Java Edition** (~$30, one-time purchase) + $0/month. See the [FAQ](#-faq) for why Oracle does this and whether it can go away.

## 📋 What you need

- **Minecraft Java Edition** (not Bedrock/console/mobile).
- A **bank card** for Oracle's identity check (a ~$1 pre-authorization, refunded; **nothing is charged** on the free tier — ask an adult if needed).
- A computer with **Windows** (with [Git for Windows](https://git-scm.com/download/win)), **macOS**, or **Linux**.
- About **25 minutes** total (most of it waiting).
- No tech knowledge: the installer includes a **guided wizard** with kid-friendly explanations, in **English or French** (auto-detected).

## ⚡ Quick start — the 3-step path

If you just want to go (the wizard will explain everything else):

1. **Download this project**: green **⟵ Code** button (top right) → **Download ZIP** → unzip it.
2. **Windows**: double-click **`start-windows.bat`**. **macOS/Linux**: open a terminal in the folder and run `bash setup.sh`.
3. Choose **Guided mode** and follow along — press **Enter** to keep recommended answers. The wizard helps you create the Oracle account and the VM if you don't have them yet, then installs everything and shows you your server address.

Prefer reading everything first? Follow the [full tutorial](#-full-installation-tutorial-for-anyone) below.

---

## 📚 Full installation tutorial (for anyone)

This tutorial assumes **zero technical knowledge**. The guided wizard in `setup.sh` follows exactly the same steps and waits for you between each one — you can use either.

### Step 0 — requirements check (2 minutes)

Make sure you have everything from [What you need](#-what-you-need). On Windows, install [Git for Windows](https://git-scm.com/download/win) first (next, next, finish — it provides the terminal the installer runs in).

Get the project on your machine:

```bash
# Option A (simplest): green "Code" button → Download ZIP → unzip
# Option B (git):       git clone https://github.com/xyrpxx/oracle-minecraft-5min-setup.git
cd oracle-minecraft-5min-setup
```

### Step 1 — create your Oracle account (10 minutes, once)

1. Go to <https://cloud.oracle.com> → **Start for free**.
2. Email + password (write them down!), name, country, phone (SMS check).
3. Bank card for identity verification — **nothing gets charged** as long as you stay on the free tier. Virtual/disposable cards are usually rejected.
4. **Home Region**: permanent choice — pick the closest to you (e.g. UK South or Germany Central in Europe) for the least lag.
5. Wait for the confirmation email (up to 30 minutes), then sign in.

> ⚠️ If Oracle ever offers **« Upgrade to Pay As You Go »** — decline. Staying on free means $0, guaranteed.

### Step 2 — create your virtual machine (10 minutes, once)

In the Oracle console: **☰ menu → Compute → Instances → Create instance**, then:

| Field | What to enter |
|---|---|
| Name | Anything (e.g. `minecraft`) |
| Image *(Edit)* | **Ubuntu** 22.04 or 24.04 — **not** “Minimal” |
| Shape *(Edit)* | **Ampere** tab → **VM.Standard.A1.Flex** → OCPUs **2**, Memory **12 GB** |
| SSH keys ⚠️ | **Generate a key pair** → **Save Private Key** (keep this file forever — it's the key to your machine!) → **Save Public Key** |
| Networking | Default, with **Assign a public IPv4 address** |

Click **Create**, wait 2–5 minutes for the green **Running** status, and note the **Public IP Address** (looks like `129.213.56.123`).

> If you get **“Out of capacity”**: the region is saturated — retry later or pick another region.

### Step 3 — run the installer (10 minutes)

**Windows**: double-click **`start-windows.bat`**.
**macOS / Linux / Git Bash manually**:

```bash
bash setup.sh
```

Pick **Guided mode**. The wizard asks:

| Question | Meaning | Recommended |
|---|---|---|
| Server type | Vanilla (no mods), Forge (classic mods), Fabric (light mods) or a preset modpack | **Forge** for mods |
| Minecraft version | Game version — everyone must use the same | **1.20.1** |
| RAM | Memory given to the server (max 8 of the 12 GB) | **8 GB** |
| Max players | Slots on the server | **10** |
| Crafty panel | Optional web page to manage the server with buttons | **Yes** |
| Server pack URL *(modpacks only)* | Direct link to the pack's server file — see below | — |

For a modpack: on its CurseForge page → **Files** tab → your version → **Additional Files** → right-click the **Server Pack** → **Copy link address**, then paste it.

The installer then connects to your machine, installs Java 21 + the server + firewall + auto-restart, starts it, and prints **your server address**.

<details>
<summary>🖥️ Scripted / expert mode (no questions asked)</summary>

```bash
bash setup.sh --lang en --mode expert --ip 1.2.3.4 --key ~/ssh-key-2026-08-22.key \
     --type forge --mc-version 1.20.1 --ram 8 --players 10 --crafty true --yes
# Preview without touching the VM: add --dry-run
# All options: bash setup.sh --help
```
</details>

### Step 4 — open the network ports (mandatory, 3 minutes)

Oracle shields every machine behind a cloud firewall. The installer configures the machine itself; **you** must click 3 rules in the console (once):

**Networking → Virtual Cloud Networks → your VCN → Security Lists → Default Security List → Add Ingress Rules:**

| | Rule 1 | Rule 2 | Rule 3 |
|---|---|---|---|
| Source CIDR | `0.0.0.0/0` | `0.0.0.0/0` | `0.0.0.0/0` |
| IP Protocol | TCP | UDP | TCP |
| Destination Port | `25565` | `25565` | `8443` |
| Description | Minecraft TCP | Minecraft UDP | Crafty Panel |

Full walkthrough with screenshots-level detail: **[docs/en/vcn-setup.md](docs/en/vcn-setup.md)** (or the [OCI CLI script](deploy/oci_ingress_setup.sh) if you prefer automation).

### Step 5 — connect with Minecraft (1 minute)

1. Minecraft **Java Edition** → **Multiplayer** → **Add Server**.
2. Address: `YOUR_SERVER_IP:25565`.
3. Join! 🎉 (If it fails → [Troubleshooting](#-troubleshooting).)

If you installed Crafty, the web panel is at `https://YOUR_SERVER_IP:8443` (accept the self-signed-certificate warning, then change the default password).

### Step 6 — mods for every player

A modded server requires **every player to have exactly the same mods**:

1. Install the [CurseForge app](https://www.curseforge.com/download).
2. **Minecraft** tab → **Browse Modpacks** → find your server's pack and version → **Install**.
3. Always launch the game **from CurseForge** (Play button), then connect as above.

### Step 7 — become the server admin

```bash
./utils/console.sh "op YourName"
```

That gives you operator powers in-game (creative mode, teleportation, commands). The same tool sends any server command: `say Hello!`, `time set day`, `list`…

---

## ✅ What the installer does for you

| Step | Done automatically |
|---|---|
| System | Java 21 (ARM64), packages, dedicated unprivileged `minecraft` user |
| Server | Vanilla / Forge / Fabric / modpack engine, optimized config |
| Performance | JVM flags tuned for Ampere A1 (generational ZGC, 8 GB cap) |
| Firewall | iptables rules inserted before Oracle's REJECT (**ufw is forbidden on OCI**) |
| Web panel | Crafty Controller via Docker Compose (optional) |
| Boot | systemd service: auto-start + crash restart |
| Admin | hot backups, restore, monitoring, whitelist, console |

## 🛠️ Managing your server

| Task | Command |
|---|---|
| Send a game command / op yourself | `./utils/console.sh "op YourName"` |
| Backup (hot, with rotation) | `./utils/backup.sh` (keep more: `KEEP=14 ./utils/backup.sh`) |
| Restore a backup | `./utils/restore.sh` |
| Live stats (CPU, RAM, players, TPS) | `./utils/monitor.sh` |
| Update engine / Forge / modpack | `./utils/update.sh` |
| Harden the VM (SSH, fail2ban) | `./security/hardening.sh` |
| Manage the whitelist | `./security/whitelist_manager.sh add Name` |
| Remove everything | `./uninstall.sh` |

## 🔧 Troubleshooting

| Symptom | Most likely fix |
|---|---|
| “Connection timed out” | VCN ingress rules missing → [vcn-setup guide](docs/en/vcn-setup.md) |
| “Connection refused / No route to host” | Server stopped or firewall rule misplaced → [guide](docs/en/troubleshooting.md) |
| Forge “Could not find or load main class” | Someone launched the jar directly — use the generated `start.sh` |
| Crash / Out of memory | `-Xmx` above 8 GB — the OS kills Java; keep 8 max |
| Lag / “Can't keep up!” | Lower `view-distance` to 6, check TPS via `./utils/monitor.sh` |
| Mod rejection on join | Client and server modpacks differ — same pack, same version |
| SSH “Permission denied” | Wrong key/IP — the user is always `ubuntu` |

Full diagnostic tree: **[docs/en/troubleshooting.md](docs/en/troubleshooting.md)**.

## ❓ FAQ

- **Is it really free?** Yes — the Always Free resources used here (2 OCPU / 12 GB / 200 GB / 10 TB egress) cost $0/month with no time limit. Your only cost is Minecraft Java (~$30, once).
- **Why is Oracle so generous?** Customer acquisition — they hope you'll upgrade someday. Nothing is owed while you stay in the free quotas.
- **How many players?** Vanilla ~15–20; light modpacks 5–10; heavy packs 3–5 on 12 GB.
- **Does it run when I'm offline?** Yes, 24/7, with auto-restart after crashes.
- **Can Oracle end the offer?** Theoretically; it has existed since 2018. Your backups (`utils/backup.sh`) are always yours to keep.
- **Which languages?** The installer speaks **English and French** (auto-detected, `--lang fr|en` to force). Documentation exists in both — see below.

## 🏗️ How it works (technical guarantees)

- **Strict local/remote separation** — `setup.sh` runs on your machine and drives the VM over SSH; all provisioning happens on the VM via `deploy/remote_provision.sh`.
- **Modern Forge bootstrapping** — launched through `@unix_args.txt` (the `java -jar` way has been broken since Forge 1.17), with the recommended build resolved dynamically from Forge's promotions API.
- **OCI-aware firewall** — Oracle's Ubuntu images end their iptables chain with a global REJECT that neutralizes ufw; rules are inserted directly before it and persisted with `netfilter-persistent`.
- **Hardened JVM for ARM64** — `-Xms`=`-Xmx` ≤ 8 GB, generational ZGC, AlwaysPreTouch, on OpenJDK 21.
- **Idempotent everything** — re-run any script without breaking config, duplicating firewall rules or touching existing worlds.
- **Least privilege** — the server runs as a dedicated `minecraft` system user, never root; Crafty runs isolated in Docker.

## 💻 Compatibility

| Layer | Verified against |
|---|---|
| Your computer | Windows (Git Bash), macOS (bash 3.2-safe), Linux |
| The VM | Ubuntu 22.04 / 24.04 LTS, ARM64 (Ampere A1) |
| Java | OpenJDK 21 (generational ZGC) |
| Engines | Vanilla (piston-meta), Forge 1.17+ (unix_args), Fabric (meta API) |
| Panel | Crafty Controller 4 via Docker Compose (with `get.docker.com` fallback) |
| Tests | 350+ assertions run with `bash tests/run_tests.sh` |

## 📖 Documentation

| Document | English | Français |
|---|---|---|
| Beginner guide | [docs/en/getting-started.md](docs/en/getting-started.md) | [docs/guide-debutant-fr.md](docs/guide-debutant-fr.md) |
| Open the VCN ports | [docs/en/vcn-setup.md](docs/en/vcn-setup.md) | [docs/oci-vcn-config.md](docs/oci-vcn-config.md) |
| Troubleshooting | [docs/en/troubleshooting.md](docs/en/troubleshooting.md) | [docs/troubleshooting.md](docs/troubleshooting.md) |
| Full README | *(this file)* | [README.fr.md](README.fr.md) |

## 🤝 Contributing

Issues and PRs welcome: new modpacks (one JSON file in `modpacks/`), doc fixes and **new translations**, optimization ideas. Run `bash tests/run_tests.sh` before opening a PR. The maintenance scripts' UI is currently French — help translating them is especially appreciated.

## 📄 License

[MIT](LICENSE)

# Beginner's Guide — Free Minecraft Server on Oracle Cloud

> 🇬🇧 English | [🇫🇷 Version française](../guide-debutant-fr.md)

## Table of contents
1. Introduction
2. What is a Minecraft server?
3. What is Oracle Cloud and why is it really free?
4. Requirements
5. Creating your Oracle account
6. Creating the virtual machine
7. Running setup.sh
8. Opening the VCN ports (mandatory)
9. Connecting with Minecraft
10. Installing mods on each player's computer
11. Inviting your friends
12. Day-to-day administration
13. FAQ

---

## 1. Introduction

Goal: a modded Minecraft server, free, online 24/7, manageable from a simple
web page (Crafty), in under 25 minutes total — of which ~10 minutes of
technical steps thanks to `setup.sh`'s guided wizard.

> 🧒 **Total beginner?** You don't need to read this guide end-to-end:
> download the project (green **Code → Download ZIP** button), open the
> folder, **double-click `start-windows.bat`** (Windows) and pick **Guided
> mode**. The program explains each step as it comes. Come back here only to
> understand or troubleshoot.

## 2. What is a Minecraft server?

In single-player, the world runs on your PC and stops when you quit. A
dedicated server is a computer that keeps the world running permanently:
your friends connect whenever they want, the world persists, and you choose
the mods and rules. It's "your own apartment" instead of "your bedroom".

## 3. What is Oracle Cloud and why is it really free?

Oracle Cloud Infrastructure (OCI) rents out computers in data centers.
Their **Always Free** offer includes, for life, with no commitment:

| Resource | Free quota (2026) | For Minecraft |
|---|---|---|
| CPU (ARM Ampere A1) | 2 OCPUs | Enough for 3–10 players |
| RAM | 12 GB | Plenty (free hosts give 1–2 GB) |
| Disk | 200 GB | A modded world = 5–30 GB |
| Egress | 10 TB/month | Effectively unlimited |

It's customer acquisition: Oracle hopes you'll upgrade later. The free tier
doesn't expire after 12 months (unlike AWS/Azure trials). The bank card
asked at sign-up is only an identity check: nothing is charged while you
stay within these quotas (never accept an “Upgrade to Pay As You Go”).

## 4. Requirements

- **Minecraft Java Edition** (~$30, one-time — NOT Bedrock/console/mobile).
- A bank card for Oracle's verification (~$1 pre-authorization, refunded).
- A terminal: Linux, macOS, or **Git Bash on Windows** (included with
  [Git for Windows](https://git-scm.com/download/win) — install it, then
  right-click in a folder → “Open Git Bash here”).
- 25 minutes.

## 5. Creating your Oracle account

1. <https://cloud.oracle.com> → **Start for free**.
2. Email, password, name, country, phone (SMS verification).
3. Bank card verification (no charge; disposable virtual cards are often
   rejected).
4. **Home Region**: permanent choice. In Europe pick UK South (London) or
   Germany Central (Frankfurt) for 15–35 ms ping.
5. Wait for the confirmation email (sometimes 30 minutes), then sign in.

## 6. Creating the virtual machine

In the console: ☰ menu → **Compute** → **Instances** → **Create instance**.

- **Name**: anything (e.g. `minecraft`).
- **Image and Shape**:
  - Edit → Image: **Ubuntu** 22.04 or 24.04 (not “Minimal”).
  - Edit → Shape: **Ampere** → **VM.Standard.A1.Flex** with:
    - OCPUs: **2**
    - Memory: **12 GB**
- **Networking**: leave defaults, check **Assign a public IPv4 address**.
- **Add SSH keys**: ⚠️ critical step —
  1. “Generate a key pair”
  2. **Save Private Key** → keep this file (`ssh-key-2026-XX-XX.key`) safe:
     without it, no more access to the machine.
  3. **Save Public Key**.
- Click **Create** (2–5 minutes), then note the **Public IP Address**.

If you hit “Out of capacity”: retry later or pick another region (see
troubleshooting).

## 7. Running setup.sh

In a terminal (Git Bash on Windows), inside the project folder:

```bash
bash setup.sh
```

Pick **Guided mode**. The wizard walks you through the Oracle account and VM
creation if needed, then asks: the public IP, the path to your private key,
the server type (Vanilla / Forge / Fabric / Modpack), RAM (8 GB advised),
max players, and whether you want the Crafty web panel. It then installs
everything on the machine: Java 21, the server, the firewall, auto-restart
(systemd), and prints the final connection address.

Then do step 8 below — without it, nobody can connect.

## 8. Don't forget: opening the VCN ports

Follow [vcn-setup.md](vcn-setup.md) (3 minutes of clicking in the Oracle
console). Summary: VCN → Security Lists → Add Ingress Rules → TCP 25565,
UDP 25565, TCP 8443, source `0.0.0.0/0`.

## 9. Connecting with Minecraft

1. Minecraft Java Edition → **Multiplayer** → **Add Server**.
2. Address: `YOUR_VM_IP:25565` (the `:25565` is optional but explicit).
3. Join! If it fails: [troubleshooting.md](troubleshooting.md).

The Crafty panel (if installed): `https://YOUR_VM_IP:8443` — accept the
self-signed-certificate warning, sign in (credentials shown by Crafty on
first launch, visible via `ssh ubuntu@IP 'sudo docker logs crafty_controller'`)
and change the password.

### Plugging your server into Crafty — once, 30 seconds

Crafty is your Aternos-style control panel: start/stop buttons, live console,
file manager and scheduled backups, all in the browser. The installer puts
your server where Crafty can see it — you just point Crafty at it once:

1. Open `https://YOUR_VM_IP:8443` and sign in.
2. Click **New Server** (or **Server Wizard**) → choose **import an
   existing server**.
3. Directory: **`servers/server`** — name it whatever you like (e.g.
   `minecraft`) → **Import**.
4. Press **Start**. Done: your server now has a web dashboard.

> The exact button names can vary slightly between Crafty versions; what
> matters is *import* (not create) and the folder `servers/server`.

## 10. Installing mods on each player's computer

A modded server requires **every player** to have exactly the same mods.

1. Install the **CurseForge** app (<https://www.curseforge.com/download>).
2. Minecraft tab → Browse Modpacks → find the server's pack (e.g. “Better
   Minecraft [Forge]” version **1.20.1**) → Install.
3. Always launch the game **from CurseForge** (Play button).

For a custom Forge server: same Minecraft AND Forge versions as the server
(visible in `./utils/monitor.sh` or the Crafty console).

## 11. Inviting your friends

Send them something like (adapt):

> 🎮 Modded Minecraft server is up!
> Address: `IP:25565`
> You need: Minecraft Java (~$30, one-time) + the CurseForge app + the
> “NAME” modpack version 1.20.1 (Install, then Play from CurseForge).
> Then: Multiplayer → Add Server → the address above.

Consider the whitelist for a private server:
`./security/whitelist_manager.sh add Name`.

## 12. Day-to-day administration

| Task | Command |
|---|---|
| Become in-game admin (operator) | `./utils/console.sh "op YourName"` |
| Send a server command | `./utils/console.sh "time set day"` |
| Backup | `./utils/backup.sh` |
| Restore | `./utils/restore.sh` |
| Monitor (CPU, RAM, players, TPS) | `./utils/monitor.sh` |
| Update the server | `./utils/update.sh` |
| Harden the VM | `./security/hardening.sh` |
| Manage the whitelist | `./security/whitelist_manager.sh` |
| Remove everything | `./uninstall.sh` |

Being an **operator** gives you in-game superpowers: creative mode,
teleportation, admin commands. **Join your server once first** (to register
your player), then: `./utils/console.sh "op YourName"`.

The server restarts by itself after a crash or a VM reboot (systemd).

## 13. FAQ

- **Really free?** Yes — $0/month within the Always Free quotas; the only
  cost is Minecraft Java (~$30, once).
- **How many players?** Vanilla: 15–20; light modpacks: 5–10; heavy packs:
  3–5 with 12 GB.
- **Runs when I'm not playing?** Yes, 24/7.
- **Change modpacks later?** Yes: `./utils/update.sh`.
- **Can Oracle kill the offer?** Theoretically; in practice it has existed
  since 2018. Your backups (`utils/backup.sh`) are always yours to keep.

<div align="center">

# 🎮 Your own Minecraft server — free, forever

**A modded Minecraft server on Oracle Cloud's free tier.**
No subscription. No ads. No "server falls asleep after 10 minutes".

**12 GB RAM** · **0 $/month** · **online 24/7** · no tech skills needed

**🇬🇧 English** · [🇫🇷 Français](README.fr.md)

![License](https://img.shields.io/badge/license-MIT-green)
![Cost](https://img.shields.io/badge/cost-0%24%2Fmonth-success)
![Platform](https://img.shields.io/badge/works%20on-Windows%20%7C%20macOS%20%7C%20Linux-blue)
![UI](https://img.shields.io/badge/wizard-English%20%7C%20Fran%C3%A7ais-informational)

</div>

---

## ⏱️ Start here — 4 small steps

Your part takes about **15 minutes of clicking**. The wizard does the rest.

### 1 · Download this project

*1 minute*

Green **⟵ Code** button (top right of this page) → **Download ZIP** → unzip the folder.

### 2 · Run the installer

*1 minute*

**Windows** — open the folder and **double-click `start-windows.bat`**

**Mac / Linux** — open a terminal in that folder and run:

```bash
bash setup.sh
```

### 3 · Follow the wizard

*~10 minutes, mostly forms*

Pick **Guided mode**. It walks you through creating your free Oracle account
and your server machine — and **waits for you** between each step.

> 💡 **Press Enter** at any question to accept the recommended answer.
> You can't really get this wrong.

### 4 · Open the ports

*3 minutes, done once*

Three clicks in the Oracle console so your friends can connect.
The wizard opens the right page and shows you exactly what to click.

### 🎉 That's it

The installer hands you your **server address** — the only thing your
friends ever need. Paste it into Minecraft: *Multiplayer → Add Server*.

---

## 📦 What you get

- **A real machine in the cloud** — 2 CPU cores, 12 GB RAM, 200 GB disk
- **Always on** — plays 24/7, restarts itself after any crash
- **Mods** — Forge, Fabric, Vanilla, or a ready-made modpack
- **A web dashboard** (optional) — start/stop and read logs like a pro
- **Safety nets** — one-command backups, restore, monitoring, updates

## 🧾 What you need

- **Minecraft Java Edition** (~30 $, one time — not Bedrock/console/mobile)
- A **bank card** for Oracle's identity check
  (nothing is ever charged on the free plan — a ~1 $ hold is refunded)
- **Windows** (with [Git for Windows](https://git-scm.com/download/win)), **Mac**, or **Linux**
- That's all. Really.

> 💬 The wizard speaks **English and French** — it picks your language automatically.

---

## 🔍 Curious or stuck? Open only what you need

<details>
<summary><b>📖 The complete walkthrough</b> — every click, zero guessing</summary>

<br>

**Step 0 — the folder on your machine.**
Install [Git for Windows](https://git-scm.com/download/win) first if you're on Windows
(next → next → finish). Then get this project: green **Code** button → **Download ZIP** → unzip.

**Step 1 — Oracle account** *(10 min, once)*

1. Go to <https://cloud.oracle.com> → **Start for free**
2. Email + password (write them down), name, country, phone
3. Card for the identity check — nothing gets charged
4. **Region**: pick the closest to you (permanent choice, affects lag)
5. Wait for the confirmation email (up to 30 min)

⚠️ If Oracle offers **"Upgrade to Pay As You Go"** — **decline**. Free means 0 $.

**Step 2 — the machine** *(10 min, once)*

Console → ☰ menu → **Compute → Instances → Create instance**, then:

| Field | Enter |
|---|---|
| Image | **Ubuntu 22.04 or 24.04** (not *Minimal*) |
| Shape | **Ampere → VM.Standard.A1.Flex** · 2 OCPUs · 12 GB |
| SSH keys | **Generate a key pair** → **Save Private Key** → **Save Public Key** |

⚠️ The **private key file** is the only key to your machine.
Lose it = lose the server. Don't rename it, don't delete it.

Click **Create**, wait 2–5 min for the green **Running** badge,
then copy the **Public IP Address** (looks like `129.213.56.123`).

*"Out of capacity" error?* The region is full — retry later or try another region.

**Step 3 — the installer** *(~10 min)*

Double-click `start-windows.bat` (or `bash setup.sh`), pick **Guided mode**, and:

| Question | Recommended | Why |
|---|---|---|
| Server type | **Forge** | The classic way to play mods |
| Minecraft version | **1.20.1** | Most mods available; latest (26.2) also works |
| RAM | **8 GB** | Leaves 4 GB for the machine itself |
| Players | **10** | Comfortable for 12 GB |
| Crafty panel | **Yes** | Manage the server from your browser |

Then it installs everything (Java, server, firewall, auto-restart),
starts the server, and prints your address.

**Step 4 — open the ports** *(3 min, once)* — see the
[dedicated guide with the exact clicks](docs/en/vcn-setup.md).

**Step 5 — connect.** Minecraft → *Multiplayer → Add Server* → `YOUR_IP:25565`.

**Step 6 — mods for players.** Everyone installs the
[CurseForge app](https://www.curseforge.com/download) → same modpack,
same version → always launch the game from CurseForge.

**Step 7 — make yourself admin.** Join your server **once**, then run:

```bash
./utils/console.sh "op YourName"
```

</details>

<details>
<summary><b>🛠️ Running your server day-to-day</b> — commands cheat sheet</summary>

<br>

| I want to… | Run this |
|---|---|
| Send a game command (make someone admin, set daytime…) | `./utils/console.sh "op YourName"` |
| Back up the world | `./utils/backup.sh` |
| Restore a backup | `./utils/restore.sh` |
| See CPU / RAM / players | `./utils/monitor.sh` |
| Update Minecraft, Forge or the modpack | `./utils/update.sh` |
| Lock the server to invited players | `./security/whitelist_manager.sh add Name` |
| Tighten security (recommended after setup) | `./security/hardening.sh` |
| Remove everything cleanly | `./uninstall.sh` |

All of them are re-runnable — they fix rather than break.

</details>

<details>
<summary><b>🔧 Something doesn't work?</b> — the 7 most common fixes</summary>

<br>

| Symptom | The fix |
|---|---|
| **Connection timed out** | The ports aren't open → [3-minute guide](docs/en/vcn-setup.md) |
| **Connection refused** | Server stopped → `./utils/monitor.sh`, then restart via Crafty or `ssh ubuntu@IP 'sudo systemctl start minecraft'` |
| **Crash / out of memory** | RAM was raised above 8 GB → put `-Xmx8G` back in `user_jvm_args.txt` and restart |
| **Lag, "Can't keep up!"** | Lower `view-distance` to 6 in `server.properties`, restart |
| **Player rejected: mods mismatch** | Client and server run different modpacks → same pack, same version |
| **SSH "Permission denied"** | Wrong key or IP; the user is always `ubuntu` |
| **Crafty page won't load** | Check TCP 8443 is open (VCN), then `sudo docker logs crafty_controller` |

Full diagnostic tree: [docs/en/troubleshooting.md](docs/en/troubleshooting.md)

</details>

<details>
<summary><b>❓ Questions people actually ask</b></summary>

<br>

**Is it really free?**
Yes. The resources used (2 cores, 12 GB RAM, 200 GB disk, 10 TB traffic)
are part of Oracle's *Always Free* tier — no expiry date, no credit card
burn. Your only cost ever is Minecraft Java itself (~30 $, once).

**Why does Oracle give this away?**
Marketing — they hope you'll someday upgrade to paid resources.
You don't owe them anything while staying inside the free quotas.

**Does it work with the latest Minecraft (26.x)?**
Yes. The required Java version is auto-detected from Mojang's own metadata
(Java 25 for 26.x — verified by actually booting a 26.2 server with this
project's files). Forge and Fabric versions resolve automatically too.
1.20.1 stays the default simply because it has the most mods.

**How many players?**
Vanilla: ~15–20. Light modpack: 5–10. Heavy modpack: 3–5.

**Does it run when my computer is off?**
Yes — it's a cloud machine. 24/7, with automatic crash-restart.

**Can Oracle take it back?**
The offer has existed since 2018. And your backups (`./utils/backup.sh`)
download to your computer — your world is always yours.

</details>

<details>
<summary><b>🏗️ How it works & compatibility</b> — for the curious</summary>

<br>

**Architecture in one sentence:** `setup.sh` runs on your computer and
drives your cloud machine over SSH; everything heavy happens over there,
via `deploy/remote_provision.sh`.

Guarantees baked in:

- The server runs as a dedicated `minecraft` user — never as root
- Modern Forge bootstrapping (`@unix_args.txt`, the only correct way since 1.17)
- Firewall rules inserted exactly where Oracle's Ubuntu images need them
  (raw iptables — `ufw` silently fails on Oracle)
- JVM tuned for the ARM processor (generational ZGC, memory pinned at start)
- Every script is **idempotent** — re-running fixes, never duplicates

| Layer | Verified against |
|---|---|
| Your computer | Windows (Git Bash) · macOS (bash 3.2-safe) · Linux |
| Cloud machine | Ubuntu 22.04 / 24.04 LTS · ARM64 (Ampere A1) |
| Minecraft | 1.20.1 → **26.2** (Java 21 or 25 auto-installed to match) |
| Quality | 370+ automated assertions: `bash tests/run_tests.sh` |

</details>

<details>
<summary><b>📚 All documentation</b></summary>

<br>

| Guide | English | Français |
|---|---|---|
| Complete beginner guide | [getting-started.md](docs/en/getting-started.md) | [guide-debutant-fr.md](docs/guide-debutant-fr.md) |
| Opening the ports | [vcn-setup.md](docs/en/vcn-setup.md) | [oci-vcn-config.md](docs/oci-vcn-config.md) |
| Troubleshooting | [troubleshooting.md](docs/en/troubleshooting.md) | [troubleshooting.md](docs/troubleshooting.md) |

**Contributing** — issues and PRs welcome (new modpacks are just one JSON
file, and translating the maintenance scripts is a great first PR).
Run the test suite before submitting.

**License** — [MIT](LICENSE)

</details>

---

<div align="center">

Made for players who'd rather play than configure. 🎮

</div>

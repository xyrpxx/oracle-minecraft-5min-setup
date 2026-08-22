# Oracle Cloud Minecraft — 5 min Auto Setup (V3.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete `oracle-minecraft-5min-setup` GitHub repository: an interactive local orchestrator (`setup.sh`) that deploys a modded Minecraft server (Vanilla / Forge 1.20.1+ / Fabric / modpack) onto an Oracle Cloud Always Free ARM VM in ~5 minutes, plus ops utilities, security scripts, and francophone beginner documentation.

**Architecture:** Strict separation of execution contexts — everything the user runs lives locally (`setup.sh`, `utils/`, `security/`, `uninstall.sh`) and drives the VM over SSH; a single provisioning script (`deploy/remote_provision.sh`) is transferred to and executed on the VM, creating a dedicated `minecraft` system user, installing the server engine, generating a `start.sh` (Forge launched via `@unix_args.txt`, never `java -jar`), opening ports with raw `iptables` (UFW is forbidden on OCI Ubuntu images), optionally deploying Crafty Controller via Docker Compose, and managing the server through systemd. Shared pure functions live in `scripts/lib.sh` and are unit-tested by a Git-Bash-compatible test suite in `tests/`.

**Tech Stack:** Bash (strict mode), Python 3 (minimal RCON client), systemd, iptables/netfilter-persistent, Docker Compose (Crafty Controller), OCI CLI (optional ingress automation), OpenJDK 21 (ZGC generational on ARM64).

## Global Constraints

- Spec source: **Master Prompt V3.0** (the corrected spec at the end of the pasted document). Where V2.0 and V3.0 conflict, V3.0 wins.
- Every Bash script uses `set -euo pipefail` and a `#!/usr/bin/env bash` shebang.
- **UFW is forbidden.** Host firewall = `iptables` rules inserted *before* Oracle's `REJECT` rule + `netfilter-persistent save`.
- **Forge 1.17+ launch must use `@unix_args.txt`** (`java @user_jvm_args.txt @libraries/.../unix_args.txt nogui`). The string `minecraft_server.jar` must not appear in any script.
- JVM (OpenJDK 21, ARM64): `-Xms` = `-Xmx`, **max 8 GB** (12 GB total VM RAM, ~4 GB reserved for OS + Docker/Crafty); flags: `UnlockExperimentalVMOptions`, `UseZGC`, `ZGenerational`, `AlwaysPreTouch`, `UseStringDeduplication`, `DisableExplicitGC`.
- Server runs as dedicated user `minecraft` (`/usr/sbin/nologin`), never root/ubuntu.
- **Idempotency:** every script can be re-run without breaking config, duplicating firewall rules, or overwriting an existing `world/`.
- Crafty Controller **only** via Docker Compose (image `registry.gitlab.com/crafty-controller/crafty-4`), never via its interactive installer.
- Ports: TCP+UDP 25565 (Minecraft), TCP 8443 (Crafty), TCP 22 (SSH). VCN Ingress Rules (`0.0.0.0/0`) are documented + automated in `deploy/oci_ingress_setup.sh`.
- All user-facing messages and code comments are **in French**.
- Target: Ubuntu 22.04/24.04 LTS ARM64 (Ampere A1, 2 OCPU / 12 GB RAM — current Always Free quota; the old 4 OCPU / 24 GB numbers from V2 must not appear).
- Dev machine is Windows Git Bash: local scripts may only rely on `bash`, `ssh`, `scp`, `curl`, `grep`, `sed` (no `jq`, no `rsync` locally; `jq`/`python3` are installed on the VM and used remotely).
- All text files use LF endings, enforced by `.gitattributes` (critical: CRLF breaks Bash on Linux).
- Every task ends with `bash tests/run_tests.sh` green and a git commit.
- Known V2 spec bugs fixed in this plan: `spawn-monsters=70`/`spawn-animals=15` are invalid (booleans), `allow-the-end` is not a real key, `level-type=default` → `minecraft\:normal`, hardcoded Mojang URL → piston-meta resolution.

---

## File Structure

```
oracle-minecraft-5min-setup/
├── README.md                     # Landing page (FR): quick start, features, cost table
├── LICENSE                       # MIT
├── .gitignore                    # keys, .server.conf, backups, zips
├── .gitattributes                # LF enforcement for all text/scripts
├── setup.sh                      # LOCAL interactive orchestrator (transfer + SSH exec)
├── uninstall.sh                  # LOCAL clean removal of everything on the VM
├── scripts/
│   └── lib.sh                    # Shared pure functions: colors, logging, validations, ask_*, run_ssh
├── deploy/
│   ├── remote_provision.sh       # Runs ON THE VM (apt, user, engine install, systemd)
│   ├── configure_iptables.sh     # Runs ON THE VM (iptables before REJECT + persist)
│   ├── docker-compose.crafty.yml # Crafty Controller v4 container
│   └── oci_ingress_setup.sh      # Optional: VCN ingress rules via OCI CLI
├── configs/
│   ├── server.properties.template
│   ├── user_jvm_args.txt.template
│   └── eula.txt
├── modpacks/
│   ├── manifest.json             # Registry of available modpacks
│   ├── better-minecraft.json
│   ├── atm9-light.json
│   └── vanilla-plus.json
├── utils/
│   ├── rcon_client.py            # Minimal Source-RCON client (runs on VM)
│   ├── backup.sh                 # Hot backup (save-off/save-on) + rotation
│   ├── restore.sh                # Restore an archive
│   ├── monitor.sh                # Live stats (service, CPU/RAM, players, TPS)
│   └── update.sh                 # Engine/modpack update (re-runs remote_provision --update-server)
├── security/
│   ├── hardening.sh              # SSH hardening, fail2ban, unattended-upgrades
│   └── whitelist_manager.sh      # whitelist add/remove/list via RCON
├── docs/
│   ├── guide-debutant-fr.md      # Full beginner guide (FR)
│   ├── oci-vcn-config.md         # MANDATORY VCN ingress rules walkthrough
│   └── troubleshooting.md        # Error → cause → fix ladder
└── tests/
    ├── run_tests.sh              # Suite runner
    ├── helpers.sh                # Assertion helpers
    ├── test_lib.sh               # Unit tests for scripts/lib.sh
    ├── test_configs.sh
    ├── test_modpacks.sh
    ├── test_deploy_scripts.sh
    ├── test_setup.sh
    ├── test_rcon.py
    ├── test_utils_scripts.sh
    ├── test_security_scripts.sh
    └── test_structure.sh         # File tree + bash -n + CRLF + shellcheck (optional)
```

Responsibilities: `scripts/lib.sh` = only file with shared logic (single source of truth for validation and SSH invocation). `deploy/` = everything that executes on the VM. `utils/`, `security/`, `uninstall.sh` = local wrappers that SSH into the VM using credentials saved by `setup.sh` in `.server.conf` (gitignored). `tests/` = the quality gate for every task.

---

### Task 1: Initialisation du dépôt (git, .gitignore, .gitattributes, LICENSE)

**Files:**
- Create: `.gitignore`
- Create: `.gitattributes`
- Create: `LICENSE`

**Interfaces:**
- Consumes: nothing.
- Produces: an initialized git repository that all later tasks commit into.

- [ ] **Step 1: Initialize git (with local identity fallback so commit never fails)**

```bash
cd "C:\Users\eleno\Documents\Code\oracle-minecraft-5min-setup"
git init -b main
git config user.name  >/dev/null 2>&1 || git config user.name  "Dev"
git config user.email >/dev/null 2>&1 || git config user.email "dev@local"
```

Expected: `Initialized empty Git repository` (or reinitialization warning if run twice — harmless).

- [ ] **Step 2: Create `.gitignore`**

```gitignore
# Clés SSH privées — ne JAMAIS versionner
*.key
*.pem
*.ppk

# Configuration locale générée par setup.sh (contient IP + chemin de clé)
.server.conf

# Sauvegardes et binaires
*.tar.gz
*.zip
backups/

# OS / éditeurs
.DS_Store
Thumbs.db
```

- [ ] **Step 3: Create `.gitattributes`**

```gitattributes
* text=auto
*.sh   text eol=lf
*.py   text eol=lf
*.yml  text eol=lf
*.yaml text eol=lf
*.json text eol=lf
*.md   text eol=lf
*.txt  text eol=lf
*.template text eol=lf
*.conf text eol=lf
*.properties text eol=lf
```

- [ ] **Step 4: Create `LICENSE`**

```text
MIT License

Copyright (c) 2026 oracle-minecraft-5min-setup contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 5: Verify and commit**

Run: `git status --short` — expect exactly `.gitattributes`, `.gitignore`, `LICENSE` listed.

```bash
git add .gitignore .gitattributes LICENSE
git commit -m "chore: init dépôt (gitignore, gitattributes LF, licence MIT)"
```

---

### Task 2: Harnais de tests + `scripts/lib.sh` (couleurs, journalisation, validation IPv4)

**Files:**
- Create: `tests/helpers.sh`
- Create: `tests/run_tests.sh`
- Create: `tests/test_lib.sh`
- Create: `scripts/lib.sh`

**Interfaces:**
- Consumes: nothing.
- Produces (used by nearly every later task): `info`, `success`, `warn`, `die` (logging); `is_valid_ipv4 <ip>` → exit 0/1; assertion helpers `t_pass`, `t_fail`, `assert_equals <expected> <actual> <msg>`, `assert_contains <haystack> <needle> <msg>`, `assert_file_exists <path> <msg>`, `assert_file_contains <file> <needle> <msg>`, `assert_file_not_contains <file> <needle> <msg>`, `assert_exit_zero <msg> <cmd...>`, `assert_exit_nonzero <msg> <cmd...>`, `finish_tests` (exits non-zero on any failure).

- [ ] **Step 1: Write the failing test**

`tests/helpers.sh`:

```bash
#!/usr/bin/env bash
# helpers.sh — Assertions minimales pour la suite de tests (compatible Git Bash)
PASS_COUNT=0
FAIL_COUNT=0

t_pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  OK    %s\n' "$1"; }
t_fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '  ÉCHEC %s\n' "$1" >&2; }

assert_equals() { # attendu obtenu message
    if [[ "$1" == "$2" ]]; then t_pass "$3"; else t_fail "$3 (attendu '$1', obtenu '$2')"; fi
}
assert_contains() { # botte_aiguille aiguille message
    if [[ "$1" == *"$2"* ]]; then t_pass "$3"; else t_fail "$3 ('$2' introuvable)"; fi
}
assert_file_exists() {
    if [[ -f "$1" ]]; then t_pass "$2"; else t_fail "$2 (fichier absent : $1)"; fi
}
assert_file_contains() { # fichier aiguille message
    if grep -qF -- "$2" "$1" 2>/dev/null; then t_pass "$3"; else t_fail "$3 ('$2' introuvable dans $1)"; fi
}
assert_file_not_contains() {
    if grep -qF -- "$2" "$1" 2>/dev/null; then t_fail "$3 ('$2' trouvé dans $1 alors qu'interdit)"; else t_pass "$3"; fi
}
assert_exit_zero() { # message commande...
    local msg="$1"; shift
    if "$@" >/dev/null 2>&1; then t_pass "$msg"; else t_fail "$msg"; fi
}
assert_exit_nonzero() {
    local msg="$1"; shift
    if "$@" >/dev/null 2>&1; then t_fail "$msg"; else t_pass "$msg"; fi
}
finish_tests() {
    printf '\nRésultats : %d OK, %d échec(s)\n' "$PASS_COUNT" "$FAIL_COUNT"
    [[ "$FAIL_COUNT" -eq 0 ]]
}
```

`tests/run_tests.sh`:

```bash
#!/usr/bin/env bash
# run_tests.sh — Exécute tous les tests. Code retour non nul si un échec.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

overall=0
for t in tests/test_*.sh; do
    echo "==> $t"
    if ! bash "$t"; then
        overall=1
        echo "    [ÉCHEC] $t"
    fi
done

if (( overall == 0 )); then
    echo "SUITE : SUCCÈS"
else
    echo "SUITE : ÉCHECS"
fi
exit "$overall"
```

`tests/test_lib.sh`:

```bash
#!/usr/bin/env bash
# Tests unitaires de scripts/lib.sh — partie validations de base
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"
# shellcheck source=scripts/lib.sh
. "${REPO_ROOT}/scripts/lib.sh"

echo "-- is_valid_ipv4 --"
assert_exit_zero    "IPv4 192.168.1.1 valide"          is_valid_ipv4 192.168.1.1
assert_exit_zero    "IPv4 0.0.0.0 valide"              is_valid_ipv4 0.0.0.0
assert_exit_zero    "IPv4 255.255.255.255 valide"      is_valid_ipv4 255.255.255.255
assert_exit_zero    "IPv4 129.213.56.123 valide"       is_valid_ipv4 129.213.56.123
assert_exit_nonzero "IPv4 256.1.1.1 invalide"          is_valid_ipv4 256.1.1.1
assert_exit_nonzero "IPv4 1.2.3 invalide"              is_valid_ipv4 1.2.3
assert_exit_nonzero "IPv4 1.2.3.4.5 invalide"          is_valid_ipv4 1.2.3.4.5
assert_exit_nonzero "IPv4 a.b.c.d invalide"            is_valid_ipv4 a.b.c.d
assert_exit_nonzero "IPv4 vide invalide"               is_valid_ipv4 ""
assert_exit_nonzero "IPv4 999.1.1.1 invalide"          is_valid_ipv4 999.1.1.1
assert_exit_nonzero "IPv4 avec texte invalide"         is_valid_ipv4 "1.2.3.4 x"
assert_exit_zero    "IPv4 1.2.3.04 (zéro initial) valide" is_valid_ipv4 1.2.3.04

finish_tests
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL — `scripts/lib.sh: No such file or directory` (test cannot source the lib).

- [ ] **Step 3: Write minimal implementation**

`scripts/lib.sh`:

```bash
#!/usr/bin/env bash
# =============================================================================
# lib.sh — Fonctions partagées du projet oracle-minecraft-5min-setup
# Sourcing :
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "${SCRIPT_DIR}/scripts/lib.sh"
# Contient : couleurs, journalisation, validations pures (unit-testées),
#            questions interactives et invocation SSH.
# =============================================================================

# --- Couleurs terminal (désactivées si la sortie n'est pas un terminal) ---
if [[ -t 1 ]]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; NC=''
fi

info()    { printf '%s\n' "${BLUE}[INFO]${NC} $*"; }
success() { printf '%s\n' "${GREEN}[OK]${NC} $*"; }
warn()    { printf '%s\n' "${YELLOW}[ATTENTION]${NC} $*"; }
die()     { printf '%s\n' "${RED}[ERREUR]${NC} $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Validations pures (testées dans tests/test_lib.sh)
# ---------------------------------------------------------------------------

# IPv4 valide : 4 octets numériques 0-255. Retourne 0 si valide, 1 sinon.
is_valid_ipv4() {
    local ip="$1" octet
    local -a octets=()
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        (( 10#$octet <= 255 )) || return 1
    done
    return 0
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/run_tests.sh`
Expected: `SUITE : SUCCÈS`, all IPv4 assertions OK.

- [ ] **Step 5: Commit**

```bash
git add tests/ scripts/lib.sh
git commit -m "test: harnais de tests + lib.sh (couleurs, logs, validation IPv4)"
```

---

### Task 3: `scripts/lib.sh` — validations complémentaires

**Files:**
- Modify: `scripts/lib.sh` (append functions)
- Modify: `tests/test_lib.sh` (append tests before `finish_tests`)

**Interfaces:**
- Consumes: Task 2 helpers and lib.
- Produces: `is_valid_mc_version <v>` (0/1), `is_valid_ram <go>` (0/1, 2–8), `is_valid_player_count <n>` (0/1, 1–100), `is_valid_mc_username <name>` (0/1, `^[A-Za-z0-9_]{3,16}$`), `is_valid_backup_name <f>` (0/1, `^[A-Za-z0-9._-]+$`), `modpack_id_exists <id> [manifest_path]` (0/1), `ask_yes_no <question> [default y|n]` (0=oui), `ask_number <question> <default> <min> <max>` (echoes value), `ask_choice <question> <opt...>` (sets `SELECTED_CHOICE`), `load_server_conf [path]` (sets `ORACLE_IP`, `SSH_KEY_PATH`, `SSH_USER`, `SERVER_TYPE`, `MC_VERSION`, `RAM_GB`, `MODPACK`), `run_ssh <args...>` (uses `SSH_KEY_PATH`/`SSH_USER`/`ORACLE_IP`).

- [ ] **Step 1: Append the failing tests**

Append to `tests/test_lib.sh`, **before** the final `finish_tests` line:

```bash
echo "-- is_valid_mc_version --"
assert_exit_zero    "Version 1.20.1 valide"        is_valid_mc_version 1.20.1
assert_exit_zero    "Version 1.21 valide"          is_valid_mc_version 1.21
assert_exit_nonzero "Version abc invalide"         is_valid_mc_version abc
assert_exit_nonzero "Version 1.20. invalide"       is_valid_mc_version "1.20."
assert_exit_nonzero "Version vide invalide"        is_valid_mc_version ""

echo "-- is_valid_ram --"
assert_exit_zero    "RAM 4 valide"                 is_valid_ram 4
assert_exit_zero    "RAM 8 valide (max free tier)" is_valid_ram 8
assert_exit_nonzero "RAM 9 invalide (> 8 Go)"      is_valid_ram 9
assert_exit_nonzero "RAM 1 invalide (< 2 Go)"      is_valid_ram 1
assert_exit_nonzero "RAM abc invalide"             is_valid_ram abc
assert_exit_nonzero "RAM vide invalide"            is_valid_ram ""

echo "-- is_valid_player_count --"
assert_exit_zero    "10 joueurs valide"            is_valid_player_count 10
assert_exit_nonzero "0 joueur invalide"            is_valid_player_count 0
assert_exit_nonzero "101 joueurs invalide"         is_valid_player_count 101

echo "-- is_valid_mc_username --"
assert_exit_zero    "Pseudo Notch valide"          is_valid_mc_username Notch
assert_exit_zero    "Pseudo avec underscore"       is_valid_mc_username "player_one"
assert_exit_nonzero "Pseudo 2 caractères"          is_valid_mc_username ab
assert_exit_nonzero "Pseudo 17 caractères"         is_valid_mc_username abcdefghijklmnopq
assert_exit_nonzero "Pseudo avec espace"           is_valid_mc_username "play er"

echo "-- is_valid_backup_name --"
assert_exit_zero    "Nom backup valide"            is_valid_backup_name backup-20260822-101010.tar.gz
assert_exit_nonzero "Nom backup avec espace"       is_valid_backup_name "backup bad.tar.gz"
assert_exit_nonzero "Nom backup avec /"            is_valid_backup_name "../etc/passwd"

echo "-- modpack_id_exists --"
TMP_MANIFEST="$(mktemp)"
printf '{ "modpacks": [ { "id": "better-minecraft" }, { "id": "atm9-light" } ] }\n' > "$TMP_MANIFEST"
assert_exit_zero    "Modpack known (manifest)"     modpack_id_exists better-minecraft "$TMP_MANIFEST"
assert_exit_nonzero "Modpack inconnu"              modpack_id_exists inexistant "$TMP_MANIFEST"
rm -f "$TMP_MANIFEST"
assert_exit_nonzero "Manifest absent"              modpack_id_exists better-minecraft /tmp/manifest.inexistant.json

echo "-- load_server_conf --"
TMP_CONF="$(mktemp)"
printf 'ORACLE_IP=192.0.2.10\nSSH_KEY_PATH=/tmp/faux.key\nSSH_USER=ubuntu\n' > "$TMP_CONF"
ORACLE_IP=""; SSH_KEY_PATH=""
load_server_conf "$TMP_CONF"
assert_equals "192.0.2.10" "$ORACLE_IP"  "load_server_conf renseigne ORACLE_IP"
assert_equals "/tmp/faux.key" "$SSH_KEY_PATH" "load_server_conf renseigne SSH_KEY_PATH"
rm -f "$TMP_CONF"
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/run_tests.sh`
Expected: FAIL — new functions `is_valid_mc_version` etc. are `command not found`, and `load_server_conf` likewise.

- [ ] **Step 3: Append the implementation to `scripts/lib.sh`**

```bash

# Version Minecraft valide : X.Y ou X.Y.Z (ex. 1.20.1).
is_valid_mc_version() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]
}

# RAM Go valide pour l'Always Free (12 Go au total, 4 Go réservés au système).
# Maximum strict : 8 Go — au-delà, le Linux OOM Killer fait planter le serveur.
is_valid_ram() {
    [[ "$1" =~ ^[0-9]+$ ]] || return 1
    (( 10#$1 >= 2 && 10#$1 <= 8 ))
}

# Nombre de joueurs simultanés raisonnable (1 à 100).
is_valid_player_count() {
    [[ "$1" =~ ^[0-9]+$ ]] || return 1
    (( 10#$1 >= 1 && 10#$1 <= 100 ))
}

# Pseudo Minecraft officiel : 3 à 16 caractères alphanumériques ou _.
is_valid_mc_username() {
    [[ "$1" =~ ^[A-Za-z0-9_]{3,16}$ ]]
}

# Nom de fichier de sauvegarde sûr (pas d'espace, pas de traversée de chemin).
is_valid_backup_name() {
    [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}

# Vérifie qu'un identifiant de modpack figure dans le registre (sans jq local).
modpack_id_exists() {
    local id="$1" manifest="${2:-modpacks/manifest.json}"
    grep -q "\"id\"[[:space:]]*:[[:space:]]*\"$id\"" "$manifest" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Questions interactives (non testées automatiquement)
# ---------------------------------------------------------------------------

# ask_yes_no "Question ?" [y|n]  → retourne 0 si oui, 1 si non.
ask_yes_no() {
    local question="$1" default="${2:-n}" prompt response
    if [[ "$default" == "y" ]]; then prompt="[O/n]"; else prompt="[o/N]"; fi
    read -r -p "$question $prompt : " response
    response="${response:-$default}"
    case "$response" in
        [oO]|[oO][uU][iI]|[yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# ask_number "Question" défaut min max → affiche la valeur saisie sur stdout.
ask_number() {
    local question="$1" default="$2" min="$3" max="$4" value
    while true; do
        read -r -p "$question [$default] : " value
        value="${value:-$default}"
        if [[ "$value" =~ ^[0-9]+$ ]] && (( 10#$value >= min && 10#$value <= max )); then
            printf '%s\n' "$value"
            return 0
        fi
        warn "Valeur invalide (entier entre $min et $max)."
    done
}

# ask_choice "Question ?" "Option 1" "Option 2" ... → remplit SELECTED_CHOICE.
ask_choice() {
    local question="$1"; shift
    local i=1 opt choice n=$#
    printf '\n%s\n' "$question"
    for opt in "$@"; do
        printf '  %d) %s\n' "$i" "$opt"
        i=$((i + 1))
    done
    while true; do
        read -r -p "→ Choix (1-$n) : " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( 10#$choice >= 1 && 10#$choice <= n )); then
            SELECTED_CHOICE="$choice"
            return 0
        fi
        warn "Choix invalide."
    done
}

# ---------------------------------------------------------------------------
# Configuration locale + SSH (utilisés par setup.sh, utils/, security/, uninstall.sh)
# ---------------------------------------------------------------------------

# Charge .server.conf généré par setup.sh (IP, clé, type de serveur...).
load_server_conf() {
    local conf="${1:-./.server.conf}"
    [[ -f "$conf" ]] || die "Configuration locale introuvable ($conf). Lancez d'abord ./setup.sh."
    # shellcheck disable=SC1090
    . "$conf"
    [[ -n "${ORACLE_IP:-}" && -n "${SSH_KEY_PATH:-}" ]] || die "$conf est incomplet (ORACLE_IP/SSH_KEY_PATH)."
}

# Invocation SSH standard vers la VM Oracle.
run_ssh() {
    ssh -i "${SSH_KEY_PATH:?SSH_KEY_PATH non défini}" \
        -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 \
        "${SSH_USER:-ubuntu}@${ORACLE_IP:?ORACLE_IP non définie}" "$@"
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/run_tests.sh`
Expected: `SUITE : SUCCÈS`.

- [ ] **Step 5: Commit**

```bash
git add scripts/lib.sh tests/test_lib.sh
git commit -m "feat: validations complètes et helpers SSH dans lib.sh"
```

---

### Task 4: `configs/` — templates serveur

**Files:**
- Create: `configs/server.properties.template`
- Create: `configs/user_jvm_args.txt.template`
- Create: `configs/eula.txt`
- Create: `tests/test_configs.sh`

**Interfaces:**
- Consumes: test helpers (Task 2).
- Produces: templates consumed by `remote_provision.sh` (Task 8): `__RAM__` placeholder in `user_jvm_args.txt.template` is replaced by the RAM value; `rcon.password=__RCON_PASSWORD__` and `max-players=20` lines are rewritten by provisioning; `white-list` key exists for `whitelist_manager.sh` (Task 16).

- [ ] **Step 1: Write the failing test**

`tests/test_configs.sh`:

```bash
#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"

echo "-- présence des fichiers --"
assert_file_exists configs/server.properties.template "server.properties.template présent"
assert_file_exists configs/user_jvm_args.txt.template  "user_jvm_args.txt.template présent"
assert_file_exists configs/eula.txt                    "eula.txt présent"

echo "-- server.properties.template --"
assert_file_contains configs/server.properties.template "max-players=20"           "max-players présent"
assert_file_contains configs/server.properties.template "server-port=25565"        "port serveur 25565"
assert_file_contains configs/server.properties.template "view-distance=8"          "view-distance optimisée"
assert_file_contains configs/server.properties.template "simulation-distance=8"   "simulation-distance optimisée"
assert_file_contains configs/server.properties.template "enable-rcon=true"         "RCON activé"
assert_file_contains configs/server.properties.template "rcon.password=__RCON_PASSWORD__" "mot de passe RCON à injecter"
assert_file_contains configs/server.properties.template "white-list=false"         "whitelist désactivée par défaut"
assert_file_not_contains configs/server.properties.template "allow-the-end"        "clé inventée absente"
assert_file_not_contains configs/server.properties.template "spawn-monsters=70"    "valeur numérique invalide absente"

echo "-- user_jvm_args.txt.template --"
assert_file_contains configs/user_jvm_args.txt.template "-Xms__RAM__G"             "Xms paramétré"
assert_file_contains configs/user_jvm_args.txt.template "-Xmx__RAM__G"             "Xmx paramétré (parité Xms/Xmx)"
assert_file_contains configs/user_jvm_args.txt.template "-XX:+UseZGC"              "GC ZGC"
assert_file_contains configs/user_jvm_args.txt.template "-XX:+ZGenerational"       "ZGC générationnel (JDK 21)"
assert_file_contains configs/user_jvm_args.txt.template "-XX:+UnlockExperimentalVMOptions" "déverrouillage options expérimentales"
assert_file_contains configs/user_jvm_args.txt.template "-XX:+AlwaysPreTouch"      "AlwaysPreTouch"
assert_file_contains configs/user_jvm_args.txt.template "-XX:+UseStringDeduplication" "déduplication des chaînes"
assert_file_contains configs/user_jvm_args.txt.template "-XX:+DisableExplicitGC"   "DisableExplicitGC"
assert_file_not_contains configs/user_jvm_args.txt.template "SilentGCThreads"      "flag obsolète absent"

echo "-- eula.txt --"
assert_file_contains configs/eula.txt "eula=true" "EULA acceptée"

finish_tests
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL — the three `configs/` files are absent.

- [ ] **Step 3: Create the templates**

`configs/server.properties.template`:

```properties
# =============================================================================
# server.properties — généré par oracle-minecraft-5min-setup (V3.0)
# Template copié par remote_provision.sh, puis ajusté (max-players, RCON).
# =============================================================================

# --- BASE ---
motd=§l§6Serveur Oracle Cloud §r§f- setup en 5 minutes
gamemode=survival
difficulty=hard
pvp=true
level-type=minecraft\:normal
level-seed=
generate-structures=true
allow-nether=true

# --- JOUEURS ---
max-players=20
white-list=false
enforce-secure-profile=true

# --- PERFORMANCE (adapté à 2 OCPU ARM) ---
view-distance=8
simulation-distance=8
max-tick-time=60000
spawn-animals=true
spawn-monsters=true
spawn-npcs=true

# --- RÉSEAU ---
server-port=25565
enable-query=true
query.port=25565

# --- RCON (administration locale uniquement ; mot de passe injecté au setup) ---
enable-rcon=true
rcon.port=25575
rcon.password=__RCON_PASSWORD__

# --- DIVERS ---
spawn-protection=0
force-gamemode=false
allow-flight=false
```

`configs/user_jvm_args.txt.template`:

```
# Arguments JVM — calibrés pour Oracle Cloud Ampere A1 (ARM64) / OpenJDK 21.
# La mémoire (__RAM__ Go) est injectée par remote_provision.sh.
# Règle Always Free : maximum 8 Go pour la JVM (12 Go au total sur la VM).
-Xms__RAM__G
-Xmx__RAM__G
-XX:+UnlockExperimentalVMOptions
-XX:+UseZGC
-XX:+ZGenerational
-XX:+AlwaysPreTouch
-XX:+UseStringDeduplication
-XX:+DisableExplicitGC
```

`configs/eula.txt`:

```
# EULA Minecraft acceptée par l'utilisateur lors de l'exécution de setup.sh
# (https://aka.ms/MinecraftEULA).
eula=true
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/run_tests.sh`
Expected: `SUITE : SUCCÈS`.

- [ ] **Step 5: Commit**

```bash
git add configs/ tests/test_configs.sh
git commit -m "feat: templates server.properties, flags JVM ARM64 et EULA"
```

---

### Task 5: `modpacks/` — registre et métadonnées

**Files:**
- Create: `modpacks/manifest.json`
- Create: `modpacks/better-minecraft.json`
- Create: `modpacks/atm9-light.json`
- Create: `modpacks/vanilla-plus.json`
- Create: `tests/test_modpacks.sh`

**Interfaces:**
- Consumes: test helpers (Task 2).
- Produces: JSON metadata consumed by `setup.sh` (Task 9, via `modpack_id_exists` and grep display) and validated by `remote_provision.sh` (Task 8, which requires `${STAGING}/modpacks/${MODPACK}.json` to exist). Schema per pack: `id`, `nom`, `description`, `difficulte`, `loader` (`forge`|`fabric`), `mc_version`, `ram_recommandee_go`, `page_curseforge`, `server_pack_url` (may be `""`), `instructions`.

Design decision (honesty): modpack zips cannot legally be bundled in the repo and CurseForge download URLs are not stable, so the server-pack URL is **supplied by the user at setup time** (setup.sh shows the CurseForge page from the JSON and explains where to grab the server pack). The JSONs carry display metadata + the CurseForge project page.

- [ ] **Step 1: Write the failing test**

`tests/test_modpacks.sh`:

```bash
#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"

# shellcheck source=scripts/lib.sh
. "${REPO_ROOT}/scripts/lib.sh"

echo "-- présence --"
for f in manifest.json better-minecraft.json atm9-light.json vanilla-plus.json; do
    assert_file_exists "modpacks/$f" "modpacks/$f présent"
done

echo "-- cohérence du registre --"
assert_exit_zero "better-minecraft référencé"  modpack_id_exists better-minecraft "${REPO_ROOT}/modpacks/manifest.json"
assert_exit_zero "atm9-light référencé"        modpack_id_exists atm9-light       "${REPO_ROOT}/modpacks/manifest.json"
assert_exit_zero "vanilla-plus référencé"      modpack_id_exists vanilla-plus     "${REPO_ROOT}/modpacks/manifest.json"

echo "-- champs obligatoires par modpack --"
check_pack() { # fichier
    local f="modpacks/$1"
    for key in '"id"' '"nom"' '"description"' '"difficulte"' '"loader"' '"mc_version"' '"ram_recommandee_go"' '"instructions"'; do
        assert_file_contains "$f" "$key" "$1 contient $key"
    done
}
check_pack better-minecraft.json
check_pack atm9-light.json
check_pack vanilla-plus.json

echo "-- validation JSON (si python3 disponible) --"
if command -v python3 >/dev/null 2>&1; then
    for f in manifest.json better-minecraft.json atm9-light.json vanilla-plus.json; do
        assert_exit_zero "JSON valide : $f" python3 -m json.tool "modpacks/$f"
    done
else
    echo "  (python3 absent — validation JSON syntaxique sautée)"
fi

finish_tests
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL — `modpacks/` files absent.

- [ ] **Step 3: Create the JSON files**

`modpacks/manifest.json`:

```json
{
  "commentaire": "Registre des modpacks disponibles. Pour en ajouter un : créez <id>.json ici et ajoutez une entrée dans modpacks.",
  "modpacks": [
    { "id": "better-minecraft", "fichier": "better-minecraft.json" },
    { "id": "atm9-light",       "fichier": "atm9-light.json" },
    { "id": "vanilla-plus",     "fichier": "vanilla-plus.json" }
  ]
}
```

`modpacks/better-minecraft.json`:

```json
{
  "id": "better-minecraft",
  "nom": "Better Minecraft [Forge]",
  "description": "Survie améliorée, environ 150 mods, équilibrée. Idéal pour débuter en moddé.",
  "difficulte": "Facile",
  "loader": "forge",
  "mc_version": "1.20.1",
  "ram_recommandee_go": 8,
  "page_curseforge": "https://www.curseforge.com/minecraft/modpacks/better-minecraft-forge",
  "server_pack_url": "",
  "instructions": "Ouvrez la page CurseForge, onglet Files, choisissez une version 1.20.1, section Additional Files : téléchargez le fichier « Server Pack » et collez son URL directe dans setup.sh."
}
```

`modpacks/atm9-light.json`:

```json
{
  "id": "atm9-light",
  "nom": "All The Mods 9 (édition allégée)",
  "description": "Tech + magie, grosse progression. Privilégiez une version light/server pack pour 12 Go de RAM.",
  "difficulte": "Moyen",
  "loader": "forge",
  "mc_version": "1.20.1",
  "ram_recommandee_go": 8,
  "page_curseforge": "https://www.curseforge.com/minecraft/modpacks/all-the-mods-9",
  "server_pack_url": "",
  "instructions": "Ouvrez la page CurseForge du modpack, onglet Files, section Additional Files d'une version 1.20.1 : téléchargez le « Server Pack » et collez son URL directe dans setup.sh."
}
```

`modpacks/vanilla-plus.json`:

```json
{
  "id": "vanilla-plus",
  "nom": "Vanilla+ (performance, Fabric)",
  "description": "Vanilla optimisé + utilitaires légers. Le plus sobre en RAM (4 à 6 Go).",
  "difficulte": "Très facile",
  "loader": "fabric",
  "mc_version": "1.20.1",
  "ram_recommandee_go": 4,
  "page_curseforge": "https://www.curseforge.com/minecraft/modpacks",
  "server_pack_url": "",
  "instructions": "Peu de packs Fabric fournissent un server pack : vous pouvez aussi choisir le type « Fabric » dans setup.sh puis ajouter les mods serveur manuellement (dossier mods/). Si un server pack existe, collez son URL directe."
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/run_tests.sh`
Expected: `SUITE : SUCCÈS`.

- [ ] **Step 5: Commit**

```bash
git add modpacks/ tests/test_modpacks.sh
git commit -m "feat: registre modpacks + métadonnées (better-minecraft, atm9-light, vanilla-plus)"
```

---

### Task 6: `deploy/configure_iptables.sh` — pare-feu hôte OCI

**Files:**
- Create: `deploy/configure_iptables.sh`
- Create: `tests/test_deploy_scripts.sh`

**Interfaces:**
- Consumes: nothing (standalone, runs as root on the VM).
- Produces: a script invoked by `remote_provision.sh` (Task 8) as `bash "${STAGING}/deploy/configure_iptables.sh"`; opens TCP+UDP 25565 and TCP 8443 before Oracle's REJECT rule, persists with `netfilter-persistent save`.

- [ ] **Step 1: Write the failing test**

`tests/test_deploy_scripts.sh`:

```bash
#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"

echo "-- configure_iptables.sh --"
assert_file_exists deploy/configure_iptables.sh "configure_iptables.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n deploy/configure_iptables.sh
assert_file_contains deploy/configure_iptables.sh "iptables -C"                "vérification d'existence (idempotence)"
assert_file_contains deploy/configure_iptables.sh "iptables -I INPUT"          "insertion dans la chaîne INPUT"
assert_file_contains deploy/configure_iptables.sh "REJECT"                     "détection de la règle REJECT d'Oracle"
assert_file_contains deploy/configure_iptables.sh "netfilter-persistent save"  "persistance des règles"
assert_file_contains deploy/configure_iptables.sh "25565"                      "port Minecraft"
assert_file_contains deploy/configure_iptables.sh "8443"                       "port Crafty"
assert_file_not_contains deploy/configure_iptables.sh "ufw"                    "ufw interdit sur OCI"

finish_tests
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL — script absent.

- [ ] **Step 3: Create `deploy/configure_iptables.sh`**

```bash
#!/usr/bin/env bash
# =============================================================================
# configure_iptables.sh — Ouverture des ports sur une VM Ubuntu OCI.
# S'EXÉCUTE SUR LA VM (root). Les images Ubuntu d'Oracle embarquent des règles
# iptables se terminant par un REJECT global : ufw est donc INTERDIT (conflit).
# On insère nos règles AVANT le REJECT, puis on persiste via netfilter-persistent.
# Idempotent : les règles déjà présentes ne sont pas dupliquées.
# =============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "[ERREUR] Ce script doit être exécuté avec sudo (root)." >&2
    exit 1
fi

# Numéro de la première règle REJECT de la chaîne INPUT (règle finale d'Oracle).
# On insère juste avant elle ; si elle est introuvable, on insère en tête.
REJECT_LINE="$(iptables -L INPUT --line-numbers -n | awk '/REJECT/ {print $1; exit}')"
INSERT_AT="${REJECT_LINE:-1}"

add_rule() { # protocole port
    local proto="$1" port="$2"
    if iptables -C INPUT -p "$proto" --dport "$port" -m state --state NEW -j ACCEPT 2>/dev/null; then
        echo "[iptables] Règle déjà présente : ${proto}/${port}"
    else
        iptables -I INPUT "$INSERT_AT" -p "$proto" --dport "$port" -m state --state NEW -j ACCEPT
        echo "[iptables] Règle ajoutée : ${proto}/${port} (position ${INSERT_AT})"
    fi
}

add_rule tcp 25565   # Minecraft (TCP)
add_rule udp 25565   # Minecraft (UDP : query, mods vocaux)
add_rule tcp 8443    # Crafty Controller (panel web)

# Persistance après redémarrage
netfilter-persistent save
echo "[iptables] Règles sauvegardées (netfilter-persistent)."
echo "[iptables] RAPPEL : les Ingress Rules du VCN doivent AUSSI être ouvertes"
echo "[iptables] dans la console Oracle (voir docs/oci-vcn-config.md)."
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/run_tests.sh`
Expected: `SUITE : SUCCÈS`.

- [ ] **Step 5: Commit**

```bash
git add deploy/configure_iptables.sh tests/test_deploy_scripts.sh
git commit -m "feat: pare-feu iptables OCI (insertion avant REJECT, idempotent, sans ufw)"
```

---

### Task 7: `deploy/docker-compose.crafty.yml` — Crafty Controller

**Files:**
- Create: `deploy/docker-compose.crafty.yml`
- Modify: `tests/test_deploy_scripts.sh` (append before `finish_tests`)

**Interfaces:**
- Consumes: nothing.
- Produces: compose file copied by `remote_provision.sh` (Task 8) to `/opt/minecraft/docker-crafty/docker-compose.yml` and started with `docker compose up -d`.

- [ ] **Step 1: Append the failing test**

Append to `tests/test_deploy_scripts.sh`, before `finish_tests`:

```bash
echo "-- docker-compose.crafty.yml --"
assert_file_exists deploy/docker-compose.crafty.yml "docker-compose.crafty.yml présent"
assert_file_contains deploy/docker-compose.crafty.yml "registry.gitlab.com/crafty-controller/crafty-4" "image officielle Crafty 4"
assert_file_contains deploy/docker-compose.crafty.yml "8443:8443"              "port web Crafty"
assert_file_contains deploy/docker-compose.crafty.yml "/opt/minecraft/server:/crafty/servers" "serveur MC exposé à Crafty"
assert_file_contains deploy/docker-compose.crafty.yml "restart: always"        "redémarrage automatique"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL on the new assertions.

- [ ] **Step 3: Create `deploy/docker-compose.crafty.yml`**

```yaml
# =============================================================================
# Crafty Controller v4 — panel web d'administration Minecraft.
# Déployé par remote_provision.sh dans /opt/minecraft/docker-crafty/.
# L'installation via l'installeur interactif officiel est proscrite (fragile) :
# on utilise exclusivement le conteneur officiel.
# =============================================================================
services:
  crafty:
    container_name: crafty_controller
    image: registry.gitlab.com/crafty-controller/crafty-4:latest
    restart: always
    environment:
      - TZ=Europe/Paris
    ports:
      - "8443:8443"   # Interface web (https)
      - "8123:8123"   # Port interne Crafty
    volumes:
      - /opt/minecraft/docker-crafty/backups:/crafty/backups
      - /opt/minecraft/docker-crafty/logs:/crafty/logs
      - /opt/minecraft/docker-crafty/app:/crafty/app
      - /opt/minecraft/server:/crafty/servers
```

(No `version:` key — removed from modern Compose; it only triggers an obsolescence warning.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/run_tests.sh`
Expected: `SUITE : SUCCÈS`.

- [ ] **Step 5: Commit**

```bash
git add deploy/docker-compose.crafty.yml tests/test_deploy_scripts.sh
git commit -m "feat: Crafty Controller conteneurisé (docker compose)"
```

---

### Task 8: `deploy/remote_provision.sh` — provisionnement distant

**Files:**
- Create: `deploy/remote_provision.sh`
- Modify: `tests/test_deploy_scripts.sh` (append before `finish_tests`)

**Interfaces:**
- Consumes: `deploy/configure_iptables.sh`, `deploy/docker-compose.crafty.yml`, `configs/*.template`, `configs/eula.txt`, `modpacks/<id>.json` (all from the `/tmp/setup` staging dir), `utils/rcon_client.py` (copied to `/opt/minecraft/bin/` — file created in Task 11; until then the copy line must tolerate absence).
- Produces: on the VM — user `minecraft`, `/opt/minecraft/{server,backups,bin}`, engine installed with `start.sh`, `server.properties` (with real RCON password), `user_jvm_args.txt` (RAM injected), `eula.txt`, `.rcon-credentials`, systemd unit `minecraft.service`, Crafty container (optional), listening port 25565. CLI contract used by `setup.sh` (Task 9) and `utils/update.sh` (Task 14):

```
sudo bash remote_provision.sh --ip <IP> --server-type <vanilla|forge|fabric|modpack> \
    --mc-version <X.Y[.Z]> --ram <2..8> --players <n> --crafty <true|false> \
    --modpack <id|none> --pack-url <url|-> [--forge-build <X.Y.Z>] [--update-server]
```

Modes: `install` (default; preserves an existing `world/`, only repairs user/firewall/service) and `--update-server` (refresh engine binaries, never touches `world/`, configs or eula).

- [ ] **Step 1: Append the failing test**

Append to `tests/test_deploy_scripts.sh`, before `finish_tests`:

```bash
echo "-- remote_provision.sh --"
assert_file_exists deploy/remote_provision.sh "remote_provision.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n deploy/remote_provision.sh
assert_file_contains deploy/remote_provision.sh "set -euo pipefail"            "mode strict"
assert_file_contains deploy/remote_provision.sh "openjdk-21-jre-headless"      "OpenJDK 21"
assert_file_contains deploy/remote_provision.sh "useradd"                      "utilisateur dédié minecraft"
assert_file_contains deploy/remote_provision.sh "usr/sbin/nologin"             "shell nologin"
assert_file_contains deploy/remote_provision.sh "--installServer"              "installation silencieuse Forge"
assert_file_contains deploy/remote_provision.sh "unix_args.txt"                "amorçage Forge moderne"
assert_file_not_contains deploy/remote_provision.sh "minecraft_server.jar"     "java -jar obsolète interdit"
assert_file_not_contains deploy/remote_provision.sh "ufw"                      "ufw interdit"
assert_file_contains deploy/remote_provision.sh "minecraft.service"            "unité systemd"
assert_file_contains deploy/remote_provision.sh "Restart=on-failure"           "redémarrage auto"
assert_file_contains deploy/remote_provision.sh "SuccessExitStatus=0 143"      "arrêt propre (SIGTERM)"
assert_file_contains deploy/remote_provision.sh "docker compose up -d"         "Crafty via compose"
assert_file_contains deploy/remote_provision.sh "ss -tln"                      "vérification port 25565"
assert_file_contains deploy/remote_provision.sh "piston-meta.mojang.com"      "résolution vanilla dynamique"
assert_file_contains deploy/remote_provision.sh "meta.fabricmc.net"            "résolution fabric dynamique"
assert_file_contains deploy/remote_provision.sh "__RCON_PASSWORD__"            "injection mot de passe RCON"
assert_file_contains deploy/remote_provision.sh "__RAM__"                      "injection RAM JVM"
assert_file_contains deploy/remote_provision.sh "--update-server"              "mode mise à jour"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL on the new assertions.

- [ ] **Step 3: Create `deploy/remote_provision.sh`**

```bash
#!/usr/bin/env bash
# =============================================================================
# remote_provision.sh — Provisionnement du serveur Minecraft sur la VM OCI.
#
# ⚠️ S'EXÉCUTE SUR LA VM Ubuntu (ARM64), jamais sur la machine locale.
#    setup.sh le transfère dans /tmp/setup/ puis le lance via SSH.
#
# Usage :
#   sudo bash remote_provision.sh --ip <IP_PUBLIQUE> \
#        --server-type <vanilla|forge|fabric|modpack> \
#        --mc-version <version> --ram <Go> [--players <n>] \
#        [--crafty <true|false>] [--modpack <id|none>] [--pack-url <url|->] \
#        [--forge-build <build>] [--update-server]
#
# Garanties :
#   - Idempotent : ré-exécutable sans dupliquer les règles ni écraser un monde.
#   - Le serveur tourne sous l'utilisateur dédié 'minecraft' (jamais root).
#   - Forge 1.17+ : lancement via @unix_args.txt (jamais java -jar).
# =============================================================================
set -euo pipefail

# --- Constantes ---
MOJANG_MANIFEST="https://piston-meta.mojang.com/mc/game/version_manifest.json"
FABRIC_META="https://meta.fabricmc.net/v2/versions/loader"
INSTALL_ROOT="/opt/minecraft"
SERVER_DIR="${INSTALL_ROOT}/server"
STAGING="/tmp/setup"

# Build Forge par défaut pour MC 1.20.1 (modifiable via --forge-build).
FORGE_BUILD="47.2.0"

# --- Variables remplies par les arguments ---
REMOTE_IP="" SERVER_TYPE="" MC_VERSION="" RAM_GB=""
PLAYERS="20" INSTALL_CRAFTY="false" MODPACK="none" PACK_URL="-" MODE="install"

die() { printf '\n[ERREUR FATALE] %s\n' "$*" >&2; exit 1; }
log()  { printf '[provision] %s\n' "$*"; }

usage() {
    sed -n 's/^# \{0,1\}//p' "$0" | sed -n '3,20p'
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ip)           REMOTE_IP="$2"; shift 2 ;;
            --server-type)  SERVER_TYPE="$2"; shift 2 ;;
            --mc-version)   MC_VERSION="$2"; shift 2 ;;
            --ram)          RAM_GB="$2"; shift 2 ;;
            --players)      PLAYERS="$2"; shift 2 ;;
            --crafty)       INSTALL_CRAFTY="$2"; shift 2 ;;
            --modpack)      MODPACK="$2"; shift 2 ;;
            --pack-url)     PACK_URL="$2"; shift 2 ;;
            --forge-build)  FORGE_BUILD="$2"; shift 2 ;;
            --update-server) MODE="update"; shift ;;
            -h|--help)      usage; exit 0 ;;
            *) die "Argument inconnu : $1 (voir --help)" ;;
        esac
    done
    [[ -n "$REMOTE_IP" ]]      || die "--ip requis"
    [[ -n "$SERVER_TYPE" ]]    || die "--server-type requis"
    case "$SERVER_TYPE" in
        vanilla|forge|fabric|modpack) ;;
        *) die "--server-type invalide : $SERVER_TYPE" ;;
    esac
    [[ "$MC_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || die "--mc-version invalide : $MC_VERSION"
    [[ "$RAM_GB" =~ ^[0-9]+$ ]] || die "--ram invalide : $RAM_GB"
    (( 10#$RAM_GB >= 2 && 10#$RAM_GB <= 8 )) \
        || die "--ram doit être entre 2 et 8 Go (12 Go au total, 4 Go réservés au système)"
    [[ "$PLAYERS" =~ ^[0-9]+$ && 10#$PLAYERS -ge 1 ]] || die "--players invalide"
    [[ "$INSTALL_CRAFTY" == "true" || "$INSTALL_CRAFTY" == "false" ]] || die "--crafty doit valoir true ou false"
    [[ "$FORGE_BUILD" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "--forge-build invalide : $FORGE_BUILD"
    if [[ "$SERVER_TYPE" == "modpack" ]]; then
        [[ "$PACK_URL" != "-" ]] || die "--pack-url requis pour un modpack (URL du server pack)"
        if [[ "$MODE" == "install" ]]; then
            [[ -f "${STAGING}/modpacks/${MODPACK}.json" ]] || die "Modpack inconnu : $MODPACK"
        fi
    fi
}

step_system_packages() {
    log "Mise à jour du système et installation des paquets..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq \
        openjdk-21-jre-headless docker.io docker-compose-v2 \
        netfilter-persistent iptables-persistent \
        curl wget jq unzip screen htop python3 >/dev/null
    log "Java installé : $(java -version 2>&1 | head -n 1)"
}

step_minecraft_user() {
    if id -u minecraft >/dev/null 2>&1; then
        log "Utilisateur système 'minecraft' déjà présent."
    else
        log "Création de l'utilisateur système 'minecraft' (sans privilèges)..."
        useradd -r -m -U -d "$INSTALL_ROOT" -s /usr/sbin/nologin minecraft
    fi
}

step_directories() {
    mkdir -p "${INSTALL_ROOT}/server" "${INSTALL_ROOT}/backups" "${INSTALL_ROOT}/bin"
    # Copie des outils d'administration (présents uniquement en mode install,
    # lorsque le staging /tmp/setup existe).
    if [[ -d "${STAGING}/utils" ]]; then
        cp "${STAGING}/utils/rcon_client.py" "${INSTALL_ROOT}/bin/rcon_client.py"
        cp "${STAGING}/deploy/remote_provision.sh" "${INSTALL_ROOT}/bin/remote_provision.sh"
        chmod 755 "${INSTALL_ROOT}/bin/rcon_client.py" "${INSTALL_ROOT}/bin/remote_provision.sh"
    fi
    chown -R minecraft:minecraft "$INSTALL_ROOT"
}

step_firewall() {
    log "Configuration du pare-feu iptables (OCI — ufw proscrit)..."
    bash "${STAGING}/deploy/configure_iptables.sh"
}

step_crafty() {
    if [[ "$INSTALL_CRAFTY" != "true" ]]; then return 0; fi
    log "Déploiement de Crafty Controller via Docker Compose..."
    mkdir -p "${INSTALL_ROOT}/docker-crafty"
    cp "${STAGING}/deploy/docker-compose.crafty.yml" "${INSTALL_ROOT}/docker-crafty/docker-compose.yml"
    chown -R minecraft:minecraft "${INSTALL_ROOT}/docker-crafty"
    ( cd "${INSTALL_ROOT}/docker-crafty" && docker compose up -d )
    log "Crafty Controller accessible sur https://${REMOTE_IP}:8443"
}

download_file() { # url destination
    curl -fsSL --retry 3 -o "$2" "$1" || die "Téléchargement échoué : $1"
}

generate_forge_start_script() {
    # Depuis Forge 1.17 : l'installateur ne produit plus un JAR autonome mais
    # libraries/ + unix_args.txt. Le lancement DOIT passer par @unix_args.txt.
    local unix_args rel
    unix_args="$(find "${SERVER_DIR}/libraries/net/minecraftforge/forge" \
        -name unix_args.txt -type f 2>/dev/null | head -n 1)"
    [[ -n "$unix_args" ]] || die "unix_args.txt introuvable — installation Forge en échec"
    rel="${unix_args#"${SERVER_DIR}/"}"
    cat > "${SERVER_DIR}/start.sh" <<EOF
#!/bin/bash
# Démarrage Forge — généré par remote_provision.sh (amorçage @unix_args.txt)
cd "\$(dirname "\$0")"
exec java @user_jvm_args.txt @${rel} nogui "\$@"
EOF
    chown minecraft:minecraft "${SERVER_DIR}/start.sh"
    chmod 755 "${SERVER_DIR}/start.sh"
}

write_simple_start_script() { # jar_name
    cat > "${SERVER_DIR}/start.sh" <<EOF
#!/bin/bash
# Démarrage ${SERVER_TYPE} — généré par remote_provision.sh
cd "\$(dirname "\$0")"
exec java @user_jvm_args.txt -jar "$1" nogui "\$@"
EOF
    chown minecraft:minecraft "${SERVER_DIR}/start.sh"
    chmod 755 "${SERVER_DIR}/start.sh"
}

install_engine_vanilla() {
    log "Installation Vanilla ${MC_VERSION} (résolution via piston-meta)..."
    local version_url server_url
    version_url="$(curl -fsSL "$MOJANG_MANIFEST" \
        | jq -r --arg v "$MC_VERSION" '.versions[] | select(.id==$v) | .url')"
    [[ -n "$version_url" && "$version_url" != "null" ]] \
        || die "Version Vanilla introuvable : ${MC_VERSION}"
    server_url="$(curl -fsSL "$version_url" | jq -r '.downloads.server.url')"
    [[ -n "$server_url" && "$server_url" != "null" ]] \
        || die "Pas de binaire serveur pour ${MC_VERSION}"
    download_file "$server_url" "${SERVER_DIR}/server.jar"
    chown minecraft:minecraft "${SERVER_DIR}/server.jar"
    write_simple_start_script "server.jar"
}

install_engine_forge() {
    local coords="${MC_VERSION}-${FORGE_BUILD}"
    local base="https://maven.minecraftforge.net/net/minecraftforge/forge/${coords}"
    local installer="forge-${coords}-installer.jar"
    log "Installation Forge ${coords} (2 à 3 minutes)..."
    download_file "${base}/${installer}" "${SERVER_DIR}/${installer}"
    ( cd "$SERVER_DIR" && sudo -u minecraft java -jar "$installer" --installServer "$SERVER_DIR" )
    rm -f "${SERVER_DIR:?}/${installer}"
    generate_forge_start_script
}

install_engine_fabric() {
    log "Installation Fabric ${MC_VERSION}..."
    local loader server_url
    loader="$(curl -fsSL "$FABRIC_META" | jq -r '.[0].version')"
    [[ -n "$loader" && "$loader" != "null" ]] || die "Loader Fabric introuvable"
    server_url="${FABRIC_META}/${MC_VERSION}/${loader}/server/jar"
    download_file "$server_url" "${SERVER_DIR}/fabric-server-launch.jar"
    chown minecraft:minecraft "${SERVER_DIR}/fabric-server-launch.jar"
    write_simple_start_script "fabric-server-launch.jar"
}

install_modpack_pack() {
    log "Installation du modpack '${MODPACK}' depuis le server pack..."
    local zip="${SERVER_DIR}/modpack-server-pack.zip"
    download_file "$PACK_URL" "$zip"
    ( cd "$SERVER_DIR" && unzip -oq "$zip" )
    rm -f "$zip"
    chown -R minecraft:minecraft "$SERVER_DIR"
    if find "${SERVER_DIR}/libraries" -name unix_args.txt -type f 2>/dev/null | grep -q .; then
        generate_forge_start_script        # server pack Forge standard
    elif [[ -f "${SERVER_DIR}/run.sh" ]]; then
        printf '#!/bin/bash\ncd "$(dirname "$0")"\nexec bash run.sh nogui "$@"\n' \
            > "${SERVER_DIR}/start.sh"     # server pack avec run.sh
        chown minecraft:minecraft "${SERVER_DIR}/start.sh"
        chmod 755 "${SERVER_DIR}/start.sh"
    else
        die "Server pack inattendu : ni unix_args.txt ni run.sh trouvé (layout non standard)"
    fi
}

apply_server_config() {
    log "Application de la configuration (properties, EULA, JVM, RCON)..."
    local props="${SERVER_DIR}/server.properties"
    cp "${STAGING}/configs/server.properties.template" "$props"
    sed -i "s/^max-players=.*/max-players=${PLAYERS}/" "$props"
    # Mot de passe RCON aléatoire, injecté puis stocké localement à la VM.
    local rcon_pass
    rcon_pass="$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)"
    [[ ${#rcon_pass} -ge 16 ]] || die "Génération du mot de passe RCON échouée"
    sed -i "s/^rcon.password=.*/rcon.password=${rcon_pass}/" "$props"
    printf 'RCON_HOST=127.0.0.1\nRCON_PORT=25575\nRCON_PASSWORD=%s\n' "$rcon_pass" \
        > "${SERVER_DIR}/.rcon-credentials"
    chmod 600 "${SERVER_DIR}/.rcon-credentials"
    cp "${STAGING}/configs/eula.txt" "${SERVER_DIR}/eula.txt"
    sed "s/__RAM__/${RAM_GB}/g" "${STAGING}/configs/user_jvm_args.txt.template" \
        > "${SERVER_DIR}/user_jvm_args.txt"
    chown -R minecraft:minecraft "$SERVER_DIR"
}

step_systemd() {
    log "Installation du service systemd 'minecraft'..."
    cat > /etc/systemd/system/minecraft.service <<'EOF'
[Unit]
Description=Serveur Minecraft (oracle-minecraft-5min-setup)
After=network.target

[Service]
User=minecraft
Group=minecraft
WorkingDirectory=/opt/minecraft/server
ExecStart=/bin/bash /opt/minecraft/server/start.sh
Restart=on-failure
RestartSec=20s
SuccessExitStatus=0 143
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable minecraft >/dev/null
}

step_first_boot() {
    log "Démarrage du serveur (génération du monde : 1 à 5 minutes)..."
    systemctl restart minecraft
    local i
    for i in $(seq 1 60); do
        if ss -tln | grep -q ':25565 '; then
            log "Port 25565 en écoute — serveur démarré."
            return 0
        fi
        systemctl is-active --quiet minecraft || break
        sleep 5
    done
    echo "---- 50 dernières lignes du journal du service ----"
    journalctl -u minecraft -n 50 --no-pager || true
    die "Le serveur n'est pas encore en écoute (voir journal ci-dessus). S'il s'agit d'un gros modpack, il peut simplement être lent : surveillez 'systemctl status minecraft'."
}

final_summary() {
    echo
    echo "=============================================================="
    echo "  Serveur Minecraft opérationnel !"
    echo "  Adresse de connexion : ${REMOTE_IP}:25565"
    if [[ "$INSTALL_CRAFTY" == "true" ]]; then
        echo "  Panel Crafty         : https://${REMOTE_IP}:8443"
    fi
    echo "  Gestion              : ssh ${SUDO_USER:-ubuntu}@${REMOTE_IP} 'systemctl status minecraft'"
    echo "=============================================================="
    echo "  Si la connexion depuis Minecraft échoue : ouvrez les"
    echo "  Ingress Rules du VCN Oracle (docs/oci-vcn-config.md)."
    echo "=============================================================="
}

main() {
    parse_args "$@"
    [[ $EUID -eq 0 ]] || die "Ce script doit être lancé avec sudo"

    step_system_packages
    step_minecraft_user
    step_directories

    if [[ "$MODE" == "install" ]]; then
        step_firewall
    fi

    if [[ "$MODE" == "install" && -d "${SERVER_DIR}/world" && -f "${SERVER_DIR}/server.properties" ]]; then
        log "Monde existant détecté — préservé (utilisez --update-server pour changer de version)."
    else
        case "$SERVER_TYPE" in
            vanilla) install_engine_vanilla ;;
            forge)   install_engine_forge ;;
            fabric)  install_engine_fabric ;;
            modpack) install_modpack_pack ;;
        esac
        # En mode update, on ne touche NI au monde NI à la configuration.
        if [[ "$MODE" == "install" ]]; then
            apply_server_config
        fi
    fi

    if [[ "$MODE" == "install" ]]; then
        step_crafty
    fi

    step_systemd
    step_first_boot

    [[ -d "$STAGING" ]] && rm -rf "$STAGING"
    final_summary
}

main "$@"
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/run_tests.sh`
Expected: `SUITE : SUCCÈS` (all `remote_provision.sh` assertions OK, `bash -n` clean).

- [ ] **Step 5: Commit**

```bash
git add deploy/remote_provision.sh tests/test_deploy_scripts.sh
git commit -m "feat: provisionnement distant complet (user dédié, Forge @unix_args, systemd, idempotent)"
```

---

### Task 9: `setup.sh` — orchestrateur local

**Files:**
- Create: `setup.sh`
- Create: `tests/test_setup.sh`

**Interfaces:**
- Consumes: `scripts/lib.sh` (all validations, `ask_*`, colors), `deploy/`, `configs/`, `modpacks/`, `utils/rcon_client.py`.
- Produces: `.server.conf` at repo root (gitignored) containing `ORACLE_IP`, `SSH_KEY_PATH`, `SSH_USER=ubuntu`, `SERVER_TYPE`, `MC_VERSION`, `RAM_GB`, `MODPACK` — consumed by `load_server_conf` (utils, security, uninstall). CLI flags: `--ip --key --type --mc-version --ram --players --crafty --modpack --pack-url --yes --dry-run` (used by tests for a non-interactive dry run).

- [ ] **Step 1: Write the failing test**

`tests/test_setup.sh`:

```bash
#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"

echo "-- présence et syntaxe --"
assert_file_exists setup.sh "setup.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n setup.sh

echo "-- contenu attendu --"
assert_file_contains setup.sh "scripts/lib.sh"          "source lib.sh"
assert_file_contains setup.sh "remote_provision.sh"     "appelle le provisionnement distant"
assert_file_contains setup.sh ".server.conf"            "sauvegarde la configuration locale"
assert_file_contains setup.sh "StrictHostKeyChecking"   "SSH non interactif"
assert_file_contains setup.sh "docs/oci-vcn-config.md"  "rappel des Ingress Rules VCN"

echo "-- mode simulation (dry-run) --"
TMP="$(mktemp -d)"
printf 'fake\n' > "${TMP}/fake.key"
out="$(bash setup.sh --ip 192.0.2.10 --key "${TMP}/fake.key" --type vanilla \
      --mc-version 1.20.1 --ram 4 --players 5 --crafty false --modpack none \
      --yes --dry-run 2>&1)" && rc=0 || rc=1
assert_equals "0" "$rc" "dry-run sort avec code 0"
assert_contains "$out" "192.0.2.10" "dry-run affiche l'IP"
assert_contains "$out" "vanilla"    "dry-run affiche le type de serveur"
assert_contains "$out" "SIMULATION" "dry-run se présente comme simulation"
if [[ -f "${REPO_ROOT}/.server.conf" ]]; then
    t_fail "dry-run ne doit pas écrire .server.conf"
else
    t_pass "dry-run n'écrit pas .server.conf"
fi

echo "-- validations en mode non interactif --"
bash setup.sh --ip 999.1.1.1 --key "${TMP}/fake.key" --type vanilla \
     --mc-version 1.20.1 --ram 4 --players 5 --crafty false --modpack none \
     --yes --dry-run >/dev/null 2>&1 && rc=0 || rc=1
assert_equals "1" "$rc" "IP invalide rejetée"
bash setup.sh --ip 192.0.2.10 --key "${TMP}/fake.key" --type vanilla \
     --mc-version 1.20.1 --ram 12 --players 5 --crafty false --modpack none \
     --yes --dry-run >/dev/null 2>&1 && rc=0 || rc=1
assert_equals "1" "$rc" "RAM > 8 rejetée"

rm -rf "$TMP"
finish_tests
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL — `setup.sh` absent.

- [ ] **Step 3: Create `setup.sh`**

```bash
#!/usr/bin/env bash
# =============================================================================
# setup.sh — Orchestrateur LOCAL du déploiement (machine de l'utilisateur).
#
# Transfère deploy/, configs/, modpacks/ et utils/rcon_client.py vers la VM
# dans /tmp/setup/, puis exécute deploy/remote_provision.sh via SSH.
# Aucune commande de provisioning n'est exécutée localement.
#
# Usage interactif :  ./setup.sh
# Usage scripté   :  ./setup.sh --ip IP --key CHEMIN --type forge ... --yes [--dry-run]
# =============================================================================
set -euo pipefail

VERSION="3.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

STAGING="/tmp/setup"
CONF_FILE="${SCRIPT_DIR}/.server.conf"

# --- Configuration (remplie par les questions ou les options) ---
ORACLE_IP="" SSH_KEY_PATH="" SSH_USER="ubuntu"
SERVER_TYPE="vanilla" MC_VERSION="1.20.1" RAM_GB="8"
PLAYERS="10" INSTALL_CRAFTY="true" MODPACK="none" PACK_URL="-"
ASSUME_YES="false" DRY_RUN="false"

usage() {
    cat <<EOF
Usage : setup.sh [options]
  --ip <adresse>        IP publique de la VM Oracle
  --key <chemin>        Clé privée SSH (.key / .pem)
  --type <type>         vanilla | forge | fabric | modpack
  --mc-version <ver>    Version Minecraft (défaut : 1.20.1)
  --ram <Go>            RAM JVM, 2 à 8 (défaut : 8)
  --players <n>         Joueurs maximum (défaut : 10)
  --crafty <bool>       Installer le panel Crafty (défaut : true)
  --modpack <id>        Identifiant du modpack (better-minecraft, atm9-light, vanilla-plus)
  --pack-url <url>      URL directe du server pack (requis si --type modpack)
  --yes                 Non interactif (nécessite toutes les options ci-dessus)
  --dry-run             Simulation : affiche les actions sans rien exécuter
  -h, --help            Cette aide
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ip)          ORACLE_IP="$2"; shift 2 ;;
            --key)         SSH_KEY_PATH="$2"; shift 2 ;;
            --type)        SERVER_TYPE="$2"; shift 2 ;;
            --mc-version)  MC_VERSION="$2"; shift 2 ;;
            --ram)         RAM_GB="$2"; shift 2 ;;
            --players)     PLAYERS="$2"; shift 2 ;;
            --crafty)      INSTALL_CRAFTY="${2,,}"; shift 2 ;;
            --modpack)     MODPACK="$2"; shift 2 ;;
            --pack-url)    PACK_URL="$2"; shift 2 ;;
            --yes)         ASSUME_YES="true"; shift ;;
            --dry-run)     DRY_RUN="true"; shift ;;
            -h|--help)     usage; exit 0 ;;
            *) die "Option inconnue : $1 (voir --help)" ;;
        esac
    done
}

check_local_prerequisites() {
    case "$(uname -s)" in
        Linux|Darwin|MINGW*|MSYS*|CYGWIN*)
            info "Système détecté : $(uname -s)" ;;
        *) die "OS non supporté : $(uname -s). Utilisez Linux, macOS ou Git Bash (Windows)." ;;
    esac
    local tool
    for tool in ssh scp curl; do
        command -v "$tool" >/dev/null 2>&1 || die "Outil requis manquant : $tool"
    done
}

show_preflight_checklist() {
    echo
    info "AVANT DE CONTINUER, vérifiez que vous avez :"
    echo "  1. Un compte Oracle Cloud actif        (https://cloud.oracle.com)"
    echo "  2. Une VM Ubuntu ARM créée : image Ubuntu 22.04+, shape Ampere A1"
    echo "     avec 2 OCPU / 12 Go de RAM (quota Always Free actuel)"
    echo "  3. L'IP publique de la VM (console → Compute → Instances)"
    echo "  4. Votre clé SSH privée téléchargée lors de la création de la VM"
    echo
    if ! ask_yes_no "Tout est prêt ?" "y"; then
        echo
        info "Consultez le guide pas à pas : docs/guide-debutant-fr.md"
        exit 0
    fi
}

ask_ip() {
    while true; do
        read -r -p "→ IP publique de votre VM Oracle : " ORACLE_IP
        ORACLE_IP="${ORACLE_IP// /}"
        if is_valid_ipv4 "$ORACLE_IP"; then
            success "IP valide : $ORACLE_IP"
            break
        fi
        warn "Format invalide. Exemple attendu : 129.213.56.123"
    done
}

ask_ssh_key() {
    echo
    info "Clé SSH privée téléchargée depuis la console Oracle"
    info "(fichier du type ssh-key-2026-XX-XX.key ou *.pem, souvent dans Téléchargements)."
    local default_found=""
    local candidate
    for candidate in "$HOME"/Downloads/ssh-key-*.key "$HOME"/Downloads/*.pem \
                     "$HOME"/.ssh/id_*.pem "$HOME"/.ssh/id_rsa; do
        if [[ -f "$candidate" ]]; then
            if ask_yes_no "Clé trouvée : ${candidate} — l'utiliser ?" "y"; then
                SSH_KEY_PATH="$candidate"
                default_found="yes"
                break
            fi
        fi
    done
    if [[ -z "$default_found" ]]; then
        while true; do
            read -r -e -p "→ Chemin de la clé privée SSH : " SSH_KEY_PATH
            if [[ -f "$SSH_KEY_PATH" ]]; then
                break
            fi
            warn "Fichier introuvable : ${SSH_KEY_PATH}"
        done
    fi
    chmod 600 "$SSH_KEY_PATH" 2>/dev/null || warn "Impossible d'ajuster les permissions de la clé (ignoré sous Windows)."
    success "Clé SSH : $SSH_KEY_PATH"
}

list_modpack_ids() {
    grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' "${SCRIPT_DIR}/modpacks/manifest.json" \
        | sed 's/.*"\([^"]*\)"$/\1/'
}

show_modpack_info() { # id
    local f="${SCRIPT_DIR}/modpacks/$1.json"
    [[ -f "$f" ]] || return 0
    sed -n 's/.*"nom"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/  Nom : \1/p; s/.*"description"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/  Description : \1/p; s/.*"ram_recommandee_go"[[:space:]]*:[[:space:]]*\([0-9]*\).*/  RAM recommandée : \1 Go/p' "$f"
    sed -n 's/.*"page_curseforge"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/  Page : \1/p' "$f"
}

ask_server_config() {
    echo
    ask_choice "Quel type de serveur Minecraft ?" \
        "Vanilla (pur, sans mods)" \
        "Forge (mods classiques — recommandé pour 1.20.1)" \
        "Fabric (mods modernes, léger)" \
        "Modpack préconfiguré (server pack CurseForge)"
    case "$SELECTED_CHOICE" in
        1) SERVER_TYPE="vanilla" ;;
        2) SERVER_TYPE="forge" ;;
        3) SERVER_TYPE="fabric" ;;
        4) SERVER_TYPE="modpack" ;;
    esac

    while true; do
        read -r -p "Version Minecraft [1.20.1] : " MC_VERSION
        MC_VERSION="${MC_VERSION:-1.20.1}"
        is_valid_mc_version "$MC_VERSION" && break
        warn "Version invalide (formats attendus : 1.20.1, 1.21...)"
    done
    success "Version Minecraft : $MC_VERSION"

    RAM_GB="$(ask_number "RAM pour le serveur en Go (max 8 sur l'Always Free)" 8 2 8)"
    success "RAM allouée à la JVM : ${RAM_GB} Go"

    PLAYERS="$(ask_number "Nombre maximum de joueurs" 10 1 100)"

    if ask_yes_no "Installer Crafty Controller (panel web d'administration) ?" "y"; then
        INSTALL_CRAFTY="true"
        info "Panel accessible après installation sur https://<IP>:8443"
    else
        INSTALL_CRAFTY="false"
        info "Gestion via SSH et les scripts utils/ uniquement."
    fi

    if [[ "$SERVER_TYPE" == "modpack" ]]; then
        echo
        info "Modpacks disponibles :"
        local ids id
        ids="$(list_modpack_ids)"
        local i=1
        for id in $ids; do
            echo "  ${i}) ${id}"
            show_modpack_info "$id"
            i=$((i + 1))
        done
        while true; do
            read -r -p "→ Identifiant du modpack : " MODPACK
            if modpack_id_exists "$MODPACK" "${SCRIPT_DIR}/modpacks/manifest.json"; then
                break
            fi
            warn "Modpack inconnu : $MODPACK"
        done
        echo
        info "Collez l'URL DIRECTE du fichier « Server Pack » ( CurseForge →"
        info "  onglet Files → version ${MC_VERSION} → Additional Files → Server Pack )."
        info "Détails : docs/guide-debutant-fr.md (section modpacks)."
        while true; do
            read -r -p "→ URL du server pack (.zip) : " PACK_URL
            [[ "$PACK_URL" == http* ]] && break
            warn "URL invalide (doit commencer par http)"
        done
    fi
}

validate_non_interactive_config() {
    is_valid_ipv4 "$ORACLE_IP" || die "IP invalide : $ORACLE_IP"
    case "$SERVER_TYPE" in
        vanilla|forge|fabric|modpack) ;;
        *) die "Type de serveur invalide : $SERVER_TYPE" ;;
    esac
    is_valid_mc_version "$MC_VERSION" || die "Version Minecraft invalide : $MC_VERSION"
    is_valid_ram "$RAM_GB" \
        || die "RAM invalide : ${RAM_GB} Go (entre 2 et 8 — quota Always Free 12 Go)"
    [[ -f "$SSH_KEY_PATH" ]] || die "Clé SSH introuvable : $SSH_KEY_PATH"
    [[ "$INSTALL_CRAFTY" == "true" || "$INSTALL_CRAFTY" == "false" ]] || die "--crafty doit valoir true ou false"
    if [[ "$SERVER_TYPE" == "modpack" ]]; then
        modpack_id_exists "$MODPACK" "${SCRIPT_DIR}/modpacks/manifest.json" || die "Modpack inconnu : $MODPACK"
        [[ "$PACK_URL" == http* ]] || die "--pack-url requis pour un modpack"
    fi
}

confirm_summary() {
    echo
    echo "════════════════════════════════════════════════════════"
    echo "                 RÉSUMÉ DE CONFIGURATION"
    echo "════════════════════════════════════════════════════════"
    echo "  IP Oracle      : $ORACLE_IP"
    echo "  Type serveur   : $SERVER_TYPE"
    [[ "$SERVER_TYPE" == "modpack" ]] && echo "  Modpack        : $MODPACK"
    echo "  Version MC     : $MC_VERSION"
    echo "  RAM JVM        : ${RAM_GB} Go"
    echo "  Joueurs max    : $PLAYERS"
    echo "  Panel Crafty   : $INSTALL_CRAFTY"
    echo "════════════════════════════════════════════════════════"
    echo
    if [[ "$ASSUME_YES" != "true" ]]; then
        ask_yes_no "Confirmer et lancer l'installation ?" "y" || { info "Installation annulée."; exit 0; }
    fi
}

setup_ssh() {
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 \
        "${SSH_USER}@${ORACLE_IP}" "$@"
}

test_ssh_connectivity() {
    info "Test de connexion SSH vers ${SSH_USER}@${ORACLE_IP} ..."
    if setup_ssh "true" 2>/dev/null; then
        success "Connexion SSH OK."
    else
        die "Connexion SSH impossible. Vérifiez l'IP, la clé et que la VM est Running (voir docs/troubleshooting.md)."
    fi
}

transfer_files() {
    info "Transfert des fichiers vers la VM (${STAGING}) ..."
    setup_ssh "sudo rm -rf ${STAGING} && mkdir -p ${STAGING}/utils"
    scp -q -r -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new \
        "${SCRIPT_DIR}/deploy" "${SCRIPT_DIR}/configs" "${SCRIPT_DIR}/modpacks" \
        "${SSH_USER}@${ORACLE_IP}:${STAGING}/"
    scp -q -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new \
        "${SCRIPT_DIR}/utils/rcon_client.py" "${SSH_USER}@${ORACLE_IP}:${STAGING}/utils/"
    success "Fichiers transférés."
}

execute_remote_provision() {
    info "Exécution du provisionnement sur la VM (5 à 10 minutes) ..."
    setup_ssh "sudo bash ${STAGING}/deploy/remote_provision.sh \
        --ip '${ORACLE_IP}' --server-type '${SERVER_TYPE}' --mc-version '${MC_VERSION}' \
        --ram '${RAM_GB}' --players '${PLAYERS}' --crafty '${INSTALL_CRAFTY}' \
        --modpack '${MODPACK}' --pack-url '${PACK_URL}'"
}

save_server_conf() {
    cat > "$CONF_FILE" <<EOF
# Généré par setup.sh — configuration locale (ne pas versionner)
ORACLE_IP=${ORACLE_IP}
SSH_KEY_PATH=${SSH_KEY_PATH}
SSH_USER=${SSH_USER}
SERVER_TYPE=${SERVER_TYPE}
MC_VERSION=${MC_VERSION}
RAM_GB=${RAM_GB}
MODPACK=${MODPACK}
EOF
    chmod 600 "$CONF_FILE" 2>/dev/null || true
    success "Configuration locale sauvegardée dans .server.conf"
}

final_banner() {
    echo
    success "INSTALLATION TERMINÉE !"
    echo
    echo "  Prochaines étapes :"
    echo "   1. Ouvrez les Ingress Rules du VCN Oracle si ce n'est pas fait :"
    echo "      docs/oci-vcn-config.md  (TCP+UDP 25565, TCP 8443)"
    echo "   2. Dans Minecraft Java Edition : Multijoueur → Ajouter un serveur"
    echo "      Adresse : ${ORACLE_IP}:25565"
    if [[ "$SERVER_TYPE" == "modpack" || "$SERVER_TYPE" == "forge" || "$SERVER_TYPE" == "fabric" ]]; then
        echo "   3. Chaque joueur doit installer les MÊMES mods côté client"
        echo "      (CurseForge App → même modpack/version)."
    fi
    echo
    echo "  Sauvegardes : ./utils/backup.sh   —  Surveillance : ./utils/monitor.sh"
    echo "  Dépannage   : docs/troubleshooting.md"
}

main() {
    parse_args "$@"
    echo
    echo "=============================================================="
    echo "   Oracle Cloud Minecraft — Auto Setup v${VERSION}"
    echo "   Forge / Fabric / Vanilla / Modpacks — Always Free (ARM)"
    echo "=============================================================="

    check_local_prerequisites

    if [[ "$ASSUME_YES" == "true" ]]; then
        validate_non_interactive_config
    else
        show_preflight_checklist
        ask_ip
        ask_ssh_key
        ask_server_config
        validate_non_interactive_config
    fi

    confirm_summary

    if [[ "$DRY_RUN" == "true" ]]; then
        echo
        warn "MODE SIMULATION (--dry-run) : aucune action distante ne sera exécutée."
        echo "  Commandes qui seraient exécutées :"
        echo "    scp -r deploy configs modpacks + utils/rcon_client.py → ${SSH_USER}@${ORACLE_IP}:${STAGING}/"
        echo "    ssh ${SSH_USER}@${ORACLE_IP} 'sudo bash ${STAGING}/deploy/remote_provision.sh --ip ${ORACLE_IP} --server-type ${SERVER_TYPE} --mc-version ${MC_VERSION} --ram ${RAM_GB} --players ${PLAYERS} --crafty ${INSTALL_CRAFTY} --modpack ${MODPACK} --pack-url ${PACK_URL}'"
        exit 0
    fi

    test_ssh_connectivity
    transfer_files
    execute_remote_provision
    save_server_conf
    final_banner
}

main "$@"
```

Note: `${2,,}` (bash 4 lowercase expansion) works in Git Bash (bash ≥ 4.4) and on Ubuntu. `utils/rcon_client.py` does not exist yet (Task 11) — that is fine until real deployment; the test only runs `--dry-run`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/run_tests.sh`
Expected: `SUITE : SUCCÈS`.

- [ ] **Step 5: Commit**

```bash
git add setup.sh tests/test_setup.sh
git commit -m "feat: orchestrateur local setup.sh (interactif, scripté, dry-run)"
```

---

### Task 10: `deploy/oci_ingress_setup.sh` — Ingress Rules VCN via OCI CLI

**Files:**
- Create: `deploy/oci_ingress_setup.sh`
- Modify: `tests/test_deploy_scripts.sh` (append before `finish_tests`)

**Interfaces:**
- Consumes: OCI CLI (`oci`) and `jq`, both on the *user's local machine* if they choose this path.
- Produces: optional automation matching `docs/oci-vcn-config.md` (Task 18). Usage: `bash deploy/oci_ingress_setup.sh --security-list-ocid <ocid1.securitylist...>`.

- [ ] **Step 1: Append the failing test**

Append to `tests/test_deploy_scripts.sh`, before `finish_tests`:

```bash
echo "-- oci_ingress_setup.sh --"
assert_file_exists deploy/oci_ingress_setup.sh "oci_ingress_setup.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n deploy/oci_ingress_setup.sh
assert_file_contains deploy/oci_ingress_setup.sh "oci network security-list update" "mise à jour de la security list"
assert_file_contains deploy/oci_ingress_setup.sh "25565"   "port Minecraft"
assert_file_contains deploy/oci_ingress_setup.sh "8443"    "port Crafty"
assert_file_contains deploy/oci_ingress_setup.sh "0.0.0.0/0" "source ouverte"
assert_file_contains deploy/oci_ingress_setup.sh "oracle-minecraft-setup" "descriptions identifiant les règles"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL on new assertions.

- [ ] **Step 3: Create `deploy/oci_ingress_setup.sh`**

```bash
#!/usr/bin/env bash
# =============================================================================
# oci_ingress_setup.sh — Ajoute les Ingress Rules VCN via OCI CLI (OPTIONNEL).
# Alternative scriptée au guide manuel docs/oci-vcn-config.md.
#
# Prérequis (machine locale) :
#   pip install oci-cli && oci setup config
#   sudo apt install jq   (ou brew install jq)
#
# Usage :
#   bash deploy/oci_ingress_setup.sh --security-list-ocid ocid1.securitylist.oc1..
#
# Règles ajoutées (idempotent, par description) :
#   TCP 25565, UDP 25565, TCP 8443 — source 0.0.0.0/0
# =============================================================================
set -euo pipefail

SL_ID=""
usage() { sed -n 's/^# \{0,1\}//p' "$0" | sed -n '3,18p'; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --security-list-ocid) SL_ID="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Argument inconnu : $1" >&2; exit 1 ;;
    esac
done
[[ -n "$SL_ID" ]] || { usage; exit 1; }
[[ "$SL_ID" == ocid1.securitylist.* ]] || { echo "OCID de security list invalide." >&2; exit 1; }

command -v oci >/dev/null 2>&1 || { echo "OCI CLI absent : pip install oci-cli" >&2; exit 1; }
command -v jq  >/dev/null 2>&1 || { echo "jq absent (apt install jq)" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[1/4] Lecture de la security list..."
oci network security-list get --security-list-id "$SL_ID" > "${TMP}/sl.json"

echo "[2/4] Construction des règles à ajouter..."
oci network security-list get --security-list-id "$SL_ID" \
    --query 'data."ingress-security-rules"' --raw-output > "${TMP}/existing.json"

make_rule() { # protocole_num port description
    jq -n --arg src "0.0.0.0/0" --arg proto "$1" --arg port "$2" --arg desc "$3" \
        '{description: $desc, protocol: $proto, isStateless: false, source: $src,
          sourceType: "CIDR", tcpOptions: (if $proto == "6" then
            {destinationPortRange: {max: ($port | tonumber), min: ($port | tonumber)}} else null end),
          udpOptions: (if $proto == "17" then
            {destinationPortRange: {max: ($port | tonumber), min: ($port | tonumber)}} else null end)}'
}

DESC_TCP="oracle-minecraft-setup TCP 25565"
DESC_UDP="oracle-minecraft-setup UDP 25565"
DESC_CRAFTY="oracle-minecraft-setup TCP 8443"

EXISTING_COUNT="$(jq --arg d "$DESC_TCP" '[.[] | select(.description == $d)] | length' "${TMP}/existing.json")"
if [[ "$EXISTING_COUNT" != "0" ]]; then
    echo "[2/4] Règles déjà présentes (description identique) — rien à faire."
    exit 0
fi

{
    make_rule 6  25565 "$DESC_TCP"
    make_rule 17 25565 "$DESC_UDP"
    make_rule 6  8443  "$DESC_CRAFTY"
} > "${TMP}/new.json"

echo "[3/4] Fusion des règles existantes et nouvelles..."
jq -s '.[0] + .[1]' "${TMP}/existing.json" "${TMP}/new.json" > "${TMP}/merged.json"

echo "[4/4] Mise à jour de la security list..."
oci network security-list update --security-list-id "$SL_ID" \
    --ingress-security-rules "file://${TMP}/merged.json" --force >/dev/null

echo "Terminé : Ingress Rules TCP/UDP 25565 et TCP 8443 ajoutées (0.0.0.0/0)."
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/run_tests.sh`
Expected: `SUITE : SUCCÈS`.

- [ ] **Step 5: Commit**

```bash
git add deploy/oci_ingress_setup.sh tests/test_deploy_scripts.sh
git commit -m "feat: automatisation optionnelle des Ingress Rules VCN (OCI CLI)"
```

---

### Task 11: `utils/rcon_client.py` — client RCON minimal

**Files:**
- Create: `utils/rcon_client.py`
- Create: `tests/test_rcon.py`

**Interfaces:**
- Consumes: nothing (stdlib only).
- Produces: `build_packet(request_id, ptype, payload) -> bytes`, `read_packet(sock) -> (id, type, str)`, `run(host, port, password, command)`; CLI `rcon_client.py <hote> <port> <mot_de_passe> <commande>`. Deployed on the VM at `/opt/minecraft/bin/rcon_client.py` and used by `utils/backup.sh`, `utils/monitor.sh`, `security/whitelist_manager.sh` via SSH.

- [ ] **Step 1: Write the failing test**

`tests/test_rcon.py`:

```python
#!/usr/bin/env python3
"""Tests du client RCON (exécutés si python3 est disponible)."""
import struct
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "utils"))
import rcon_client  # noqa: E402

failures = []


def check(name, cond):
    if cond:
        print(f"  OK    {name}")
    else:
        failures.append(name)
        print(f"  ÉCHEC {name}", file=sys.stderr)


p = rcon_client.build_packet(1, 3, "secret")
check("longueur totale = 20", len(p) == 20)
check("champ length = 16", struct.unpack("<i", p[:4])[0] == 16)
check("champ id = 1", struct.unpack("<i", p[4:8])[0] == 1)
check("champ type = 3", struct.unpack("<i", p[8:12])[0] == 3)
check("charge utile", p[12:18] == b"secret")
check("double octet nul final", p[18:20] == b"\x00\x00")

p2 = rcon_client.build_packet(7, 2, "list")
check("paquet 'list' : length = 10", struct.unpack("<i", p2[:4])[0] == 10)

print(f"\nRésultats : {6 + 2 - len(failures) - 0} OK, {len(failures)} échec(s)")
sys.exit(1 if failures else 0)
```

- [ ] **Step 2: Verify the test harness runs and fails**

Add a runner shim so `tests/run_tests.sh` executes it only when python3 exists — append to `tests/run_tests.sh` just before the final summary block:

```bash
# Test python optionnel (client RCON)
if command -v python3 >/dev/null 2>&1; then
    echo "==> tests/test_rcon.py"
    if ! python3 tests/test_rcon.py; then
        overall=1
        echo "    [ÉCHEC] tests/test_rcon.py"
    fi
else
    echo "==> tests/test_rcon.py (python3 absent — sauté)"
fi
```

Run: `bash tests/run_tests.sh`
Expected: FAIL — `No module named 'rcon_client'` (or SKIP if python3 absent, in which case verify the file manually with `python -m py_compile` if any python exists; on this dev machine treat SKIP as acceptable and rely on Task 21's structure checks).

- [ ] **Step 3: Create `utils/rcon_client.py`**

```python
#!/usr/bin/env python3
"""Client RCON minimal (protocole Source RCON) pour Minecraft.

Usage : rcon_client.py <hote> <port> <mot_de_passe> <commande>

Déployé sur la VM dans /opt/minecraft/bin/ par remote_provision.sh.
Le serveur Minecraft doit avoir enable-rcon=true (configuré par le setup).
Limite connue : les réponses de plus de 4096 octets sont tronquées par le
protocole lui-même — suffisant pour save-off/list/whitelist...
"""
import socket
import struct
import sys

SERVERDATA_AUTH = 3
SERVERDATA_AUTH_RESPONSE = 2
SERVERDATA_EXECCOMMAND = 2
SERVERDATA_RESPONSE_VALUE = 0
TIMEOUT = 10


def build_packet(request_id, ptype, payload):
    """Construit un paquet RCON : [longueur][id][type][charge][nul][nul]."""
    body = struct.pack("<ii", request_id, ptype) + payload.encode("utf-8") + b"\x00\x00"
    return struct.pack("<i", len(body)) + body


def recv_exact(sock, size):
    """Lit exactement `size` octets sur le socket."""
    data = b""
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise ConnectionError("Connexion RCON fermée par le serveur")
        data += chunk
    return data


def read_packet(sock):
    """Lit un paquet RCON et retourne (id, type, charge_utile)."""
    (length,) = struct.unpack("<i", recv_exact(sock, 4))
    body = recv_exact(sock, length)
    request_id, ptype = struct.unpack("<ii", body[:8])
    return request_id, ptype, body[8:-2].decode("utf-8", errors="replace")


def run(host, port, password, command):
    """Se connecte, s'authentifie puis exécute une commande et affiche la réponse."""
    with socket.create_connection((host, port), timeout=TIMEOUT) as sock:
        sock.settimeout(TIMEOUT)
        sock.sendall(build_packet(1, SERVERDATA_AUTH, password))
        while True:
            rid, rtype, _ = read_packet(sock)
            if rtype == SERVERDATA_AUTH_RESPONSE:
                if rid == -1:
                    print("Authentification RCON échouée (mot de passe).", file=sys.stderr)
                    sys.exit(1)
                break
        sock.sendall(build_packet(1, SERVERDATA_EXECCOMMAND, command))
        _rid, rtype, payload = read_packet(sock)
        if rtype == SERVERDATA_RESPONSE_VALUE:
            print(payload)


def main(argv):
    if len(argv) != 5:
        print("Usage : rcon_client.py <hote> <port> <mot_de_passe> <commande>", file=sys.stderr)
        return 2
    try:
        run(argv[1], int(argv[2]), argv[3], argv[4])
    except (OSError, ConnectionError) as exc:
        print(f"Erreur RCON : {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/run_tests.sh`
Expected: `SUITE : SUCCÈS` (rcon packet assertions OK, or SKIP without python3).

- [ ] **Step 5: Commit**

```bash
git add utils/rcon_client.py tests/test_rcon.py tests/run_tests.sh
git commit -m "feat: client RCON minimal (python3) pour l'administration à chaud"
```

---

### Task 12: `utils/backup.sh` + `utils/restore.sh`

**Files:**
- Create: `utils/backup.sh`
- Create: `utils/restore.sh`
- Create: `tests/test_utils_scripts.sh`

**Interfaces:**
- Consumes: `scripts/lib.sh` (`load_server_conf`, `run_ssh`, `ask_yes_no`, `die`...), `.server.conf` (Task 9), `/opt/minecraft/bin/rcon_client.py` + `/opt/minecraft/server/.rcon-credentials` on the VM (Task 8).
- Produces: archives `/opt/minecraft/backups/backup-YYYYMMDD-HHMMSS.tar.gz` on the VM (format consumed by `restore.sh`), rotation keeping `KEEP` (default 7, env override). `backup.sh` exit 0 on success.

- [ ] **Step 1: Write the failing test**

`tests/test_utils_scripts.sh`:

```bash
#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"

echo "-- backup.sh --"
assert_file_exists utils/backup.sh "backup.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n utils/backup.sh
assert_file_contains utils/backup.sh "save-off"        "sauvegarde à chaud (save-off)"
assert_file_contains utils/backup.sh "save-all flush"  "flush des chunks avant archive"
assert_file_contains utils/backup.sh "save-on"         "réactivation des sauvegardes"
assert_file_contains utils/backup.sh "tar czf"         "archivage tar.gz"
assert_file_contains utils/backup.sh "load_server_conf" "utilise .server.conf"
assert_file_contains utils/backup.sh "systemctl stop minecraft" "repli à froid si RCON absent"

echo "-- restore.sh --"
assert_file_exists utils/restore.sh "restore.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n utils/restore.sh
assert_file_contains utils/restore.sh "tar xzf"        "extraction"
assert_file_contains utils/restore.sh "systemctl stop minecraft" "arrêt avant restauration"
assert_file_contains utils/restore.sh "systemctl start minecraft" "redémarrage après restauration"
assert_file_contains utils/restore.sh "is_valid_backup_name"      "validation du nom d'archive"

finish_tests
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL — scripts absent.

- [ ] **Step 3: Create `utils/backup.sh`**

```bash
#!/usr/bin/env bash
# =============================================================================
# backup.sh — Sauvegarde du serveur Minecraft (exécuté LOCALEMENT, via SSH).
# Sauvegarde à chaud via RCON (save-off / save-all flush / save-on) ;
# repli à froid (arrêt/relance du service) si RCON n'est pas disponible.
# Archive : /opt/minecraft/backups/backup-YYYYMMDD-HHMMSS.tar.gz
# Rotation : garde les KEEP dernières archives (défaut 7) — KEEP=3 ./utils/backup.sh
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

KEEP="${KEEP:-7}"
load_server_conf "${SCRIPT_DIR}/.server.conf"

run_ssh "bash -s -- ${KEEP}" <<'REMOTE'
set -euo pipefail
KEEP="$1"
SERVER_DIR=/opt/minecraft/server
BACKUP_DIR=/opt/minecraft/backups
mkdir -p "$BACKUP_DIR"

HOT=0
if [[ -f "${SERVER_DIR}/.rcon-credentials" ]]; then
    # shellcheck disable=SC1091
    . "${SERVER_DIR}/.rcon-credentials"
    rcon() { python3 /opt/minecraft/bin/rcon_client.py 127.0.0.1 "${RCON_PORT}" "${RCON_PASSWORD}" "$1"; }
    if rcon "save-off" >/dev/null 2>&1; then
        echo "[backup] Mode CHAUD : écriture du monde suspendue (save-off)."
        rcon "save-all flush" >/dev/null 2>&1 || true
        sleep 3
        HOT=1
    fi
fi
if [[ $HOT -eq 0 ]]; then
    echo "[backup] RCON indisponible : arrêt du serveur (mode FROID)."
    systemctl stop minecraft
fi

STAMP="backup-$(date +%Y%m%d-%H%M%S).tar.gz"
ITEMS=()
cd "$SERVER_DIR"
for p in world world_nether world_the_end mods config defaultconfigs \
         serverconfig kubejs server.properties whitelist.json user_jvm_args.txt; do
    [[ -e "$p" ]] && ITEMS+=("$p")
done
tar czf "${BACKUP_DIR}/${STAMP}" "${ITEMS[@]}"
echo "[backup] Archive créée : ${BACKUP_DIR}/${STAMP}"

if [[ $HOT -eq 1 ]]; then
    rcon "save-on" >/dev/null 2>&1 || true
    echo "[backup] Écriture du monde réactivée (save-on)."
else
    systemctl start minecraft
    echo "[backup] Serveur redémarré."
fi

# Rotation : ne conserver que les KEEP plus récentes
cd "$BACKUP_DIR"
ls -1t backup-*.tar.gz 2>/dev/null | tail -n +"$((KEEP + 1))" | while IFS= read -r old; do
    rm -f -- "$old"
    echo "[backup] Rotation : ${old} supprimée."
done
echo "[backup] Terminé. Archives conservées : $(ls -1 backup-*.tar.gz 2>/dev/null | wc -l)"
REMOTE

success "Sauvegarde terminée sur ${ORACLE_IP}."
```

- [ ] **Step 4: Create `utils/restore.sh`**

```bash
#!/usr/bin/env bash
# =============================================================================
# restore.sh — Restaure une archive créée par backup.sh (exécuté LOCALEMENT).
# Liste les archives présentes sur la VM, demande laquelle restaurer,
# arrête le serveur, extrait, redémarre et vérifie le port 25565.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

load_server_conf "${SCRIPT_DIR}/.server.conf"

echo "[restore] Archives disponibles sur la VM :"
LISTING="$(run_ssh "ls -1t /opt/minecraft/backups/backup-*.tar.gz 2>/dev/null")" \
    || die "Aucune archive trouvée dans /opt/minecraft/backups/."
mapfile -t ARCHIVES <<< "$LISTING"

i=1
for a in "${ARCHIVES[@]}"; do
    printf '  %d) %s\n' "$i" "$(basename "$a")"
    i=$((i + 1))
done

while true; do
    read -r -p "→ Numéro de l'archive à restaurer : " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( 10#$choice >= 1 && 10#$choice <= ${#ARCHIVES[@]} )); then
        break
    fi
    warn "Choix invalide."
done

ARCHIVE_NAME="$(basename "${ARCHIVES[$((10#$choice - 1))]}")"
is_valid_backup_name "$ARCHIVE_NAME" || die "Nom d'archive invalide : $ARCHIVE_NAME"

warn "Le monde actuel sera REMPLACÉ par le contenu de ${ARCHIVE_NAME}."
ask_yes_no "Confirmer la restauration ?" "n" || { info "Restauration annulée."; exit 0; }

run_ssh "bash -s -- '${ARCHIVE_NAME}'" <<'REMOTE'
set -euo pipefail
NAME="$1"
systemctl stop minecraft
cd /opt/minecraft/server
tar xzf "/opt/minecraft/backups/${NAME}"
chown -R minecraft:minecraft /opt/minecraft/server
systemctl start minecraft
REMOTE

info "Attente du redémarrage (jusqu'à 2 minutes)..."
sleep 10
if run_ssh "ss -tln | grep -q ':25565 '"; then
    success "Serveur restauré et en écoute sur ${ORACLE_IP}:25565."
else
    warn "Le port 25565 n'est pas encore en écoute — vérifiez : ssh ${SSH_USER}@${ORACLE_IP} 'journalctl -u minecraft -n 30'"
fi
```

- [ ] **Step 5: Run the tests to verify they pass, then commit**

Run: `bash tests/run_tests.sh`
Expected: `SUITE : SUCCÈS`.

```bash
git add utils/backup.sh utils/restore.sh tests/test_utils_scripts.sh
git commit -m "feat: sauvegarde à chaud avec rotation + restauration"
```

---

### Task 13: `utils/monitor.sh`

**Files:**
- Create: `utils/monitor.sh`
- Modify: `tests/test_utils_scripts.sh` (append before `finish_tests`)

**Interfaces:**
- Consumes: `scripts/lib.sh` (`load_server_conf`, `run_ssh`), `.server.conf`, RCON on the VM.
- Produces: one-shot status report (service state, java process CPU/RAM, memory, disk, player list, Forge TPS when available). Tip documented in header: `watch -n 5 ./utils/monitor.sh`.

- [ ] **Step 1: Append the failing test**

Append to `tests/test_utils_scripts.sh`, before `finish_tests`:

```bash
echo "-- monitor.sh --"
assert_file_exists utils/monitor.sh "monitor.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n utils/monitor.sh
assert_file_contains utils/monitor.sh "load_server_conf"   "utilise .server.conf"
assert_file_contains utils/monitor.sh "systemctl is-active minecraft" "état du service"
assert_file_contains utils/monitor.sh "free -h"            "mémoire système"
assert_file_contains utils/monitor.sh "df -h"              "espace disque"
assert_file_contains utils/monitor.sh '"list"'              "joueurs connectés via RCON"
assert_file_contains utils/monitor.sh '"forge tps"'         "TPS (Forge)"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL on new assertions.

- [ ] **Step 3: Create `utils/monitor.sh`**

```bash
#!/usr/bin/env bash
# =============================================================================
# monitor.sh — État du serveur en un coup d'œil (exécuté LOCALEMENT, via SSH).
# Affiche : service, processus java (CPU/RAM/uptime), mémoire, disque,
# joueurs connectés (RCON) et TPS (Forge uniquement).
# Astuce temps réel : watch -n 5 ./utils/monitor.sh
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

load_server_conf "${SCRIPT_DIR}/.server.conf"

run_ssh "bash -s" <<'REMOTE'
set -euo pipefail
SERVER_DIR=/opt/minecraft/server

echo "===== SERVICE ====="
systemctl is-active minecraft
systemctl show minecraft -p ActiveEnterTimestamp --value

PID="$(systemctl show minecraft -p MainPID --value)"
if [[ "$PID" != "0" && -n "$PID" ]]; then
    echo
    echo "===== PROCESSUS JAVA ====="
    ps -o pid,pcpu,pmem,etime,comm -p "$PID"
fi

echo
echo "===== MÉMOIRE SYSTÈME ====="
free -h

echo
echo "===== DISQUE (/opt) ====="
df -h /opt

if [[ -f "${SERVER_DIR}/.rcon-credentials" ]]; then
    # shellcheck disable=SC1091
    . "${SERVER_DIR}/.rcon-credentials"
    rcon() { python3 /opt/minecraft/bin/rcon_client.py 127.0.0.1 "${RCON_PORT}" "${RCON_PASSWORD}" "$1"; }
    echo
    echo "===== JOUEURS ====="
    rcon "list" 2>/dev/null || echo "RCON indisponible"
    echo
    echo "===== TPS (Forge uniquement) ====="
    rcon "forge tps" 2>/dev/null || echo "Indisponible (serveur non-Forge)"
fi
REMOTE
```

- [ ] **Step 4: Run the tests to verify they pass, then commit**

Run: `bash tests/run_tests.sh`
Expected: `SUITE : SUCCÈS`.

```bash
git add utils/monitor.sh tests/test_utils_scripts.sh
git commit -m "feat: supervision temps réel (service, ressources, joueurs, TPS)"
```

---

### Task 14: `utils/update.sh`

**Files:**
- Create: `utils/update.sh`
- Modify: `tests/test_utils_scripts.sh` (append before `finish_tests`)

**Interfaces:**
- Consumes: `scripts/lib.sh` (`load_server_conf`, `is_valid_mc_version`, `ask_choice`), `.server.conf` (`SERVER_TYPE`, `MC_VERSION`, `RAM_GB`, `MODPACK`, `ORACLE_IP`...), and `/opt/minecraft/bin/remote_provision.sh` on the VM with `--update-server` mode (Task 8).
- Produces: menu-driven update that refreshes engine binaries while preserving `world/` and configuration.

- [ ] **Step 1: Append the failing test**

Append to `tests/test_utils_scripts.sh`, before `finish_tests`:

```bash
echo "-- update.sh --"
assert_file_exists utils/update.sh "update.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n utils/update.sh
assert_file_contains utils/update.sh "load_server_conf"    "utilise .server.conf"
assert_file_contains utils/update.sh "--update-server"     "réutilise remote_provision en mode update"
assert_file_contains utils/update.sh "--forge-build"       "changement de build Forge"
assert_file_contains utils/update.sh "--pack-url"          "mise à jour de modpack via server pack"
assert_file_contains utils/update.sh "is_valid_mc_version" "validation de la version saisie"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL on new assertions.

- [ ] **Step 3: Create `utils/update.sh`**

```bash
#!/usr/bin/env bash
# =============================================================================
# update.sh — Met à jour le serveur (exécuté LOCALEMENT, via SSH).
# Réutilise /opt/minecraft/bin/remote_provision.sh --update-server :
# le monde, la configuration et l'EULA sont TOUJOURS préservés.
#
# Trois mises à jour possibles :
#   1. Moteur Vanilla/Fabric  → nouvelle version Minecraft
#   2. Forge                  → nouveau build Forge (même version MC)
#   3. Modpack                → nouveau server pack CurseForge (URL)
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

load_server_conf "${SCRIPT_DIR}/.server.conf"

echo
info "Serveur actuel : type=${SERVER_TYPE} version=${MC_VERSION} modpack=${MODPACK}"
ask_choice "Que voulez-vous mettre à jour ?" \
    "Moteur Vanilla/Fabric (changer de version Minecraft)" \
    "Forge (changer de build)" \
    "Modpack (nouveau server pack)"

COMMON_ARGS=(--ip "${ORACLE_IP}" --ram "${RAM_GB}" --server-type "${SERVER_TYPE}" --update-server)

case "$SELECTED_CHOICE" in
    1)
        while true; do
            read -r -p "→ Nouvelle version Minecraft (actuelle : ${MC_VERSION}) : " NEW_VERSION
            is_valid_mc_version "$NEW_VERSION" && break
            warn "Version invalide (ex. 1.20.1 ou 1.21)."
        done
        run_ssh "sudo bash /opt/minecraft/bin/remote_provision.sh \
            ${COMMON_ARGS[*]} --mc-version '${NEW_VERSION}' --modpack none --pack-url -"
        ;;
    2)
        while true; do
            read -r -p "→ Nouveau build Forge, format 47.2.0 (voir files.minecraftforge.net) : " NEW_BUILD
            is_valid_mc_version "$NEW_BUILD" && break
            warn "Format attendu : X.Y.Z (ex. 47.4.10)."
        done
        run_ssh "sudo bash /opt/minecraft/bin/remote_provision.sh \
            ${COMMON_ARGS[*]} --mc-version '${MC_VERSION}' --forge-build '${NEW_BUILD}' \
            --modpack none --pack-url -"
        ;;
    3)
        echo
        info "Collez l'URL DIRECTE du nouveau fichier « Server Pack » (CurseForge)."
        while true; do
            read -r -p "→ URL du server pack (.zip) : " NEW_PACK_URL
            [[ "$NEW_PACK_URL" == http* ]] && break
            warn "URL invalide (doit commencer par http)."
        done
        warn "Les fichiers du pack (mods/configs) seront remplacés ; le monde est conservé."
        ask_yes_no "Confirmer ?" "n" || { info "Mise à jour annulée."; exit 0; }
        run_ssh "sudo bash /opt/minecraft/bin/remote_provision.sh \
            ${COMMON_ARGS[*]} --mc-version '${MC_VERSION}' --server-type modpack \
            --modpack '${MODPACK}' --pack-url '${NEW_PACK_URL}'"
        ;;
esac

success "Mise à jour terminée. Vérifiez : ./utils/monitor.sh"
```

- [ ] **Step 4: Run the tests to verify they pass, then commit**

Run: `bash tests/run_tests.sh`
Expected: `SUITE : SUCCÈS`.

```bash
git add utils/update.sh tests/test_utils_scripts.sh
git commit -m "feat: mise à jour moteur/forge/modpack préservant le monde"
```

---

### Task 15: `security/hardening.sh`

**Files:**
- Create: `security/hardening.sh`
- Create: `tests/test_security_scripts.sh`

**Interfaces:**
- Consumes: `scripts/lib.sh` (`load_server_conf`, `run_ssh`, `ask_yes_no`), `.server.conf`.
- Produces: on the VM — SSH drop-in `/etc/ssh/sshd_config.d/99-mc-hardening.conf` (`PermitRootLogin no`, `PasswordAuthentication no`), fail2ban with an sshd jail, unattended-upgrades. Idempotent.

- [ ] **Step 1: Write the failing test**

Create `tests/test_security_scripts.sh` containing only the hardening block below (the `whitelist_manager.sh` block is appended by Task 16 before `finish_tests`):

```bash
#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"

echo "-- hardening.sh --"
assert_file_exists security/hardening.sh "hardening.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n security/hardening.sh
assert_file_contains security/hardening.sh "load_server_conf"      "utilise .server.conf"
assert_file_contains security/hardening.sh "PermitRootLogin no"     "root SSH interdit"
assert_file_contains security/hardening.sh "PasswordAuthentication no" "SSH par clé uniquement"
assert_file_contains security/hardening.sh "sshd -t"                "validation config avant rechargement"
assert_file_contains security/hardening.sh "fail2ban"               "protection brute-force"
assert_file_contains security/hardening.sh "unattended-upgrades"    "mises à jour sécurité automatiques"
assert_file_not_contains security/hardening.sh "ufw"                "ufw interdit"

finish_tests
```

(The whitelist block listed under Task 16 is appended to this same file later.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL — `security/hardening.sh` absent.

- [ ] **Step 3: Create `security/hardening.sh`**

```bash
#!/usr/bin/env bash
# =============================================================================
# hardening.sh — Durcissement de la VM (exécuté LOCALEMENT, via SSH).
# Applique sur la VM :
#   1. SSH : root interdit, authentification par clé uniquement
#      (drop-in /etc/ssh/sshd_config.d/99-mc-hardening.conf, validé par sshd -t)
#   2. fail2ban sur le service sshd
#   3. mises à jour de sécurité automatiques (unattended-upgrades)
# Idempotent : ré-exécutable sans risque.
# AVERTISSEMENT : vérifiez que votre clé SSH fonctionne AVANT de lancer ce script
# (c'est déjà le cas si setup.sh a réussi).
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

load_server_conf "${SCRIPT_DIR}/.server.conf"

echo
warn "Ce script va interdire le login SSH root et l'authentification par mot de passe."
warn "Votre connexion par clé restera fonctionnelle (utilisée par ce projet)."
ask_yes_no "Continuer ?" "n" || { info "Durcissement annulé."; exit 0; }

run_ssh "bash -s" <<'REMOTE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[hardening] 1/3 — SSH durci (root interdit, clé uniquement)..."
cat > /etc/ssh/sshd_config.d/99-mc-hardening.conf <<'CONF'
# oracle-minecraft-5min-setup — durcissement SSH
PermitRootLogin no
PasswordAuthentication no
CONF
sshd -t
systemctl reload ssh 2>/dev/null || systemctl reload sshd

echo "[hardening] 2/3 — fail2ban (protection brute-force SSH)..."
apt-get install -y -qq fail2ban >/dev/null
cat > /etc/fail2ban/jail.d/minecraft-ssh.local <<'JAIL'
[sshd]
enabled = true
maxretry = 5
findtime = 10m
bantime = 1h
JAIL
systemctl enable --now fail2ban >/dev/null 2>&1 || true
systemctl restart fail2ban

echo "[hardening] 3/3 — mises à jour de sécurité automatiques..."
apt-get install -y -qq unattended-upgrades >/dev/null
systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true

echo "[hardening] Terminé."
REMOTE

success "VM durcie sur ${ORACLE_IP}."
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/run_tests.sh`
Expected: `SUITE : SUCCÈS` (hardening assertions only; whitelist assertions come with Task 16).

- [ ] **Step 5: Commit**

```bash
git add security/hardening.sh tests/test_security_scripts.sh
git commit -m "feat: durcissement SSH + fail2ban + mises à jour automatiques"
```

---

### Task 16: `security/whitelist_manager.sh`

**Files:**
- Create: `security/whitelist_manager.sh`
- Modify: `tests/test_security_scripts.sh` (append the whitelist block before `finish_tests`)

**Interfaces:**
- Consumes: `scripts/lib.sh` (`load_server_conf`, `run_ssh`, `is_valid_mc_username`, `ask_yes_no`), `.server.conf`, RCON on the VM.
- Produces: CLI `whitelist_manager.sh add|remove|list [pseudo]` — enables `white-list=true` (with restart confirmation) if needed, then drives the in-game whitelist via RCON.

- [ ] **Step 1: Append the failing test**

Append to `tests/test_security_scripts.sh`, before `finish_tests`:

```bash
echo "-- whitelist_manager.sh --"
assert_file_exists security/whitelist_manager.sh "whitelist_manager.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n security/whitelist_manager.sh
assert_file_contains security/whitelist_manager.sh "is_valid_mc_username" "validation du pseudo"
assert_file_contains security/whitelist_manager.sh "whitelist add"         "ajout via RCON"
assert_file_contains security/whitelist_manager.sh "whitelist remove"      "retrait via RCON"
assert_file_contains security/whitelist_manager.sh "white-list=true"       "activation possible de la whitelist"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL on new assertions.

- [ ] **Step 3: Create `security/whitelist_manager.sh`**

```bash
#!/usr/bin/env bash
# =============================================================================
# whitelist_manager.sh — Gère la liste blanche des joueurs (LOCAL, via SSH/RCON).
#
# Usage :
#   ./security/whitelist_manager.sh add <Pseudo>
#   ./security/whitelist_manager.sh remove <Pseudo>
#   ./security/whitelist_manager.sh list
#
# Si white-list=false dans server.properties, propose de l'activer
# (le serveur sera redémarré — les joueurs connectés sont déconnectés).
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

ACTION="${1:-}"
PLAYER="${2:-}"

usage() {
    cat <<'EOF'
Usage : whitelist_manager.sh <add|remove|list> [pseudo]
  add <pseudo>    Autorise un joueur (3-16 caractères alphanumériques/_)
  remove <pseudo> Retire un joueur
  list            Affiche la liste blanche
EOF
}

[[ "$ACTION" == "add" || "$ACTION" == "remove" || "$ACTION" == "list" ]] || { usage; exit 1; }
if [[ "$ACTION" != "list" ]]; then
    [[ -n "$PLAYER" ]] || { usage; exit 1; }
    is_valid_mc_username "$PLAYER" || die "Pseudo invalide : '$PLAYER' (3-16 caractères, A-Za-z0-9_)."
fi

load_server_conf "${SCRIPT_DIR}/.server.conf"

# Active white-list si nécessaire (avec confirmation : redémarrage du serveur).
WL_STATE="$(run_ssh "grep -E '^white-list=' /opt/minecraft/server/server.properties | cut -d= -f2")"
if [[ "$ACTION" != "list" && "$WL_STATE" != "true" ]]; then
    warn "La whitelist est désactivée (white-list=false). Pour l'activer, le serveur va redémarrer."
    ask_yes_no "Activer la whitelist maintenant ?" "y" || die "Whitelist désactivée — action impossible."
    run_ssh "sudo sed -i 's/^white-list=.*/white-list=true/' /opt/minecraft/server/server.properties && sudo systemctl restart minecraft"
    info "Whitelist activée, serveur redémarré."
fi

case "$ACTION" in
    add)    RCON_CMD="whitelist add ${PLAYER}" ;;
    remove) RCON_CMD="whitelist remove ${PLAYER}" ;;
    list)   RCON_CMD="whitelist list" ;;
esac

run_ssh "sudo bash -c '. /opt/minecraft/server/.rcon-credentials && \
python3 /opt/minecraft/bin/rcon_client.py 127.0.0.1 \$RCON_PORT \$RCON_PASSWORD \"${RCON_CMD}\"'"

# Rafraîchit la liste côté serveur après une modification.
if [[ "$ACTION" != "list" ]]; then
    run_ssh "sudo bash -c '. /opt/minecraft/server/.rcon-credentials && \
python3 /opt/minecraft/bin/rcon_client.py 127.0.0.1 \$RCON_PORT \$RCON_PASSWORD \"whitelist reload\"'" >/dev/null
    success "Whitelist mise à jour : ${ACTION} ${PLAYER}"
fi
```

- [ ] **Step 4: Run the tests to verify they pass, then commit**

Run: `bash tests/run_tests.sh`
Expected: `SUITE : SUCCÈS`.

```bash
git add security/whitelist_manager.sh tests/test_security_scripts.sh
git commit -m "feat: gestion de la whitelist via RCON"
```

---

### Task 17: `uninstall.sh`

**Files:**
- Create: `uninstall.sh`
- Modify: `tests/test_utils_scripts.sh` (append before `finish_tests`)

**Interfaces:**
- Consumes: `scripts/lib.sh` (`load_server_conf`, `run_ssh`, `ask_yes_no`), `.server.conf`, optionally `utils/backup.sh`.
- Produces: clean removal on the VM — systemd unit, `/opt/minecraft` (after optional final backup), Crafty container, iptables rules, `minecraft` user — plus removal of local `.server.conf`. Does NOT delete the VM itself (documented).

- [ ] **Step 1: Append the failing test**

Append to `tests/test_utils_scripts.sh`, before `finish_tests`:

```bash
echo "-- uninstall.sh --"
assert_file_exists uninstall.sh "uninstall.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n uninstall.sh
assert_file_contains uninstall.sh "load_server_conf"           "utilise .server.conf"
assert_file_contains uninstall.sh "systemctl disable --now minecraft" "arrêt du service"
assert_file_contains uninstall.sh "docker compose down"        "arrêt de Crafty"
assert_file_contains uninstall.sh "iptables -D INPUT"          "retrait des règles pare-feu"
assert_file_contains uninstall.sh "netfilter-persistent save"  "persistance du retrait"
assert_file_contains uninstall.sh "userdel minecraft"          "suppression de l'utilisateur dédié"
assert_file_contains uninstall.sh ".server.conf"               "suppression conf locale"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL on new assertions.

- [ ] **Step 3: Create `uninstall.sh`**

```bash
#!/usr/bin/env bash
# =============================================================================
# uninstall.sh — Supprime TOUT ce que le projet a installé sur la VM (via SSH).
#
#  - optionnellement : une dernière sauvegarde (utils/backup.sh)
#  - service systemd 'minecraft' + unité
#  - Crafty Controller (conteneur + fichiers)
#  - règles iptables ajoutées (25565 tcp/udp, 8443 tcp)
#  - utilisateur système 'minecraft' et /opt/minecraft
#  - configuration locale .server.conf
#
# La VM Oracle elle-même N'EST PAS supprimée (console OCI → Instances → Terminate).
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

load_server_conf "${SCRIPT_DIR}/.server.conf"

echo
warn "Cette action supprime le serveur Minecraft, ses mondes et Crafty sur ${ORACLE_IP}."
warn "La VM Oracle reste en place (à supprimer depuis la console OCI si souhaité)."
echo
read -r -p "Tapez SUPPRIMER pour confirmer : " confirmation
[[ "$confirmation" == "SUPPRIMER" ]] || { info "Annulé."; exit 0; }

if ask_yes_no "Créer une dernière sauvegarde avant suppression ?" "n"; then
    bash "${SCRIPT_DIR}/utils/backup.sh"
fi

run_ssh "bash -s" <<'REMOTE'
set -uo pipefail

echo "[uninstall] Arrêt du service minecraft..."
systemctl disable --now minecraft 2>/dev/null || true
rm -f /etc/systemd/system/minecraft.service
systemctl daemon-reload

echo "[uninstall] Arrêt de Crafty Controller..."
if [[ -d /opt/minecraft/docker-crafty ]]; then
    ( cd /opt/minecraft/docker-crafty && docker compose down ) 2>/dev/null || true
fi

echo "[uninstall] Retrait des règles iptables..."
iptables -D INPUT -p tcp --dport 25565 -m state --state NEW -j ACCEPT 2>/dev/null || true
iptables -D INPUT -p udp --dport 25565 -m state --state NEW -j ACCEPT 2>/dev/null || true
iptables -D INPUT -p tcp --dport 8443  -m state --state NEW -j ACCEPT 2>/dev/null || true
netfilter-persistent save 2>/dev/null || true

echo "[uninstall] Suppression des fichiers et de l'utilisateur..."
rm -rf /opt/minecraft
if id -u minecraft >/dev/null 2>&1; then
    userdel minecraft 2>/dev/null || true
fi

echo "[uninstall] VM nettoyée."
REMOTE

rm -f "${SCRIPT_DIR}/.server.conf"
success "Désinstallation terminée. Pensez à supprimer la VM depuis la console Oracle si vous n'en avez plus besoin."
```

- [ ] **Step 4: Run the tests to verify they pass, then commit**

Run: `bash tests/run_tests.sh`
Expected: `SUITE : SUCCÈS`.

```bash
git add uninstall.sh tests/test_utils_scripts.sh
git commit -m "feat: désinstallation complète et propre"
```

---

### Task 18: `docs/oci-vcn-config.md` — guide VCN obligatoire

**Files:**
- Create: `docs/oci-vcn-config.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the doc referenced by `remote_provision.sh` final output, `setup.sh` final banner, and README. It is the manual counterpart of `deploy/oci_ingress_setup.sh`.

- [ ] **Step 1: Create `docs/oci-vcn-config.md`**

```markdown
# Ouvrir les ports du réseau Oracle (VCN) — ÉTAPE OBLIGATOIRE

## Pourquoi cette étape est indispensable

Votre VM est protégée par **deux pare-feu** successifs :

| Niveau | Où ça se règle | Qui le configure |
|---|---|---|
| 1. VCN Security List (le cloud Oracle) | Console web Oracle (ou OCI CLI) | **Vous, une seule fois** (ce guide) |
| 2. iptables (la VM Ubuntu) | `deploy/configure_iptables.sh` | Le script d'installation, automatiquement |

Par défaut, le VCN n'autorise que le port 22 (SSH). Tant que les Ingress Rules
ne sont pas ouvertes, votre serveur est invisible depuis Minecraft, même si
tout le reste fonctionne. **Comptez 3 minutes.**

## Méthode A — Console Oracle (recommandée)

1. Connectez-vous sur <https://cloud.oracle.com>.
2. Menu ☰ (en haut à gauche) → **Networking** → **Virtual Cloud Networks**.
3. Cliquez sur votre VCN (nom par défaut du type `vcn-20260822-1234...`).
4. Dans la colonne **Resources**, cliquez sur **Security Lists**, puis sur
   **Default Security List for ...**.
5. Cliquez sur **Add Ingress Rules** et ajoutez les trois règles suivantes
   (utilisez *Add Another Rule* pour les saisir en une fois) :

   | Champ | Règle 1 | Règle 2 | Règle 3 |
   |---|---|---|---|
   | Source Type | CIDR | CIDR | CIDR |
   | Source CIDR | `0.0.0.0/0` | `0.0.0.0/0` | `0.0.0.0/0` |
   | IP Protocol | TCP | UDP | TCP |
   | Source Port Range | *(vide)* | *(vide)* | *(vide)* |
   | Destination Port Range | `25565` | `25565` | `8443` |
   | Description | Minecraft TCP | Minecraft UDP | Crafty Panel |

6. Cliquez sur **Add Ingress Rules**. L'effet est immédiat.

> Le port 22 (SSH) est déjà ouvert par défaut — ne le modifiez pas.
> `0.0.0.0/0` signifie « depuis n'importe quelle adresse Internet », ce qui est
> nécessaire pour que vos amis se connectent.

## Méthode B — Script OCI CLI (optionnel)

Si vous avez installé l'OCI CLI (`pip install oci-cli && oci setup config`) et `jq` :

```bash
bash deploy/oci_ingress_setup.sh --security-list-ocid ocid1.securitylist.oc1...
```

L'OCID se trouve dans la console : VCN → Security Lists → votre security list →
champ **OCID** (bouton copier). Le script est idempotent : le relancer ne crée
pas de doublons.

## Vérifier que ça marche

1. Le serveur doit être démarré : `./utils/monitor.sh` → `active`.
2. Depuis votre PC, testez le port :
   - Windows PowerShell : `Test-NetConnection <IP_VM> -Port 25565` → `TcpTestSucceeded : True`
   - Linux/macOS : `nc -vz <IP_VM> 25565` → `succeeded`
3. Dans Minecraft : Multijoueur → Ajouter un serveur → `<IP_VM>:25565`.

Si l'icône ping du serveur reste barrée, voir `docs/troubleshooting.md`
(section « Connection timed out ») pour l'arbre de diagnostic complet
(VCN → iptables → service).
```

- [ ] **Step 2: Verify and commit**

Run: `test -f docs/oci-vcn-config.md && grep -c "Add Ingress Rules" docs/oci-vcn-config.md` — expect `2`.

```bash
git add docs/oci-vcn-config.md
git commit -m "docs: guide d'ouverture des Ingress Rules VCN (obligatoire)"
```

---

### Task 19: `docs/guide-debutant-fr.md` — guide débutant complet

**Files:**
- Create: `docs/guide-debutant-fr.md`

**Interfaces:**
- Consumes: facts from the whole project (quotas 2 OCPU/12 Go, ports, scripts paths).
- Produces: the main beginner doc referenced by README and `setup.sh` (modpack instructions).

Write the guide with exactly this structure and technical content (prose may be lightly expanded, all facts must match):

- [ ] **Step 1: Create the guide**

```markdown
# Guide Débutant — Serveur Minecraft gratuit sur Oracle Cloud

## Sommaire
1. Introduction
2. Qu'est-ce qu'un serveur Minecraft ?
3. Qu'est-ce qu'Oracle Cloud et pourquoi c'est vraiment gratuit ?
4. Prérequis (5 minutes de lecture)
5. Créer un compte Oracle Cloud
6. Créer la machine virtuelle (VM)
7. Lancer setup.sh (5 minutes)
8. Ouvrir les ports du VCN (3 minutes — OBLIGATOIRE)
9. Se connecter avec Minecraft
10. Installer les mods côté joueur (CurseForge)
11. Inviter ses amis
12. Administrer au quotidien (sauvegardes, surveillance, mise à jour)
13. FAQ

---

## 1. Introduction

Objectif : un serveur Minecraft moddé, gratuit, allumé 24h/24, contrôlable
depuis une simple page web (Crafty), en moins de 15 minutes au total — dont
5 minutes de configuration technique grâce à `setup.sh`.

## 2. Qu'est-ce qu'un serveur Minecraft ?

En solo, le monde tourne sur votre PC et s'arrête quand vous fermez le jeu.
Un serveur dédié est un ordinateur qui fait tourner le monde en permanence :
vos amis s'y connectent quand ils veulent, le monde persiste, et vous choisissez
les mods/règles. C'est « votre appartement » plutôt que « votre chambre ».

## 3. Qu'est-ce qu'Oracle Cloud et pourquoi c'est vraiment gratuit ?

Oracle Cloud Infrastructure (OCI) loue des ordinateurs dans des datacenters.
Leur offre **Always Free** inclut, à vie et sans engagement :

| Ressource | Quota gratuit (2026) | Pour Minecraft |
|---|---|---|
| CPU (ARM Ampere A1) | 2 OCPU | Suffisant pour 3-10 joueurs |
| RAM | 12 Go | Largement (les hébergeurs gratuits donnent 1-2 Go) |
| Disque | 200 Go | Un monde moddé = 5-30 Go |
| Sortie réseau | 10 To/mois | Illimité en pratique |

C'est de l'acquisition commerciale : Oracle espère que vous passerez au payant
plus tard. Le palier gratuit ne se ferme pas au bout de 12 mois (contrairement
à AWS/Azure). La carte bancaire demandée à l'inscription sert uniquement de
vérification d'identité : aucune somme n'est prélevée tant que vous restez
dans ces quotas (ne cochez jamais « Upgrade to Pay As You Go » par accident).

## 4. Prérequis

- Minecraft **Java Edition** (~30 €, achat unique — PAS Bedrock/console/mobile).
- Une carte bancaire pour la vérification Oracle (pré-autorisation ~1 $ remboursée).
- Un terminal : Linux, macOS, ou **Git Bash sur Windows** (inclus avec Git pour
  Windows). Sur Windows : installez Git pour Windows, clic droit dans un dossier
  → « Open Git Bash here ».
- 15 minutes.

## 5. Créer un compte Oracle Cloud

1. <https://cloud.oracle.com> → **Start for free**.
2. Email, mot de passe, nom, pays, téléphone (vérification SMS).
3. Vérification par carte bancaire (aucun débit ; les cartes virtuelles
   jetables sont souvent refusées).
4. Choix de la **région (Home Region)** : c'est définitif. Depuis la France :
   UK South (Londres) ou Germany Central (Francfort) pour un ping de 15-35 ms.
5. Attendez l'email de confirmation (parfois 30 min), puis connectez-vous.

## 6. Créer la machine virtuelle (VM)

Dans la console : menu ☰ → **Compute** → **Instances** → **Create instance**.

- **Name** : ce que vous voulez (ex. `minecraft`).
- **Image and Shape** :
  - Edit → Image : **Ubuntu** 22.04 ou 24.04 (pas « Minimal »).
  - Edit → Shape : **Ampere** → **VM.Standard.A1.Flex** avec :
    - OCPUs : **2**
    - Memory : **12 GB**
    (C'est l'intégralité du quota gratuit ; si le bouton reste bloqué à moins,
    votre compte est peut-être encore en cours de validation.)
- **Networking** : laissez par défaut, vérifiez **Assign a public IPv4 address**.
- **Add SSH keys** : ⚠️ étape critique —
  1. « Generate a key pair »
  2. **Save Private Key** → conservez ce fichier (`ssh-key-2026-XX-XX.key`)
     précieusement : sans lui, plus aucun accès à la VM.
  3. **Save Public Key** (auto-upload ou upload manuel).
- Cliquez **Create** (2-5 minutes), puis notez l'**IP publique** affichée
  sur la page de l'instance.

En cas d'erreur « Out of capacity » : réessayez plus tard ou changez de région
(voir troubleshooting).

## 7. Lancer setup.sh (5 minutes)

Dans un terminal (Git Bash sous Windows), dans le dossier du projet :

```bash
./setup.sh
```

Le script vous demande : l'IP publique, le chemin de la clé privée, le type de
serveur (Vanilla / Forge / Fabric / Modpack), la RAM (8 Go conseillé), le
nombre de joueurs, et si vous voulez le panel web Crafty. Il installe ensuite
tout sur la VM : Java 21, le serveur, le pare-feu, le démarrage automatique
(systemd), et affiche l'adresse de connexion finale.

Passez ensuite à l'étape 8 ci-dessous — sans elle, personne ne peut se connecter.

## 8. Oublis interdits : ouvrir les ports du VCN

Suivez `docs/oci-vcn-config.md` (3 minutes, des clics dans la console Oracle).
Résumé : VCN → Security Lists → Add Ingress Rules → TCP 25565, UDP 25565,
TCP 8443, source `0.0.0.0/0`.

## 9. Se connecter avec Minecraft

1. Minecraft Java Edition → **Multijoueur** → **Ajouter un serveur**.
2. Adresse : `IP_DE_VOTRE_VM:25565` (le `:25565` est optionnel mais explicite).
3. Rejoignez ! Si ça échoue : `docs/troubleshooting.md`.

Le panel Crafty (si installé) : `https://IP_DE_VOTRE_VM:8443` — acceptez
l'avertissement de certificat auto-signé, connectez-vous (identifiants
affichés par Crafty au premier lancement, visibles via
`ssh ubuntu@IP 'sudo docker logs crafty_controller'`) et changez le mot de passe.

## 10. Installer les mods côté joueur (CurseForge)

Un serveur moddé exige que **chaque joueur** ait exactement les mêmes mods.

1. Installez l'app **CurseForge** (<https://www.curseforge.com/download>).
2. Onglet Minecraft → Browse Modpacks → cherchez le modpack du serveur
   (ex. « Better Minecraft [Forge] » version **1.20.1**) → Install.
3. Lancez le jeu **depuis CurseForge** (bouton Play).

Pour un serveur Forge « custom » : mêmes versions de Minecraft ET de Forge
que le serveur (visible dans `./utils/monitor.sh` ou la console Crafty).

## 11. Inviter vos amis

Envoyez-leur ce message (adaptez) :

> 🎮 Serveur Minecraft moddé prêt !
> Adresse : `IP:25565`
> Il vous faut : Minecraft Java (~30 €, achat unique) + l'app CurseForge +
> le modpack « NOM » version 1.20.1 (Install, puis Play depuis CurseForge).
> Ensuite : Multijoueur → Ajouter un serveur → l'adresse ci-dessus.

Pensez à la whitelist pour un serveur privé :
`./security/whitelist_manager.sh add Pseudo`.

## 12. Administrer au quotidien

| Besoin | Commande |
|---|---|
| Sauvegarder | `./utils/backup.sh` |
| Restaurer | `./utils/restore.sh` |
| Surveiller (CPU, RAM, joueurs, TPS) | `./utils/monitor.sh` |
| Mettre à jour le serveur | `./utils/update.sh` |
| Sécuriser la VM | `./security/hardening.sh` |
| Gérer la whitelist | `./security/whitelist_manager.sh` |
| Tout supprimer | `./uninstall.sh` |

Le serveur redémarre tout seul après un crash ou un reboot de la VM (systemd).

## 13. FAQ

- **C'est vraiment gratuit ?** Oui — 0 €/mois dans les quotas Always Free ;
  seul coût : Minecraft Java (~30 €, une fois).
- **Combien de joueurs ?** Vanilla : 15-20 ; moddé léger : 5-10 ;
  gros modpacks : 3-5 avec 8 Go de RAM.
- **Le serveur tourne quand je ne joue pas ?** Oui, 24/7.
- **Je peux changer de modpack plus tard ?** Oui : `./utils/update.sh`.
- **Oracle peut-il couper l'offre ?** Le risque existe théoriquement ; en
  pratique l'offre existe depuis 2018. Vos sauvegardes (`utils/backup.sh`)
  restent récupérables à tout moment.
```

- [ ] **Step 2: Verify and commit**

Run: `grep -c "^## " docs/guide-debutant-fr.md` — expect `14` (13 sections + Sommaire).
Run: `grep -q "12 GB" docs/guide-debutant-fr.md && grep -q "2 OCPU" docs/guide-debutant-fr.md && echo OK` — expect `OK` (current quotas, not the obsolete 24 GB).

```bash
git add docs/guide-debutant-fr.md
git commit -m "docs: guide débutant complet (compte, VM, setup, mods, admin)"
```

---

### Task 20: `docs/troubleshooting.md`

**Files:**
- Create: `docs/troubleshooting.md`

**Interfaces:**
- Consumes: facts from the whole project.
- Produces: diagnostic doc referenced by README, guide, and `setup.sh`.

- [ ] **Step 1: Create `docs/troubleshooting.md`**

```markdown
# Dépannage — problèmes courants

Arbre de diagnostic universel : **VCN → iptables → service → Java/mods**.
Chaque section suit ce fil.

## « Connection timed out » (le plus fréquent)

Le paquet n'atteint pas la VM. Dans l'ordre :

1. **VCN** : les Ingress Rules sont-elles ouvertes ? (`docs/oci-vcn-config.md`)
   Console → Networking → VCN → Security Lists → vous devez voir TCP 25565,
   UDP 25565, TCP 8443 en source `0.0.0.0/0`.
2. **iptables** : sur les VM Oracle, **ufw ne fonctionne pas** (conflit avec les
   règles OCI). Le setup utilise iptables directement. Vérifiez :
   `ssh ubuntu@IP 'sudo iptables -L INPUT -n --line-numbers | grep 25565'`
   → deux règles ACCEPT doivent apparaître AVANT la ligne REJECT.
   Réparez : relancez `./setup.sh` (idempotent) ou
   `ssh ubuntu@IP 'sudo bash /opt/minecraft/bin/remote_provision.sh ...'`.
3. **Service démarré ?** `./utils/monitor.sh` → doit afficher `active` et le
   port 25565 en écoute (`ss -tln | grep 25565`).
4. **La VM tourne ?** Console Oracle → Compute → Instances → statut Running.
   Après un arrêt Oracle, l'IP publique peut changer : refaites `./setup.sh`.

## « Connection refused » / « No route to host »

Le port est fermé ou le serveur est éteint : étapes 2 et 3 ci-dessus.
« No route to host » est typiquement la règle REJECT d'iptables qui vous
renvoie un refus : règle ACCEPT manquante ou placée après le REJECT.

## Forge : « Error: Could not find or load main class »

Cause : tentative de lancement avec `java -jar server.jar`. Depuis Forge
1.17, le lancement passe obligatoirement par `@unix_args.txt`. Le projet
génère `/opt/minecraft/server/start.sh` correct ; ne lancez jamais le jar
directement. Vérifiez :
`ssh ubuntu@IP 'cat /opt/minecraft/server/start.sh'` → la ligne `exec java
@user_jvm_args.txt @libraries/.../unix_args.txt nogui` doit être présente.

## Crash / « Out of Memory » (OOM Killer)

La VM a 12 Go ; la JVM est plafonnée à 8 Go. Si vous avez augmenté `-Xmx`
au-delà, le noyau Linux tue Java. Diagnostic :
`ssh ubuntu@IP 'journalctl -u minecraft -n 50'` (cherchez `oom-killer`).
Correctif : `-Xmx8G` maximum dans `user_jvm_args.txt`, puis
`ssh ubuntu@IP 'sudo systemctl restart minecraft'`.

## Lag / « Can't keep up! »

1. Réduire `view-distance` et `simulation-distance` à 6 dans
   `/opt/minecraft/server.properties` (via Crafty ou sed + restart).
2. Trop de mods pour 2 OCPU : retirez les gros mods, préférez les packs légers.
3. Vérifier les TPS : `./utils/monitor.sh` (19-20 = parfait, < 15 = problème).
4. Premier démarrage d'un monde moddé : c'est normal pendant 5-10 minutes.

## « IO Netty Error » / rejet de mods à la connexion

Mods différents entre serveur et joueur. Chaque joueur doit avoir EXACTEMENT
le même modpack (même version). Le plus simple : réinstallez le modpack côté
joueur via CurseForge ; côté serveur, `./utils/update.sh` avec le server pack
officiel. Comparez : `ssh ubuntu@IP 'ls /opt/minecraft/server/mods | wc -l'`.

## Crafty inaccessible (https://IP:8443)

1. Ingress Rule TCP 8443 ouverte ? (VCN)
2. `ssh ubuntu@IP 'sudo docker ps'` → conteneur `crafty_controller` « Up » ?
3. `ssh ubuntu@IP 'sudo docker logs --tail 50 crafty_controller'`.
4. Certificat auto-signé : l'avertissement du navigateur est normal.

## « Out of capacity » à la création de la VM

Région saturée : réessayez à une autre heure, un autre jour, ou choisissez
une autre région (région définitive : créez éventuellement un nouveau compte
avec une autre adresse email — la limite « Out of capacity » est par région).

## SSH : « Permission denied (publickey) »

Mauvaise clé ou mauvaise IP. Testez :
`ssh -i /chemin/vers/ssh-key-*.key ubuntu@IP` — l'utilisateur est toujours
`ubuntu` sur les images Ubuntu d'Oracle. Permissions de la clé : `chmod 600`.

## Tout réinstaller

`./uninstall.sh` puis `./setup.sh`. Le monde est sauvegardé si vous acceptez
la sauvegarde finale proposée. En dernier recours : supprimez la VM depuis la
console Oracle et recommencez le guide débutant à l'étape 6.
```

- [ ] **Step 2: Verify and commit**

Run: `grep -c "^## " docs/troubleshooting.md` — expect `10`.

```bash
git add docs/troubleshooting.md
git commit -m "docs: guide de dépannage (VCN/iptables/Forge/OOM/lag)"
```

---

### Task 21: `README.md` + validation finale de structure

**Files:**
- Create: `README.md`
- Create: `tests/test_structure.sh`
- Modify: git index (executable bits)

**Interfaces:**
- Consumes: the complete file tree from all previous tasks.
- Produces: the public landing page and the final quality gate (structure, `bash -n` sweep, CRLF check, optional shellcheck, executable bits in git).

- [ ] **Step 1: Create `README.md`**

```markdown
# 🎮 Oracle Cloud Minecraft — Setup en 5 minutes

Déployez un **serveur Minecraft moddé** (Forge 1.20.1 / Fabric / Vanilla /
modpack) sur le **Always Free** d'Oracle Cloud : 2 OCPU ARM, **12 Go de RAM**,
200 Go de disque, **0 €/mois**, 24h/24 — sans compétence DevOps.

```bash
./setup.sh
```

> ⚠️ Prérequis : un compte Oracle Cloud et une VM Ubuntu ARM créés
> (guide complet : [`docs/guide-debutant-fr.md`](docs/guide-debutant-fr.md)),
> Minecraft **Java Edition**. Après le setup, ouvrez les ports du VCN
> ([`docs/oci-vcn-config.md`](docs/oci-vcn-config.md), 3 minutes).

## Ce que fait le script

| Étape | Fait automatiquement |
|---|---|
| Système | Java 21 (ARM64), paquets, utilisateur dédié `minecraft` |
| Serveur | Vanilla / Forge / Fabric / modpack, configuration optimisée |
| Performance | Flags JVM calibrés Ampere A1 (ZGC générationnel, 8 Go max) |
| Pare-feu | iptables inséré avant le REJECT d'Oracle (ufw proscrit sur OCI) |
| Panel web | Crafty Controller (Docker Compose, optionnel) |
| Démarrage | Service systemd : auto-start et redémarrage après crash |
| Admin | Sauvegardes à chaud, restauration, supervision, whitelist |

## Comparatif

| Hébergeur | RAM | Prix | File d'attente | Contrôle |
|---|---|---|---|---|
| Aternos / Minehut | 1-2 Go | Gratuit | Oui | Limité |
| Hébergeur payant | 8 Go | 15-30 €/mois | Non | Moyen |
| **Ce projet (OCI)** | **12 Go** | **0 €/mois** | **Non** | **Total** |

Coût réel : Minecraft Java (~30 €, achat unique) + 0 €/mois.

## Scripts fournis

| Script | Rôle |
|---|---|
| `setup.sh` | Installation complète (interactive ou `--help` pour le mode scripté) |
| `utils/backup.sh` | Sauvegarde à chaud + rotation (`KEEP=14 ./utils/backup.sh`) |
| `utils/restore.sh` | Restauration d'une archive |
| `utils/monitor.sh` | CPU, RAM, disque, joueurs, TPS (`watch -n 5 ./utils/monitor.sh`) |
| `utils/update.sh` | Mise à jour moteur / Forge / modpack (préserve le monde) |
| `security/hardening.sh` | SSH durci, fail2ban, mises à jour auto |
| `security/whitelist_manager.sh` | `add` / `remove` / `list` |
| `uninstall.sh` | Suppression propre de tout ce qui a été installé |

## Documentation

- [Guide débutant complet](docs/guide-debutant-fr.md) — de zéro au premier bloc posé
- [Ouvrir les ports VCN](docs/oci-vcn-config.md) — étape obligatoire après le setup
- [Dépannage](docs/troubleshooting.md) — timed out, Forge, OOM, lag...

## Détails techniques (pour les curieux)

- **Séparation stricte local/distant** : `setup.sh` tourne chez vous et pilote
  la VM en SSH ; tout le provisioning s'exécute sur la VM via
  `deploy/remote_provision.sh` (idempotent, ré-exécutable sans risque).
- **Forge moderne** : lancement via `@unix_args.txt` — jamais `java -jar`.
- **Pare-feu OCI** : les images Ubuntu d'Oracle terminent leur chaîne iptables
  par un REJECT global qui neutralise ufw ; nous insérons donc nos règles
  directement avant ce REJECT puis persistons avec `netfilter-persistent`.
- **JVM ARM64** : `-Xms` = `-Xmx` ≤ 8 Go, ZGC générationnel, AlwaysPreTouch.

## Contribuer

Issues et PR bienvenues : nouveaux modpacks (fichier JSON dans `modpacks/`),
corrections de documentation, idées d'optimisation. Les scripts sont testés
(`bash tests/run_tests.sh`) — faites passer la suite avant de proposer une PR.

## Licence

[MIT](LICENSE)
```

- [ ] **Step 2: Write the failing structure test**

`tests/test_structure.sh`:

```bash
#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"

echo "-- arborescence complète --"
for f in README.md LICENSE .gitignore .gitattributes setup.sh uninstall.sh \
         scripts/lib.sh \
         deploy/remote_provision.sh deploy/configure_iptables.sh \
         deploy/docker-compose.crafty.yml deploy/oci_ingress_setup.sh \
         configs/server.properties.template configs/user_jvm_args.txt.template configs/eula.txt \
         modpacks/manifest.json modpacks/better-minecraft.json modpacks/atm9-light.json modpacks/vanilla-plus.json \
         utils/rcon_client.py utils/backup.sh utils/restore.sh utils/monitor.sh utils/update.sh \
         security/hardening.sh security/whitelist_manager.sh \
         docs/guide-debutant-fr.md docs/oci-vcn-config.md docs/troubleshooting.md; do
    assert_file_exists "$f" "présent : $f"
done

echo "-- syntaxe de tous les scripts bash --"
while IFS= read -r f; do
    assert_exit_zero "bash -n $f" bash -n "$f"
done < <(find . -type f -name '*.sh' -not -path './.git/*')

echo "-- fins de ligne LF (pas de CRLF) --"
while IFS= read -r f; do
    if grep -qU $'\r' "$f"; then t_fail "CRLF détecté : $f"; else t_pass "LF : $f"; fi
done < <(find . -type f \( -name '*.sh' -o -name '*.py' -o -name '*.yml' -o -name '*.json' -o -name '*.template' \) -not -path './.git/*')

echo "-- shellcheck (si installé) --"
if command -v shellcheck >/dev/null 2>&1; then
    sc_err=0
    while IFS= read -r f; do
        shellcheck -S warning "$f" || sc_err=1
    done < <(find . -type f -name '*.sh' -not -path './.git/*')
    if (( sc_err == 0 )); then t_pass "shellcheck global"; else t_fail "shellcheck global"; fi
else
    echo "  (shellcheck absent — contrôle sauté)"
fi

echo "-- absence de régressions interdites --"
assert_file_not_contains deploy/remote_provision.sh "minecraft_server.jar" "pas de java -jar Forge obsolète"
assert_file_not_contains deploy/configure_iptables.sh "ufw" "pas d'ufw"

finish_tests
```

Run: `bash tests/run_tests.sh` — the structure test passes only if every prior task is complete; fix any gap it reveals before committing.

- [ ] **Step 3: Mark scripts executable in git and run the full suite**

```bash
git ls-files '*.sh' '*.py' | xargs git update-index --chmod=+x
bash tests/run_tests.sh
```

Expected: `SUITE : SUCCÈS`.

- [ ] **Step 4: Commit**

```bash
git add README.md tests/test_structure.sh
git commit -m "docs: README final + validation de structure et syntaxe"
```

---

## Post-plan verification (done during self-review)

1. **Spec coverage** — V3.0 Part 4 structure: all 26 files present (Task map: 1→meta files, 2-3→lib, 4→configs, 5→modpacks, 6-8+10→deploy, 9→setup.sh, 11-14→utils, 15-16→security, 17→uninstall, 18-20→docs, 21→README). Part 5 code requirements (Forge `@unix_args.txt`, iptables `-I` before REJECT + `netfilter-persistent`, Docker Crafty, JVM flags incl. `-XX:+ZGenerational`, dedicated `minecraft` user, systemd unit) → Tasks 6-8. Part 6 docs (VM creation guide, VCN walkthrough, client mods, troubleshooting incl. "Could not find or load main class" and OOM 8/12) → Tasks 18-20. Part 7 constraints (no TODOs, French comments, idempotence) → Global Constraints + test assertions. V2-only extras intentionally dropped per V3: `scripts/oracle-check.sh` etc. superseded by `deploy/`, CI workflows (F9), binary assets.
2. **Placeholder scan** — no TBD/TODO/"implement later"; every code step contains full file content; the two intentional user-supplied values (modpack server-pack URL, GitHub repo links are relative) are documented UX, not placeholders.
3. **Type consistency** — `is_valid_*` signatures identical in Tasks 2/3 and used identically in Tasks 9/12/14/16; `remote_provision.sh` CLI flags in Task 8 match the invocations in Tasks 9 and 14; `.server.conf` keys written in Task 9 match `load_server_conf` consumers; archive name format `backup-YYYYMMDD-HHMMSS.tar.gz` matches `is_valid_backup_name` regex and restore parsing.

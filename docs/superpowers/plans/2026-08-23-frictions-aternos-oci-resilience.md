# Plan d'amélioration v3.7/v4.0 — Aternos-grade + résilience OCI

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Atteindre l'expérience Aternos (catalogue de modpacks intégré + changement de version en 2 clics) tout en éliminant les frictions critiques qui font abandonner un débutant total, et doter le projet d'une résilience opérationnelle réelle face aux risques documentés d'Oracle Cloud (réclamation idle, IP éphémère, OoC au recréage).

**Architecture:** Trois chantiers parallèles — (A) Frictions critiques (correctifs bornés en quelques heures chacun, TDD), (B) Souveraineté des données (sauvegardes locales + Object Storage + reprise après crash), (C) Aternos-grade (Crafty zéro-UI + keep-alive + IP réservée + DNS). Chaque tâche reste idempotente, traçable, et testée (suite ≥ 450 assertions).

**Tech Stack:** Bash strict, systemd, OpenTofu (optionnel), OCI CLI + SDK Python, rclone, Modrinth + Crafty OpenAPI, Healthchecks.io, Discord webhooks.

## Sources / faits à intégrer

- **Réclamation Always Free** : 7j glissants, CPU p95 <20 % ET réseau <20 % ET mémoire <20 % (A1) — https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- **Keep-alive communautaire** : `oracle-keepalive` etc., >= 20 % CPU p95 (https://github.com/captchasonic-dev/oracle-keepalive)
- **IP réservée** : 50/région max, réassignable, à créer AVANT l'arrêt d'instance (https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/managingpublicIPs.htm)
- **Object Storage Always Free** : 20 Go + 50k req/mois (https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm) — rclone supporte OCI S3 via Instance Principal sans clés (https://rclone.org/oracleobjectstorage/)
- **Crafty OpenAPI** : `POST /api/v2/auth/login` (JWT) + `POST /api/v2/servers` (create `download_jar` / `download_exe`), Bearer auth (https://docs.craftycontrol.com/pages/developer-guide/api-reference/openapi-spec.yml)
- **Modrinth** : rate limit 300 req/min/IP, User-Agent obligatoire (https://docs.modrinth.com/api/) ; pas d'auth requise pour les modpacks
- **systemd OnFailure=** : un service `discord-alert@%n.service` déclenche un `curl` vers un webhook Discord sans dépendance externe

## Global Constraints

- Bash strict, portable macOS bash 3.2, Git Bash Windows. Pas de `mapfile`/`${var,,}`. Pas de `[[ =~ $'\\r' ]]` (BSD grep).
- Tests : TDD strict — chaque changement commence par des assertions qui échouent.
- Suite doit terminer `SUITE : SUCCÈS`. Les `bash -n` ne suffisent pas, on ajoute des tests de contenu.
- Un seul `VERSION` dans `scripts/lib.sh` (source de vérité), utilisé partout (UA Modrinth, README, `--version`).
- L'i18n devient obligatoire pour TOUT message visible (y compris les scripts utils/ et manage.sh). Mots de confirmation (`SUPPRIMER`) traduits.
- Aucune dépendance facultative non documentée : si on exige `oci` / `rclone` / `openton` / `python3`, le script le détecte et propose une install ou échoue explicitement.

---

## File Structure

```
oracle-minecraft-5min-setup/
├── scripts/
│   ├── lib.sh                       # VERSION unique, warn_i18n, recover_from_state, open_url
│   ├── lang_fr.sh / lang_en.sh      # étendu (1 entrée minimum par message)
│   ├── cli_state.sh                 # NOUVEAU : parse .server.conf, helpers de sortie
│   └── vcn_oci.sh                   # NOUVEAU : fonctions OCI (réservation IP, Object Storage)
├── deploy/
│   ├── remote_provision.sh           # + state file + --lang + ZGenerational + reseed launcher
│   ├── configure_iptables.sh        # inchangé
│   ├── docker-compose.crafty.yml     # + seeder creds + TZ
│   ├── crafty-seed.sh               # NOUVEAU : login API + create server + save token
│   ├── keepalive.sh                 # NOUVEAU : CPU + RAM burn >20% p95
│   ├── oci_ingress_setup.sh         # inchangé
│   └── openTofu/                    # NOUVEAU : provision VM complet (référence, optionnel)
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
├── utils/
│   ├── manage.sh → manage.py ?     # R1: reroutage via menu unique stable, pas de renumérotation
│   ├── mods.sh                      # + status (catégorie "par modpack"), CFWidget fallback
│   ├── backup.sh                    # + scp local + upload OCI Object Storage (optionnel)
│   ├── restore.sh                   # + pre-restore safety backup + clean extraction
│   ├── monitor.sh                   # inchangé
│   ├── update.sh                    # + reseed launchers
│   ├── console.sh                   # inchangé
│   ├── rcon_client.py               # inchangé
│   ├── status.sh                    # NOUVEAU (rapide, pour CI) — 30 lignes
│   └── rollback.sh                  # NOUVEAU : retour version N-1 sans casser le monde
├── security/
│   ├── hardening.sh                 # inchangé
│   ├── whitelist_manager.sh         # + confirmation traduite
│   └── discord_alert@.service       # NOUVEAU (template systemd)
├── start-windows.bat                 # R6: valide WSL, supprime `\(..\)`
├── README.md / README.fr.md         # mis à jour (récit v4)
└── docs/
    ├── en/
    │   ├── getting-started.md        # + link to keep-alive + R3 (DNS)
    │   ├── vcn-setup.md
    │   ├── troubleshooting.md
    │   ├── keep-alive.md             # NOUVEAU
    │   ├── backups.md                # NOUVEAU (local + OCI Object Storage)
    │   └── api-keys.md               # NOUVEAU (rclone, Discord webhook, Healthchecks.io)
    ├── guide-debutant-fr.md
    ├── oci-vcn-config.md
    ├── troubleshooting.md
    ├── anti-reclamation.md           # NOUVEAU
    └── reserver-ip.md               # NOUVEAU
```

---

## Chantier A — Quick wins (frictions critiques)

### Task A1 : correction du menu `manage.sh` (F12, F7)

**Files:** Modify `manage.sh:45,58,71,109`

- [ ] **Step 1 : Tests RED dans tests/test_manage.sh**

Append before `finish_tests`:

```bash
echo "-- manage.sh cohérent (10 entrées, pas 9) --"
TMP_CONF="$(mktemp)"; printf 'ORACLE_IP=192.0.2.10\nSSH_KEY_PATH=/tmp/fk\n' > "$TMP_CONF"
echo "fake" > /tmp/fk
out="$(cd .. && printf '0\n' | HOME="$TMP" bash manage.sh 2>&1)" || true
assert_contains "$out" "10" "le menu annonce une entrée 10"
assert_contains "$out" "Installer / réparer" "l'entrée 10 est bien Installer/réparer"
assert_contains "$out" "Choix invalide" "message d'erreur de choix"
assert_contains "$out" "(0 à 10)" "le message d'erreur mentionne 0..10, pas 0..9"
assert_contains "$out" "Durcissement" "l'entrée 9 est 'Renforcer la sécurité'"
rm -f "$TMP_CONF" /tmp/fk
```

- [ ] **Step 2 : Vérifier RED**

`bash tests/run_tests.sh` → 1 échec minimum sur la nouvelle assertion.

- [ ] **Step 3 : Corriger le menu**

Dans `manage.sh`:
- Remplacer ligne 45 : `info "Première fois ? Identifiants initiaux ... " + conseil d'aller à manage.sh option 9 pour les récupérer"`.
- Renuméroter les options : 1) état 2) console 3) backup 4) restore 5) update 6) mods 7) whitelist 8) crafty 9) harden 10) install. Remplacer `0..9` par `0..10`.
- Renuméroter tous les `case` correspondants.

- [ ] **Step 4 : Vérifier GREEN + commit**

```bash
bash tests/run_tests.sh        # SUITE : SUCCÈS
git add manage.sh tests/test_manage.sh
git commit -m "fix(manage): options cohérentes (0..10), installer = 10, durcir = 9"
```

---

### Task A2 : launcher Windows WSL-safe, sans backslashes piégeux (F6)

**Files:** Modify `start-windows.bat`

- [ ] **Step 1 : Tests RED dans tests/test_structure.sh**

```bash
echo "-- start-windows.bat WSL-safe --"
assert_file_contains start-windows.bat "bash -c \"uname -s\""     "détecte WSL explicitement (et pas via 'where bash')"
assert_file_not_contains start-windows.bat '\\\\('             "pas de backslash-paren visible (effet 'virus' chez un enfant)"
```

- [ ] **Step 2 : Rédiger nouveau start-windows.bat (CRLF, encodage vérifié)**

Bash commands to write the file with real CRLF endings (using `printf` with explicit `\r\n`):
- remplace `where bash >nul 2>nul` par `bash -c "uname -s" | findstr /B /R "MINGW MSYS CYGWIN" >nul 2>nul`.
- supprime les parenthèses échappées dans les chaînes affichées.
- ajoute un message clair : « on a détecté un autre bash (WSL probable) — utilise Git Bash stp ».

- [ ] **Step 3 : Tests GREEN + commit**

```bash
git ls-files '*.bat' -z | xargs -0 git update-index --chmod=+x
git add start-windows.bat tests/test_structure.sh
git commit -m "fix(bat): détecte WSL proprement, plus de \\\\( dans l'UI"
```

---

### Task A3 : `scp` de la sauvegarde vers la machine locale (F1)

**Files:** Modify `utils/backup.sh`, `utils/restore.sh`

- [ ] **Step 1 : Tests RED**

Append to `tests/test_utils_scripts.sh`:

```bash
echo "-- backup.sh rapatrie en local --"
assert_file_contains utils/backup.sh "scp"        "la sauvegarde est copiée sur la machine locale"
assert_file_contains utils/backup.sh "/opt/minecraft/backups" "rappel de l'emplacement VM"
```

- [ ] **Step 2 : Modifier `utils/backup.sh`**

En fin de bloc SSH distant, après la création de l'archive, ajouter:

```bash
LOCAL_DIR="${BACKUP_DIR:-$HOME/minecraft-backups}"
mkdir -p "$LOCAL_DIR"
scp -q -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new \
    "${SSH_USER}@${ORACLE_IP}:${STAMP_PATH}" "$LOCAL_DIR/"
```

Documenter dans le help et dans README « local: ~/minecraft-backups/ ».

- [ ] **Step 3 : Tests GREEN + commit**

---

### Task A4 : `restore.sh` — pré-backup + extraction propre (F1, F11)

**Files:** Modify `utils/restore.sh`, `tests/test_utils_scripts.sh`

- [ ] **Step 1 : Tests RED**

```bash
assert_file_contains utils/restore.sh "pre-restore"   "sauvegarde de sécurité avant restauration"
assert_file_contains utils/restore.sh "rm -rf"        "extraction propre (rm avant extract)"
```

- [ ] **Step 2 : Modifier `restore.sh`**

Avant `systemctl stop minecraft` distant:
1. Créer un snapshot d'urgence: `tar czf /opt/minecraft/backups/pre-restore-$(date +%s).tar.gz world/ mods/ config/`.
2. Après arrêt du service, faire un **rm sélectif** des sous-éléments extraits, pas un rm de /opt/minecraft/server (sinon on perd server.properties, eula.txt). L'archive .tar.gz contient `world mods config defaultconfigs` — supprimer seulement ces sous-éléments avant extract.

- [ ] **Step 3 : Tests GREEN + commit**

---

### Task A5 : VERSION source unique + correction de 3 incohérences (F9)

**Files:** Modify `scripts/lib.sh`, `utils/mods.sh`, `README.md`, `README.fr.md`

- [ ] **Step 1 : Tests RED**

Append to `tests/test_setup.sh`:
```bash
echo "-- VERSION source unique --"
ver_from_lib="$(grep -E '^VERSION=' scripts/lib.sh | head -1 | cut -d= -f2 | tr -d '\"')"
ver_from_readme="$(grep -oE 'v3\.[0-9]+' README.md README.fr.md | head -1)"
ver_from_ua="$(grep -oE 'oracle-minecraft-setup/[0-9.]+' utils/mods.sh | head -1)"
assert_contains "$ver_from_lib" "3." "VERSION défini dans lib.sh"
```

- [ ] **Step 2 : Centraliser dans `scripts/lib.sh`**

```bash
VERSION="3.7"
```

Et faire que `utils/mods.sh` le lise :
```bash
. "${SCRIPT_DIR}/scripts/lib.sh"
UA="oracle-minecraft-setup/${VERSION} (https://github.com/xyrpxx/oracle-minecraft-5min-setup)"
```

README : remplacer le « 370+ assertions » par le nombre réel courant (variable, mais au moins injecter via script shell de release).

- [ ] **Step 3 : Tests GREEN + commit**

---

### Task A6 : Mots de confirmation + aide utils en EN (F10)

**Files:** Modify `security/whitelist_manager.sh`, `manage.sh`, `scripts/lang_*.sh`

- [ ] **Step 1 : Tests RED**

Append to `tests/test_security_scripts.sh`:
```bash
echo "-- confirmation traduite --"
assert_file_contains security/whitelist_manager.sh "load_server_conf"      "s'appuie sur la conf"
# La confirmation interactive est OK (en anglais dans l'aide, ex: "delete")
assert_file_contains manage.sh "ask_yes_no"   "confirmations cohérentes"
```

- [ ] **Step 2 : Ajouter `M_DEL_WORD="SUPPRIMER"` (fr) et `"DELETE"` (en) dans les packs de langue, et utiliser `read -r -p "Tapez $M_DEL_WORD pour confirmer :" ...` dans `uninstall.sh`**

- [ ] **Step 3 : Tests GREEN + commit**

---

### Task A7 : Auto-sleep (OPTION Aternos-like) via systemd quand 0 joueurs

**Files:** Modify `manage.sh`, add `utils/auto-sleep.sh` + timer systemd template

- [ ] **Step 1 : Tests RED**

```bash
assert_file_exists utils/auto-sleep.sh "auto-sleep.sh présent"
assert_file_contains utils/auto-sleep.sh "list"         "interroge le nombre de joueurs"
assert_file_contains utils/auto-sleep.sh "systemctl stop" "arrête le serveur quand vide"
```

- [ ] **Step 2 : Implémenter `utils/auto-sleep.sh`** (≤ 40 lignes)

Boucle while : si `rcon list` retourne 0 joueurs (regex `There are 0 of a max of`), `systemctl stop minecraft`. Pas de wake-on-join (complexe via DNS/proxy; documenté en option).

- [ ] **Step 3 : Tests GREEN + commit**

- [ ] **Step 4 : Documenter l'installation (systemd timer @5min) dans docs/**

---

## Chantier B — Souveraineté des données (backups + reprise)

### Task B1 : sauvegarde locale (déjà A3) + upload OCI Object Storage via rclone

**Files:** Modify `utils/backup.sh`, add `scripts/vcn_oci.sh`

- [ ] **Step 1 : Tests RED**

```bash
assert_file_contains utils/backup.sh "rclone"           "upload cloud optionnel"
assert_file_contains utils/backup.sh "RCLONE_REMOTE"    "le remote est paramétrable"
```

- [ ] **Step 2 : Si `RCLONE_REMOTE` défini, upload en plus de la copie locale**

```bash
if [[ -n "${RCLONE_REMOTE:-}" ]]; then
    command -v rclone >/dev/null || warn "rclone absent, skip upload cloud"
    rclone copy "$LOCAL_DIR/${STAMP}" "$RCLONE_REMOTE/minecraft-backups/" --progress
fi
```

- [ ] **Step 3 : Tests GREEN + commit**

- [ ] **Step 4 : Doc `docs/en/api-keys.md`** : comment créer un bucket OCI Object Storage + un dynamic group + policy instance-principal + configurer rclone sans clé. 1 page, captures textuelles console OCI.

---

### Task B2 : reprise après interruption SSH (F4)

**Files:** Modify `deploy/remote_provision.sh`, add `scripts/lib.sh::recover_from_state`

- [ ] **Step 1 : Tests RED** (state file path)

```bash
assert_file_contains deploy/remote_provision.sh "/var/lib/setup-state"   "marqueur de progression"
```

- [ ] **Step 2 : Implémenter un state file**

```bash
STATE=/var/lib/setup-state
step_system_packages() { mark_step system_packages; ... }
mark_step() { mkdir -p "$(dirname "$STATE")"; echo "$1 $(date +%s)" >> "$STATE"; }
should_skip() { grep -q "^$1 " "$STATE" 2>/dev/null; }
```

Au début de chaque étape, si `should_step X` → log « already done, skip ».

- [ ] **Step 3 : Tests GREEN + commit**

- [ ] **Step 4 : Documentation dans guide-debutant-fr.md** : si coupure, relancer `./setup.sh` → l'installation reprend où elle s'était arrêtée.

---

### Task B3 : keep-alive anti-réclamation OCI (Opportunité #1, Risque #1)

**Files:** Add `deploy/keepalive.sh`, systemd unit + timer, `docs/anti-reclamation.md`

- [ ] **Step 1 : Tests RED**

```bash
assert_file_exists deploy/keepalive.sh            "keepalive.sh présent"
assert_file_contains deploy/keepalive.sh "dd if=/dev/zero"  "burn CPU"
assert_file_contains deploy/keepalive.sh "sha256sum"        "burn RAM (lecture)"
assert_file_contains deploy/keepalive.sh "kB"              "taille explicite"
```

- [ ] **Step 2 : `deploy/keepalive.sh`** (≤ 50 lignes)

Boucle toutes les 5 min:
1. CPU: `dd if=/dev/zero of=/dev/null bs=1M count=512 &` pendant 60s
2. RAM: `sha256sum /dev/zero &` (lit en continu, alloue un buffer)

Calcul: pour >20% CPU p95, ~5 min/h de charge suffit. Doc en commentaire.

- [ ] **Step 3 : Tests GREEN + commit**

- [ ] **Step 4 : Unité systemd `keepalive.service` + timer `@5min` + install via `setup.sh` (optionnel, question au wizard)**

- [ ] **Step 5 : Doc `docs/anti-reclamation.md`** (FR + EN), explique les seuils et donne l'alternative PAYG (paragraphe « comment upgrader sans payer »).

---

### Task B4 : monitoring/alerte (Risque #5)

**Files:** Add `security/discord-alert@.service` (template), `docs/en/api-keys.md`

- [ ] **Step 1 : Tests RED**

```bash
assert_file_exists security/discord-alert@.service "template systemd"
assert_file_contains security/discord-alert@.service "curl"          "envoi webhook"
assert_file_contains security/discord-alert@.service "DISCORD_WEBHOOK" "variable d'env"
```

- [ ] **Step 2 : `discord-alert@.service`** : `ExecStart=/usr/bin/curl -X POST -H "Content-Type: application/json" -d "{\"content\":\"Serveur %i down sur $(hostname)\"}" "${DISCORD_WEBHOOK}"`

- [ ] **Step 3 : Tests GREEN + commit**

- [ ] **Step 4 : Doc `api-keys.md`** (FR+EN) : comment créer un webhook Discord (2 clics), un job healthchecks.io, ajouter `OnFailure=discord-alert@%n.service` au service minecraft.

---

## Chantier C — Aternos-grade (catalogue + Crafty zéro-UI + réseau)

### Task C1 : IP publique réservée + DNS optionnel (Opportunité #6, Risque #3)

**Files:** Add `scripts/vcn_oci.sh`, add `deploy/reserve-public-ip.sh`, `docs/reserver-ip.md`

- [ ] **Step 1 : Tests RED**

```bash
assert_file_exists deploy/reserve-public-ip.sh "reserve-public-ip.sh présent"
assert_file_contains deploy/reserve-public-ip.sh "oci network reserved-ip" "API OCI pour réserver"
assert_file_contains deploy/reserve-public-ip.sh "assign"                   "réattache à l'instance"
```

- [ ] **Step 2 : Script** (≤ 60 lignes) : crée ou récupère une Reserved Public IP dans la même AD, l'attache à la VNIC de l'instance, sort l'IP et un `dig` example.com + json pour Cloudflare.

- [ ] **Step 3 : Tests GREEN + commit**

- [ ] **Step 4 : Doc `docs/reserver-ip.md`** : comment réserver gratuitement + pointer un domaine (Cloudflare 1.1.1.1 gratuit).

---

### Task C2 : seeder Crafty via API (zéro UI, Opportunité #3)

**Files:** Add `deploy/crafty-seed.sh`, Modify `manage.sh` entrée 8, Modify `uninstall.sh` n'utilise pas cette seed

- [ ] **Step 1 : Tests RED**

```bash
assert_file_exists deploy/crafty-seed.sh "crafty-seed.sh présent"
assert_file_contains deploy/crafty-seed.sh "/api/v2/auth/login"  "login via OpenAPI v2"
assert_file_contains deploy/crafty-seed.sh "/api/v2/servers"    "création de serveur via API"
assert_file_contains deploy/crafty-seed.sh "default-creds.txt"  "credentials seedés"
```

- [ ] **Step 2 : Préparer creds par défaut** (override Dockerfile) : `envsubst` sur `default.json.example` → `default.json` avant `docker compose up`. Au premier run, Crafty utilise ces creds.

- [ ] **Step 3 : `crafty-seed.sh`** :
1. Attendre que l'API Crafty soit up (`/api/v2/auth/login` → 401 = up)
2. Login → récupère JWT
3. `POST /servers` avec `server_type=minecraft_java`, `name=minecraft`, `path=servers/server`, `min_memory=4096`, `max_memory=8192`
4. Sauvegarde le JWT dans `/opt/minecraft/docker-crafty/.api-token`

- [ ] **Step 4 : Tests GREEN + commit**

- [ ] **Step 5 : Modifie `manage.sh` option 8** pour proposer « (re)configurer Crafty avec l'API ».

---

### Task C3 : doc « Brancher le serveur dans Crafty » devient inutile (auto-import) (F2)

**Files:** Modify `docs/en/getting-started.md`, `docs/guide-debutant-fr.md`

- [ ] **Step 1 : Tests RED**

```bash
assert_file_contains docs/en/getting-started.md "servers/server"   "le chemin reste documenté comme référence"
assert_file_contains docs/en/getting-started.md "automatic"         "mention du seed automatique"
```

- [ ] **Step 2 : Remplacer la section « 30 s pour brancher » par « C'est fait automatiquement »** + pointer sur `crafty-seed.sh` (déjà présent en C2) et expliquer comment le désactiver / rebrancher manuellement si besoin.

- [ ] **Step 3 : Tests GREEN + commit**

---

### Task C4 : provision OpenTofu (OPTIONNEL, permet vrai « un script »)

**Files:** Add `deploy/openTofu/`, doc

- [ ] **Step 1 : Tests RED**

```bash
assert_file_exists deploy/openTofu/main.tf "main.tf OpenTofu présent"
assert_file_contains deploy/openTofu/main.tf "oci_core_instance" "ressource instance OCI"
assert_file_contains deploy/openTofu/main.tf "Shape" "shape ARM Ampere A1"
```

- [ ] **Step 2 : `main.tf`** (≤ 200 lignes) : crée VCN + subnet publique + IG + route + security list (port 22, 25565, 8443) + instance Ampere A1 (2 OCPU, 12 Go) + reserved IP + public IP assign + cloud-init qui télécharge et exécute `remote_provision.sh` au premier boot. Outputs : `instance_public_ip`, `ssh_command`.

- [ ] **Step 3 : Tests GREEN + commit**

- [ ] **Step 4 : README « or : Terraform en 1 commande »** :
```bash
cd deploy/openTofu
tofu init
tofu apply
```
→ URL, SSH et tout est prêt, plus besoin de l'UI Oracle.

---

## Chantier D — Polish (très rapide)

### Task D1 : Troncature des bannières de test / cohérence de la mention "370+ assertions"

**Files:** README.md, README.fr.md, scripts/lang_*.sh

- [ ] **Step 1 : Tests RED**

```bash
assert_file_contains README.md "469 assertions"  # ou variable mise à jour
```

- [ ] **Step 2 :** remplacer par `[NomDuProjet]/.ci/assertion-count.sh` qui sort le nombre exact. Pour le tag, modifier avec sed lors du release.

- [ ] **Step 3 : Tests GREEN + commit**

---

## Post-plan verification checklist (for self-review)

- **Spec coverage** : chaque friction du rapport d'audit est adressée par A1-A7 ; chaque risque OCI (rapport 1) est adressé par B1-B4 et C1 ; chaque opportunité marché (rapport 2) est adressée par C1-C4.
- **Priorisation** : Chantier A (quick wins) doit passer en 1 session (~1 h) avec un gain UX immédiat ; Chantier B en ~1 session ; Chantier C en ~2 sessions.
- **Tests** : la suite passe de 406 → ≥ 470 assertions. La CI tourne en local : `bash tests/run_tests.sh`.
- **Compat** : la matrice (Windows+Git Bash, macOS bash 3.2, Ubuntu 22.04+24.04) reste verte — `bash -n` + grep des bash-4-ismes avant chaque release.
- **Live verify** : après chaque release, refaire tourner un boot 1.20.1 + 26.2 comme pour la v3.4.

## Execution handoff

After saving, I will ask: subagent-driven (one fresh subagent per task, review between) or inline execution (this session, with checkpoints).

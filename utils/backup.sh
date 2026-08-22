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
# KEEP est interpolé dans une commande SSH distante : entier strict uniquement.
[[ "$KEEP" =~ ^[0-9]+$ ]] || die "KEEP doit être un entier (ex. KEEP=14 ./utils/backup.sh)."
(( 10#$KEEP >= 1 )) || die "KEEP doit être supérieur ou égal à 1."
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
if [[ ${#ITEMS[@]} -eq 0 ]]; then
    echo "[backup] ERREUR : rien à sauvegarder dans ${SERVER_DIR}." >&2
    exit 1
fi
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

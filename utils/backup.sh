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

# Dossier local de rapatriement (par défaut ~/minecraft-backups).
# Utiliser --local-dir <path> ou LOCAL_DIR=<path> pour changer.
LOCAL_DIR="${LOCAL_DIR:-$HOME/minecraft-backups}"
case "${1:-}" in
    --local-dir) LOCAL_DIR="${2:-}"; shift 2 ;;
esac
mkdir -p "$LOCAL_DIR" 2>/dev/null || warn "Impossible de créer $LOCAL_DIR — sauvegarde locale ignorée."

STAMP_PATH=""
out="$(run_ssh "sudo bash -s -- ${KEEP}" <<'REMOTE'
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
echo "STAMP_PATH:${BACKUP_DIR}/${STAMP}"
REMOTE
)"

# Affiche la sortie distante pour transparence
printf '%s\n' "$out"

# Récupère le chemin de l'archive distante (marqueur STAMP_PATH:...)
STAMP_PATH="$(printf '%s\n' "$out" | sed -n 's/^STAMP_PATH:\(.*\)$/\1/p' | head -1)"
[[ -n "$STAMP_PATH" ]] || die "Impossible de récupérer le chemin de l'archive distante."

success "Sauvegarde terminée sur ${ORACLE_IP}."

# --- Rapatriement local (sécurité anti-réclamation / OCI) ---
echo
info "Rapatriement local vers ${LOCAL_DIR} ..."
if scp -q -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=accept-new \
    "${SSH_USER}@${ORACLE_IP}:${STAMP_PATH}" "${LOCAL_DIR}/" 2>/dev/null; then
    success "Copie locale OK : ${LOCAL_DIR}/$(basename "${STAMP_PATH}")"
else
    warn "Rapatriement local impossible. La sauvegarde reste sur ${ORACLE_IP}:${STAMP_PATH}"
fi
info "Astuce : la VM Oracle peut être révoquée à tout moment. Garde TOUJOURS une copie locale."

# --- (Optionnel) Upload vers OCI Object Storage via rclone ---
# Set OCI_BUCKET=oci://my-bucket@namespace/backups pour activer.
# Toujours en best-effort : si rclone n'est pas dispo, on ne casse rien.
if [[ -n "${OCI_BUCKET:-}" ]]; then
    echo
    info "Upload vers OCI Object Storage (${OCI_BUCKET}) ..."
    if command -v rclone >/dev/null 2>&1; then
        OCI_BASENAME="$(basename "$STAMP_PATH")"
        if rclone copyto "${LOCAL_DIR}/${OCI_BASENAME}" "${OCI_BUCKET}/${OCI_BASENAME}" 2>/dev/null; then
            success "Sauvegarde uploadée sur OCI Object Storage."
        else
            warn "Échec upload OCI : la copie locale reste disponible."
        fi
    else
        warn "rclone n'est pas installé. Installation : https://rclone.org/install/"
    fi
fi

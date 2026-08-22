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

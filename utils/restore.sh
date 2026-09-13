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

# Boucle while portable (compatible macOS bash 3.2)
ARCHIVES=()
while IFS= read -r line; do
    ARCHIVES+=("$line")
done <<< "$LISTING"
[[ ${#ARCHIVES[@]} -gt 0 ]] || die "Aucune archive trouvée dans /opt/minecraft/backups/."

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

run_ssh "sudo bash -s -- '${ARCHIVE_NAME}'" <<'REMOTE'
set -euo pipefail
NAME="$1"
SERVER_DIR=/opt/minecraft/server
BACKUP_DIR=/opt/minecraft/backups

# 1. Pré-restauration : on capture l'état actuel en cas de pépin
PRE_STAMP="pre-restore-$(date +%Y%m%d-%H%M%S).tar.gz"
ITEMS=()
cd "$SERVER_DIR"
for p in world world_nether world_the_end mods config defaultconfigs \
         serverconfig kubejs server.properties whitelist.json user_jvm_args.txt; do
    [[ -e "$p" ]] && ITEMS+=("$p")
done
if [[ ${#ITEMS[@]} -gt 0 ]]; then
    tar czf "${BACKUP_DIR}/${PRE_STAMP}" "${ITEMS[@]}" \
        && echo "[restore] Sauvegarde de sécurité : ${BACKUP_DIR}/${PRE_STAMP}" \
        || echo "[restore] WARN: pré-restauration échouée, on continue."
fi

# 2. Arrêt du service
systemctl stop minecraft

# 3. Nettoyage sélectif : on ne supprime QUE les sous-éléments présents
#    dans l'archive (server.properties, eula.txt, .rcon-credentials préservés)
#    Cela évite qu'un ancien monde / mod de l'archive ne se mélange à l'existant.
#    Les entrées sont validées : pas de chemin absolu, pas de '..', pas de
#    glob — une archive hostile ne doit jamais supprimer hors du serveur.
ARCHIVE="${BACKUP_DIR}/${NAME}"
set -f # désactive le globbing pour la boucle ci-dessous
map_to_remove="$(tar tzf "$ARCHIVE" 2>/dev/null | awk -F/ '{print $1}' | sort -u)"
while IFS= read -r entry; do
    case "$entry" in
        ""|"."|".."|/*|*".."*) continue ;;
    esac
    # Noms simples uniquement (lettres, chiffres, . _ -) pour rm -rf.
    [[ "$entry" =~ ^[A-Za-z0-9._-]+$ ]] || continue
    [[ -e "${SERVER_DIR}/${entry}" ]] && rm -rf -- "${SERVER_DIR:?}/${entry}"
done <<< "$map_to_remove"
set +f

# 4. Extraction propre
cd "$SERVER_DIR"
tar xzf "$ARCHIVE"

# 5. Permissions et redémarrage
chown -R minecraft:minecraft "$SERVER_DIR"
systemctl start minecraft
echo "[restore] Restauration terminée."
REMOTE

info "Attente du redémarrage (jusqu'à 2 minutes)..."
sleep 10
if run_ssh "ss -tln | grep -q ':25565 '"; then
    success "Serveur restauré et en écoute sur ${ORACLE_IP}:25565."
else
    warn "Le port 25565 n'est pas encore en écoute — vérifiez : ssh ${SSH_USER}@${ORACLE_IP} 'journalctl -u minecraft -n 30'"
fi

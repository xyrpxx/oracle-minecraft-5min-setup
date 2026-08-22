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

#!/usr/bin/env bash
# =============================================================================
# manage.sh — LE menu unique de gestion du serveur (exécuté LOCALEMENT).
#
# Un seul point d'entrée pour tout faire, comme sur Aternos mais en mieux :
#   - côté navigateur : le panel Crafty (bouton 7)
#   - côté terminal   : ce menu (état, commandes, sauvegardes, maj, ...)
#
# Usage : bash manage.sh   (ou ./manage.sh)
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

# La configuration locale peut ne pas exister avant le premier setup :
# on l'accepte et on le signale gentiment.
HAVE_CONF="false"
if [[ -f "${SCRIPT_DIR}/.server.conf" ]]; then
    HAVE_CONF="true"
    load_server_conf "${SCRIPT_DIR}/.server.conf"
fi

pause_menu() {
    echo
    info "Appuie sur Entrée pour revenir au menu…"
    read -r _ || true
}

run_action() { # script [args...]
    local s="$1"; shift
    echo
    bash "$s" "$@" || warn "L'action s'est terminée avec une erreur (voir au-dessus)."
    pause_menu
}

open_crafty() {
    if [[ "$HAVE_CONF" != "true" ]]; then
        warn "Lance d'abord ./setup.sh — le panel n'existe pas encore."
        pause_menu
        return 0
    fi
    echo
    info "Ouverture de https://${ORACLE_IP}:8443 (accepte l'avertissement de certificat)."
    info "Première fois ? Identifiants initiaux : ssh ${SSH_USER:-ubuntu}@${ORACLE_IP} 'sudo docker logs crafty_controller'"
    info "Puis dans Crafty : Import Server → dossier servers/server (30 secondes, guide dans docs/)."
    open_url "https://${ORACLE_IP}:8443" || info "Adresse du panel : https://${ORACLE_IP}:8443"
    pause_menu
}

while true; do
    clear 2>/dev/null || true
    echo "════════════════════════════════════════════════════════════"
    echo "          GESTION DU SERVEUR MINECRAFT — MENU"
    if [[ "$HAVE_CONF" == "true" ]]; then
        echo "          Serveur : ${ORACLE_IP}:25565"
    else
        echo "          (aucun serveur configuré — commence par le 9)"
    fi
    echo "════════════════════════════════════════════════════════════"
    echo
    echo "   1) Voir l'état (CPU, RAM, joueurs, TPS)"
    echo "   2) Envoyer une commande de jeu (op, say, time set…)"
    echo "   3) Sauvegarder le monde"
    echo "   4) Restaurer une sauvegarde"
    echo "   5) Mettre à jour (Minecraft / Forge / modpack)"
    echo "   6) Gérer la whitelist (serveur privé)"
    echo "   7) Ouvrir le panel web Crafty (façon Aternos, dans le navigateur)"
    echo "   8) Renforcer la sécurité de la machine"
    echo "   9) Installer / réparer le serveur (relance setup.sh)"
    echo "   0) Quitter"
    echo
    read -r -p "→ Ton choix : " choice || break
    case "$choice" in
        1) run_action "${SCRIPT_DIR}/utils/monitor.sh" ;;
        2) echo
           read -r -p "→ Commande à envoyer (ex. \"op TonPseudo\") : " cmd
           if [[ -n "$cmd" ]]; then
               run_action "${SCRIPT_DIR}/utils/console.sh" "$cmd"
           else
               warn "Commande vide — rien envoyé."
               pause_menu
           fi ;;
        3) run_action "${SCRIPT_DIR}/utils/backup.sh" ;;
        4) run_action "${SCRIPT_DIR}/utils/restore.sh" ;;
        5) run_action "${SCRIPT_DIR}/utils/update.sh" ;;
        6) echo
           read -r -p "→ Action whitelist (add Pseudo / remove Pseudo / list) : " wl
           if [[ -n "$wl" ]]; then
               # shellcheck disable=SC2086
               run_action "${SCRIPT_DIR}/security/whitelist_manager.sh" $wl
           else
               warn "Format : add Pseudo, remove Pseudo ou list."
               pause_menu
           fi ;;
        7) open_crafty ;;
        8) run_action "${SCRIPT_DIR}/security/hardening.sh" ;;
        9) echo
           info "Relance de l'installation (sans danger : elle préserve le monde)."
           bash "${SCRIPT_DIR}/setup.sh" || warn "setup.sh s'est arrêté avec une erreur (voir au-dessus)."
           if [[ -f "${SCRIPT_DIR}/.server.conf" ]]; then
               HAVE_CONF="true"
               load_server_conf "${SCRIPT_DIR}/.server.conf"
           fi
           pause_menu ;;
        0) break ;;
        *) warn "Choix invalide (0 à 9)." ;;
    esac
done

echo
info "À bientôt sur ton serveur ! 🎮"

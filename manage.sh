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

# Sous-menu OCI (option 9) : durcir, activer keepalive, auto-sleep.
oci_submenu() {
    while true; do
        echo
        info "Optimisations OCI (anti-réclamation + sécurité) :"
        echo "   a) Durcir SSH (PermitRootLogin no, fail2ban, unattended-upgrades)"
        echo "   b) Activer le keepalive (brûle CPU pour rester au-dessus de 20% p95)"
        echo "   c) Activer l'auto-stop (arrête le serveur après 30 min sans joueur)"
        echo "   d) Configurer une alerte Discord sur échec"
        echo "   q) Retour au menu principal"
        read -r -p "→ Ton choix : " sub || break
        case "$sub" in
            a) run_action "${SCRIPT_DIR}/security/hardening.sh" ;;
            b) cat <<'TIP'
[EN] Install on the VM (one-time) :
   sudo cp security/keepalive.sh /opt/minecraft/bin/
   sudo tee /etc/systemd/system/keepalive.service >/dev/null <<'EOF'
[Unit]
Description=Burn CPU to stay above OCI Always Free idle threshold
[Service]
ExecStart=/opt/minecraft/bin/keepalive.sh
Restart=always
[Install]
WantedBy=multi-user.target
EOF
   sudo systemctl enable --now keepalive.service
[FR] Installation sur la VM (une seule fois) :
   (mêmes commandes, voir security/keepalive.sh en tête de fichier)
TIP
               pause_menu ;;
            c) cat <<'TIP'
[EN] Install on the VM (one-time) :
   sudo cp utils/auto-sleep.sh /opt/minecraft/bin/
   sudo tee /etc/systemd/system/auto-sleep.{service,timer} >/dev/null
   (templates dans le commentaire en tête de utils/auto-sleep.sh)
   sudo systemctl enable --now auto-sleep.timer
[FR] Installation sur la VM : voir utils/auto-sleep.sh (commentaire en tête).
TIP
               pause_menu ;;
            d) cat <<'TIP'
[EN] 1. Create a Discord webhook on your server (Channel → Edit → Integrations).
     2. On the VM: echo 'DISCORD_WEBHOOK=https://discord.com/api/webhooks/...' \
                    | sudo tee /opt/minecraft/.env
     3. sudo cp security/discord-alert@.service /etc/systemd/system/
     4. sudo systemctl edit minecraft.service → add OnFailure=discord-alert@%n.service
[FR] 1. Crée un webhook Discord (Salon → Paramètres → Intégrations).
     2. Sur la VM : echo 'DISCORD_WEBHOOK=...' | sudo tee /opt/minecraft/.env
     3. sudo cp security/discord-alert@.service /etc/systemd/system/
     4. sudo systemctl edit minecraft.service → ajoute OnFailure=discord-alert@%n.service
TIP
               pause_menu ;;
            q|0) break ;;
            *) warn "Choix invalide." ;;
        esac
    done
}

while true; do
    clear 2>/dev/null || true
    echo "════════════════════════════════════════════════════════════"
    echo "          GESTION DU SERVEUR MINECRAFT — MENU"
    if [[ "$HAVE_CONF" == "true" ]]; then
        echo "          Serveur : ${ORACLE_IP}:25565"
    else
        echo "          (aucun serveur configuré — lance ./setup.sh d'abord)"
    fi
    echo "════════════════════════════════════════════════════════════"
    echo
    echo "   1) Voir l'état (CPU, RAM, joueurs, TPS)"
    echo "   2) Envoyer une commande de jeu (op, say, time set…)"
    echo "   3) Sauvegarder le monde"
    echo "   4) Restaurer une sauvegarde"
    echo "   5) Mettre à jour (Minecraft / Forge / modpack)"
    echo "   6) Installer des mods / un modpack (recherche Modrinth intégrée)"
    echo "   7) Gérer la whitelist (serveur privé)"
    echo "   8) Ouvrir le panel web Crafty (façon Aternos, dans le navigateur)"
    echo "   9) Optimisations OCI (sécurité, keepalive, auto-stop, alertes Discord)"
    echo "  10) Installer / réparer le serveur (relance setup.sh)"
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
        6) run_action "${SCRIPT_DIR}/utils/mods.sh" ;;
        7) echo
           read -r -p "→ Action whitelist (add Pseudo / remove Pseudo / list) : " wl
           if [[ -n "$wl" ]]; then
               # shellcheck disable=SC2086
               run_action "${SCRIPT_DIR}/security/whitelist_manager.sh" $wl
           else
               warn "Format : add Pseudo, remove Pseudo ou list."
               pause_menu
           fi ;;
        8) open_crafty ;;
        9) oci_submenu ;;
        10) echo
           info "Relance de l'installation (sans danger : elle préserve le monde)."
           bash "${SCRIPT_DIR}/setup.sh" || warn "setup.sh s'est arrêté avec une erreur (voir au-dessus)."
           if [[ -f "${SCRIPT_DIR}/.server.conf" ]]; then
               HAVE_CONF="true"
               load_server_conf "${SCRIPT_DIR}/.server.conf"
           fi
           pause_menu ;;
        0) break ;;
        *) warn "Choix invalide (0 à 10)." ;;
    esac
done

echo
info "À bientôt sur ton serveur ! 🎮"

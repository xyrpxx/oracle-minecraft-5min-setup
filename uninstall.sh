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

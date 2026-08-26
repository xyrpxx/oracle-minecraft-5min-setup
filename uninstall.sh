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

# Langue : autodétection, surchargeable par --lang fr|en
UI_LANG="${LC_ALL:-${LANG:-}}"
UI_LANG="${UI_LANG%%_*}"
case "$UI_LANG" in fr) UI_LANG=fr ;; *) UI_LANG=en ;; esac
while [[ $# -gt 0 ]]; do
    case "$1" in
        --lang) UI_LANG="$2"; shift 2 ;;
        *) shift ;;
    esac
done
# shellcheck source=scripts/lang_fr.sh
# shellcheck source=scripts/lang_en.sh
. "${SCRIPT_DIR}/scripts/lang_${UI_LANG}.sh"

load_server_conf "${SCRIPT_DIR}/.server.conf"

echo
if [[ "$UI_LANG" == "fr" ]]; then
    warn "Cette action supprime le serveur Minecraft, ses mondes et Crafty sur ${ORACLE_IP}."
    warn "La VM Oracle reste en place (à supprimer depuis la console OCI si souhaité)."
else
    warn "This will delete the Minecraft server, worlds and Crafty on ${ORACLE_IP}."
    warn "The Oracle VM itself stays in place (terminate it from the OCI console if needed)."
fi
echo
read -r -p "${M_DEL_TIP} " confirmation
[[ "$confirmation" == "${M_DEL_WORD}" ]] || { info "${M_DEL_CANCEL}"; exit 0; }

if ask_yes_no "${M_DEL_LAST_BACKUP}" "n"; then
    bash "${SCRIPT_DIR}/utils/backup.sh"
fi

run_ssh "bash -s" <<'REMOTE'
set -uo pipefail

echo "[uninstall] Stopping the minecraft service..."
systemctl disable --now minecraft 2>/dev/null || true
rm -f /etc/systemd/system/minecraft.service
systemctl daemon-reload

echo "[uninstall] Stopping Crafty Controller..."
if [[ -d /opt/minecraft/docker-crafty ]]; then
    ( cd /opt/minecraft/docker-crafty && docker compose down ) 2>/dev/null || true
fi

echo "[uninstall] Removing iptables rules..."
iptables -D INPUT -p tcp --dport 25565 -m conntrack --ctstate NEW -j ACCEPT 2>/dev/null || true
iptables -D INPUT -p udp --dport 25565 -m conntrack --ctstate NEW -j ACCEPT 2>/dev/null || true
iptables -D INPUT -p tcp --dport 8443  -m conntrack --ctstate NEW -j ACCEPT 2>/dev/null || true
netfilter-persistent save 2>/dev/null || true

echo "[uninstall] Removing files and user..."
rm -rf /opt/minecraft
if id -u minecraft >/dev/null 2>&1; then
    userdel minecraft 2>/dev/null || true
fi

echo "[uninstall] VM cleaned."
REMOTE

rm -f "${SCRIPT_DIR}/.server.conf"
if [[ "$UI_LANG" == "fr" ]]; then
    success "Désinstallation terminée. Pensez à supprimer la VM depuis la console Oracle si vous n'en avez plus besoin."
else
    success "Uninstall done. Remember to terminate the VM from the Oracle console if you no longer need it."
fi

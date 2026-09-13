#!/usr/bin/env bash
# =============================================================================
# manage.sh — LE menu unique de gestion du serveur (exécuté LOCALEMENT).
#
# Un seul point d'entrée pour tout faire, comme sur Aternos mais en mieux :
#   - côté navigateur : le panel Crafty (bouton 8)
#   - côté terminal   : ce menu (état, commandes, sauvegardes, maj, ...)
#
# Usage : bash manage.sh [--lang fr|en]   (ou ./manage.sh)
# La langue est auto-détectée (comme setup.sh), surchargeable par --lang.
# Tous les textes visibles viennent de scripts/lang_*.sh (aucun dur).
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

# Langue : autodétection, surchargeable par --lang fr|en (même motif que setup.sh).
UI_LANG="${LC_ALL:-${LANG:-}}"
UI_LANG="${UI_LANG%%_*}"
case "$UI_LANG" in fr) UI_LANG=fr ;; *) UI_LANG=en ;; esac
for arg in "$@"; do
    case "$arg" in
        --lang=fr) UI_LANG=fr ;;
        --lang=en) UI_LANG=en ;;
    esac
done
if [[ "${1:-}" == "--lang" && -n "${2:-}" ]]; then
    case "$2" in
        fr|en) UI_LANG="$2" ;;
        *) printf '[ERROR] --lang expects fr or en\n' >&2; exit 1 ;;
    esac
fi
# shellcheck source=scripts/lang_fr.sh
# shellcheck source=scripts/lang_en.sh
. "${SCRIPT_DIR}/scripts/lang_${UI_LANG}.sh"

# La configuration locale peut ne pas exister avant le premier setup :
# on l'accepte et on le signale gentiment.
HAVE_CONF="false"
if [[ -f "${SCRIPT_DIR}/.server.conf" ]]; then
    HAVE_CONF="true"
    load_server_conf "${SCRIPT_DIR}/.server.conf"
fi

pause_menu() {
    echo
    info "$M_MENU_BACK"
    read -r _ || true
}

run_action() { # script [args...]
    local s="$1"; shift
    echo
    bash "$s" "$@" || warn "$M_MENU_ACTERR"
    pause_menu
}

open_crafty() {
    if [[ "$HAVE_CONF" != "true" ]]; then
        warn "$M_CRAFTY_NOCONF"
        pause_menu
        return 0
    fi
    echo
    # shellcheck disable=SC2059
    printf "${BLUE}[INFO]${NC} $(printf "$M_CRAFTY_OPEN" "${ORACLE_IP}")\n"
    # shellcheck disable=SC2059
    printf "${BLUE}[INFO]${NC} $(printf "$M_CRAFTY_FIRST" "${SSH_USER:-ubuntu}" "${ORACLE_IP}")\n"
    info "$M_CRAFTY_IMPORT"
    open_url "https://${ORACLE_IP}:8443" \
        || printf "${BLUE}[INFO]${NC} $(printf "$M_CRAFTY_ADDR" "${ORACLE_IP}")\n"
    pause_menu
}

# Sous-menu OCI (option 9) : durcir, activer keepalive, auto-sleep.
# keepalive (b) et auto-stop (c) sont MUTUELLEMENT EXCLUSIFS :
# keepalive simule de l'activité (anti-réclamation), auto-sleep éteint
# le serveur vide (économie). Les deux ensemble se contredisent.
oci_submenu() {
    install_remote_file() { # $1 = fichier local, $3 = nom distant dans /tmp
        [[ "$HAVE_CONF" == "true" ]] || { warn "$M_OCI_NOCONF"; return 1; }
        scp -q -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=accept-new \
            "${SCRIPT_DIR}/$1" "${SSH_USER}@${ORACLE_IP}:/tmp/$3" \
            || { warn "$M_OCI_SENDFAIL"; return 1; }
    }
    while true; do
        echo
        info "$M_OCI_TITLE"
        echo "   a) $M_OCI_A"
        echo "   b) $M_OCI_B"
        echo "      $M_OCI_B_WARN"
        echo "   c) $M_OCI_C"
        echo "      $M_OCI_C_WARN"
        echo "   d) $M_OCI_D"
        echo "   e) $M_OCI_E"
        echo "   q) $M_OCI_Q"
        read -r -p "→ ${M_OCI_CHOICE}" sub || break
        case "$sub" in
            a) run_action "${SCRIPT_DIR}/security/hardening.sh" ;;
            b) if [[ "$HAVE_CONF" != "true" ]]; then
                   warn "$M_OCI_NOCONF"
               else
                   warn "$M_OCI_KEEP_WARN"
                   # shellcheck disable=SC2059
                   if ask_yes_no "$(printf "$M_OCI_KEEP_Q" "${ORACLE_IP}")" "n"; then
                       install_remote_file "security/keepalive.sh" "" "keepalive.sh" && \
                       run_ssh "sudo install -m 755 /tmp/keepalive.sh /opt/minecraft/bin/keepalive.sh && \
sudo tee /etc/systemd/system/keepalive.service >/dev/null <<'EOF'
[Unit]
Description=Burn CPU to stay above OCI Always Free idle threshold
[Service]
ExecStart=/opt/minecraft/bin/keepalive.sh
Nice=19
CPUWeight=10
CPUQuota=30%
MemoryMax=256M
Restart=always
RestartSec=60
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable --now keepalive.service" \
                           && success "$M_OCI_KEEP_OK" \
                           || warn "$M_OCI_FAIL"
                   else
                       info "$M_OCI_CANCEL"
                   fi
               fi
               pause_menu ;;
            c) if [[ "$HAVE_CONF" != "true" ]]; then
                   warn "$M_OCI_NOCONF"
               else
                   warn "$M_OCI_SLEEP_WARN"
                   # shellcheck disable=SC2059
                   if ask_yes_no "$(printf "$M_OCI_SLEEP_Q" "${ORACLE_IP}")" "n"; then
                       install_remote_file "utils/auto-sleep.sh" "" "auto-sleep.sh" && \
                       run_ssh "sudo install -m 755 /tmp/auto-sleep.sh /opt/minecraft/bin/auto-sleep.sh && \
sudo tee /etc/systemd/system/auto-sleep.service >/dev/null <<'EOF'
[Unit]
Description=Stop Minecraft when no players are online
[Service]
Type=oneshot
ExecStart=/opt/minecraft/bin/auto-sleep.sh
[Install]
WantedBy=multi-user.target
EOF
sudo tee /etc/systemd/system/auto-sleep.timer >/dev/null <<'EOF'
[Unit]
Description=Check Minecraft idle every 5 minutes
[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
EOF
sudo systemctl enable --now auto-sleep.timer" \
                           && success "$M_OCI_SLEEP_OK" \
                           || warn "$M_OCI_FAIL"
                   else
                       info "$M_OCI_CANCEL"
                   fi
               fi
               pause_menu ;;
            d) if [[ "$HAVE_CONF" != "true" ]]; then
                   warn "$M_OCI_NOCONF"
               else
                   echo
                   info "$M_OCI_HOOK_1"
                   read -r -p "→ ${M_OCI_HOOK_Q}" hook
                   if [[ -z "$hook" ]]; then
                       info "$M_OCI_CANCEL"
                   elif [[ "$hook" != https://discord.com/api/webhooks/* && "$hook" != https://discordapp.com/api/webhooks/* ]]; then
                       warn "$M_OCI_HOOK_BAD"
                   else
                       # Le secret voyage en base64 comme argument positionnel :
                       # aucun caractère ne peut être réinterprété par le shell distant.
                       HOOK_B64="$(printf '%s' "$hook" | base64 | tr -d '\n')"
                       install_remote_file "security/discord-alert@.service" "" "discord-alert@.service" && \
                       run_ssh "sudo bash -s -- '${HOOK_B64}'" <<'REMOTE_EOF'
set -euo pipefail
HOOK="$(printf '%s' "$1" | base64 -d)"
sudo install -m 644 /tmp/discord-alert@.service /etc/systemd/system/discord-alert@.service
printf 'DISCORD_WEBHOOK=%s\n' "$HOOK" | sudo tee /opt/minecraft/.env >/dev/null
sudo chmod 600 /opt/minecraft/.env
sudo mkdir -p /etc/systemd/system/minecraft.service.d
printf '[Unit]\nOnFailure=discord-alert@%%n.service\n' | sudo tee /etc/systemd/system/minecraft.service.d/discord.conf >/dev/null
sudo systemctl daemon-reload
REMOTE_EOF
                       if [[ $? -eq 0 ]]; then
                           success "$M_OCI_HOOK_OK"
                       else
                           warn "$M_OCI_FAIL"
                       fi
                   fi
               fi
               pause_menu ;;
            e) if [[ "$HAVE_CONF" != "true" ]]; then
                   warn "$M_OCI_NOCONF"
               else
                   echo
                   info "$M_OCI_SEED_INFO"
                   info "$M_OCI_SEED_PASS"
                   info "  ssh ${SSH_USER}@${ORACLE_IP} 'sudo docker logs crafty_controller'"
                   read -r -p "→ ${M_OCI_SEED_Q}" crafty_pass
                   if [[ -z "$crafty_pass" ]]; then
                       info "$M_OCI_CANCEL"
                   else
                       # Mot de passe en base64 (argument positionnel) : aucun caractère
                       # collé par l'utilisateur ne peut être réinterprété à distance.
                       PASS_B64="$(printf '%s' "$crafty_pass" | base64 | tr -d '\n')"
                       install_remote_file "deploy/crafty-seed.sh" "" "crafty-seed.sh" && \
                       run_ssh "sudo bash -s -- '${PASS_B64}' '${ORACLE_IP}'" <<'REMOTE_EOF'
set -euo pipefail
PASS="$(printf '%s' "$1" | base64 -d)"
PUB_IP="$2"
sudo install -m 755 /tmp/crafty-seed.sh /opt/minecraft/bin/crafty-seed.sh
printf 'CRAFTY_ADMIN_PASSWORD=%s\n' "$PASS" | sudo tee /opt/minecraft/.env >/dev/null
sudo chmod 600 /opt/minecraft/.env
sudo CRAFTY_PUBLIC_IP="$PUB_IP" /opt/minecraft/bin/crafty-seed.sh
REMOTE_EOF
                       if [[ $? -eq 0 ]]; then
                           # shellcheck disable=SC2059
                           printf "${GREEN}${OK_TAG:-[OK]}${NC} $(printf "$M_OCI_SEED_OK" "${ORACLE_IP}")\n"
                       else
                           warn "$M_OCI_SEED_FAIL"
                       fi
                   fi
               fi
               pause_menu ;;
            q|0) break ;;
            *) warn "$M_OCI_BAD" ;;
        esac
    done
}

while true; do
    clear 2>/dev/null || true
    echo "════════════════════════════════════════════════════════════"
    echo "          ${M_MENU_TITLE}"
    if [[ "$HAVE_CONF" == "true" ]]; then
        echo "          Serveur : ${ORACLE_IP}:25565"
    else
        echo "          ${M_MENU_NOCONF}"
    fi
    echo "════════════════════════════════════════════════════════════"
    echo
    echo "   1) ${M_MENU_1}"
    echo "   2) ${M_MENU_2}"
    echo "   3) ${M_MENU_3}"
    echo "   4) ${M_MENU_4}"
    echo "   5) ${M_MENU_5}"
    echo "   6) ${M_MENU_6}"
    echo "   7) ${M_MENU_7}"
    echo "   8) ${M_MENU_8}"
    echo "   9) ${M_MENU_9}"
    echo "  10) ${M_MENU_10}"
    echo "   0) ${M_MENU_0}"
    echo
    read -r -p "→ ${M_MENU_CHOICE} : " choice || break
    case "$choice" in
        1) run_action "${SCRIPT_DIR}/utils/monitor.sh" ;;
        2) echo
           read -r -p "→ ${M_MENU_CMDQ}" cmd
           if [[ -n "$cmd" ]]; then
               run_action "${SCRIPT_DIR}/utils/console.sh" "$cmd"
           else
               warn "$M_MENU_CMDEMPTY"
               pause_menu
           fi ;;
        3) run_action "${SCRIPT_DIR}/utils/backup.sh" ;;
        4) run_action "${SCRIPT_DIR}/utils/restore.sh" ;;
        5) run_action "${SCRIPT_DIR}/utils/update.sh" ;;
        6) run_action "${SCRIPT_DIR}/utils/mods.sh" ;;
        7) echo
           read -r -p "→ ${M_MENU_WLQ}" wl
           if [[ -n "$wl" ]]; then
               # shellcheck disable=SC2086
               run_action "${SCRIPT_DIR}/security/whitelist_manager.sh" $wl
           else
               warn "$M_MENU_WLBAD"
               pause_menu
           fi ;;
        8) open_crafty ;;
        9) oci_submenu ;;
        10) echo
           info "$M_MENU_REINSTALL"
           bash "${SCRIPT_DIR}/setup.sh" || warn "$M_MENU_SETUPERR"
           if [[ -f "${SCRIPT_DIR}/.server.conf" ]]; then
               HAVE_CONF="true"
               load_server_conf "${SCRIPT_DIR}/.server.conf"
           fi
           pause_menu ;;
        0) break ;;
        *) warn "$M_MENU_BAD" ;;
    esac
done

echo
info "$M_MENU_BYE"

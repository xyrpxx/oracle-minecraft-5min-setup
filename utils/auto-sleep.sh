#!/usr/bin/env bash
# =============================================================================
# auto-sleep.sh — Éteint automatiquement le serveur quand 0 joueur connecté.
#
# Option Aternos-like : si personne ne joue, le serveur s'arrête tout seul.
# Économie d'énergie + respect de la réclamation OCI Always Free (CPU/RAM).
#
# Fonctionnement : ce script est lancé par un systemd timer toutes les 5 min.
#   - Interroge le nombre de joueurs via RCON (`list`)
#   - Si 0 joueur ET serveur actif depuis > IDLE_MINUTES → systemctl stop minecraft
#   - Sinon ne fait rien
#
# Wake-on-join (relancer quand un joueur veut rejoindre) : non implémenté.
# Un utilisateur peut rejoindre en SSH + `sudo systemctl start minecraft`.
#
# Installation (une fois, sur la VM) :
#   1. sudo cp utils/auto-sleep.sh /opt/minecraft/bin/auto-sleep.sh
#      sudo chmod +x /opt/minecraft/bin/auto-sleep.sh
#   2. sudo tee /etc/systemd/system/auto-sleep.service <<'EOF'
#      [Unit]
#      Description=Stop Minecraft when no players are online
#      [Service]
#      Type=oneshot
#      ExecStart=/opt/minecraft/bin/auto-sleep.sh
#      [Install]
#      WantedBy=multi-user.target
#      EOF
#   3. sudo tee /etc/systemd/system/auto-sleep.timer <<'EOF'
#      [Unit]
#      Description=Check Minecraft idle every 5 minutes
#      [Timer]
#      OnBootSec=5min
#      OnUnitActiveSec=5min
#      [Install]
#      WantedBy=timers.target
#      EOF
#   4. sudo systemctl enable --now auto-sleep.timer
# =============================================================================
set -euo pipefail

SERVER_DIR=/opt/minecraft/server
IDLE_MINUTES="${IDLE_MINUTES:-30}"

# Charger les credentials RCON
if [[ ! -f "${SERVER_DIR}/.rcon-credentials" ]]; then
    echo "[auto-sleep] Pas de .rcon-credentials : rien à faire."
    exit 0
fi
# shellcheck disable=SC1091
. "${SERVER_DIR}/.rcon-credentials"

# Si le service est déjà arrêté, on ne fait rien.
if ! systemctl is-active --quiet minecraft; then
    echo "[auto-sleep] minecraft inactif : rien à faire."
    exit 0
fi

# Combien de joueurs en ligne ?
PLAYERS="$(python3 /opt/minecraft/bin/rcon_client.py \
    127.0.0.1 "${RCON_PORT}" "${RCON_PASSWORD}" "list" 2>/dev/null || true)"
# Réponse typique : "There are 0 of a max of 10 players online."
if [[ "$PLAYERS" =~ There\ are\ ([0-9]+)\ of ]]; then
    N="${BASH_REMATCH[1]}"
else
    echo "[auto-sleep] Impossible de lire le nombre de joueurs : $PLAYERS"
    exit 0
fi

if [[ "$N" -gt 0 ]]; then
    echo "[auto-sleep] $N joueur(s) en ligne : pas d'arrêt."
    exit 0
fi

# 0 joueur. Depuis quand le service tourne-t-il ?
STARTED="$(systemctl show minecraft --property=ActiveEnterTimestampMonotonic --value 2>/dev/null || echo 0)"
NOW="$(date +%s%3N 2>/dev/null || echo 0)"
if [[ "$NOW" -gt 0 && "$STARTED" -gt 0 ]]; then
    UPTIME_MS=$(( (10#$NOW - 10#$STARTED) ))
    UPTIME_MIN=$(( UPTIME_MS / 60000 ))
    if (( UPTIME_MIN < IDLE_MINUTES )); then
        echo "[auto-sleep] Serveur vide depuis ${UPTIME_MIN} min (< ${IDLE_MINUTES}) : on patiente."
        exit 0
    fi
fi

echo "[auto-sleep] Aucun joueur depuis > ${IDLE_MINUTES} min : arrêt du serveur."
systemctl stop minecraft

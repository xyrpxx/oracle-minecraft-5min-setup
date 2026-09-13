#!/usr/bin/env bash
# =============================================================================
# auto-sleep.sh — Éteint automatiquement le serveur quand 0 joueur connecté.
#
# Option Aternos-like : si personne ne joue DEPUIS IDLE_MINUTES, le serveur
# s'arrête tout seul. Économie d'énergie + respect de la réclamation OCI
# Always Free (CPU/RAM).
#
# Fonctionnement : ce script est lancé par un systemd timer toutes les 5 min.
#   - Interroge le nombre de joueurs via RCON (`list`)
#   - Si 0 joueur : on regarde DEPUIS COMBIEN DE TEMPS le serveur est vide
#     (fichier d'état /opt/minecraft/.state/empty_since — pas l'uptime du
#     service : un reboot ne doit pas remettre le compteur à zéro à tort,
#     et des joueurs partis il y a 1 min ne doivent pas déclencher l'arrêt)
#   - Si vide depuis > IDLE_MINUTES → systemctl stop minecraft
#   - Dès qu'un joueur est là → le marqueur est effacé
#
# Wake-on-join (relancer quand un joueur veut rejoindre) : non implémenté.
# Un utilisateur peut rejoindre en SSH + `sudo systemctl start minecraft`.
#
# ⚠️  INCOMPATIBLE avec keepalive (security/keepalive.sh) : auto-sleep éteint
#   le serveur quand il est vide, keepalive simule de l'activité pour paraître
#   occupé. Choisissez l'un OU l'autre, jamais les deux.
#
# Installation (une fois, sur la VM) : via manage.sh menu 9 → option c
#   (ou manuellement : voir les templates ci-dessous)
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
STATE_DIR=/opt/minecraft/.state
EMPTY_MARKER="${STATE_DIR}/empty_since"
IDLE_MINUTES="${IDLE_MINUTES:-30}"

# IDLE_MINUTES non numérique → on refuse de deviner (fail-closed : pas d'arrêt).
[[ "$IDLE_MINUTES" =~ ^[0-9]+$ ]] \
    || { echo "[auto-sleep] IDLE_MINUTES invalide : $IDLE_MINUTES" >&2; exit 1; }

# Charger les credentials RCON
if [[ ! -f "${SERVER_DIR}/.rcon-credentials" ]]; then
    echo "[auto-sleep] Pas de .rcon-credentials : rien à faire."
    exit 0
fi
# shellcheck disable=SC1091
. "${SERVER_DIR}/.rcon-credentials"

# Si le service est déjà arrêté, on nettoie le marqueur et on ne fait rien.
if ! systemctl is-active --quiet minecraft; then
    rm -f "$EMPTY_MARKER" 2>/dev/null || true
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

# Des joueurs → le serveur n'est pas vide : on efface le marqueur.
if [[ "$N" -gt 0 ]]; then
    rm -f "$EMPTY_MARKER" 2>/dev/null || true
    echo "[auto-sleep] $N joueur(s) en ligne : pas d'arrêt."
    exit 0
fi

# 0 joueur. Depuis quand ? Premier constat → on pose le marqueur (epoch).
NOW="$(date +%s)"
if [[ ! -f "$EMPTY_MARKER" ]]; then
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    printf '%s\n' "$NOW" > "$EMPTY_MARKER" 2>/dev/null || true
    echo "[auto-sleep] Serveur vide : compteur démarré (arrêt dans ${IDLE_MINUTES} min si personne ne revient)."
    exit 0
fi

EMPTY_SINCE="$(cat "$EMPTY_MARKER" 2>/dev/null || echo "$NOW")"
[[ "$EMPTY_SINCE" =~ ^[0-9]+$ ]] || EMPTY_SINCE="$NOW"
EMPTY_MIN=$(( (10#$NOW - 10#$EMPTY_SINCE) / 60 ))

if (( EMPTY_MIN < 10#$IDLE_MINUTES )); then
    echo "[auto-sleep] Serveur vide depuis ${EMPTY_MIN} min (< ${IDLE_MINUTES}) : on patiente."
    exit 0
fi

echo "[auto-sleep] Aucun joueur depuis ${EMPTY_MIN} min (> ${IDLE_MINUTES}) : arrêt du serveur."
rm -f "$EMPTY_MARKER" 2>/dev/null || true
systemctl stop minecraft

#!/usr/bin/env bash
# =============================================================================
# monitor.sh — État du serveur en un coup d'œil (exécuté LOCALEMENT, via SSH).
# Affiche : service, processus java (CPU/RAM/uptime), mémoire, disque,
# joueurs connectés (RCON) et TPS (Forge uniquement).
# Astuce temps réel : watch -n 5 ./utils/monitor.sh
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

load_server_conf "${SCRIPT_DIR}/.server.conf"

run_ssh "bash -s" <<'REMOTE'
set -euo pipefail
SERVER_DIR=/opt/minecraft/server

echo "===== SERVICE ====="
systemctl is-active minecraft
systemctl show minecraft -p ActiveEnterTimestamp --value

PID="$(systemctl show minecraft -p MainPID --value)"
if [[ "$PID" != "0" && -n "$PID" ]]; then
    echo
    echo "===== PROCESSUS JAVA ====="
    ps -o pid,pcpu,pmem,etime,comm -p "$PID"
fi

echo
echo "===== MÉMOIRE SYSTÈME ====="
free -h

echo
echo "===== DISQUE (/opt) ====="
df -h /opt

if [[ -f "${SERVER_DIR}/.rcon-credentials" ]]; then
    # shellcheck disable=SC1091
    . "${SERVER_DIR}/.rcon-credentials"
    rcon() { python3 /opt/minecraft/bin/rcon_client.py 127.0.0.1 "${RCON_PORT}" "${RCON_PASSWORD}" "$1"; }
    echo
    echo "===== JOUEURS ====="
    rcon "list" 2>/dev/null || echo "RCON indisponible"
    echo
    echo "===== TPS (Forge uniquement) ====="
    rcon "forge tps" 2>/dev/null || echo "Indisponible (serveur non-Forge)"
fi
REMOTE

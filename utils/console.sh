#!/usr/bin/env bash
# =============================================================================
# console.sh — Parle à ton serveur comme un admin (exécuté LOCALEMENT, RCON).
#
# Usage :
#   ./utils/console.sh "op TonPseudo"        ← te rendre admin en jeu
#   ./utils/console.sh "say Bienvenue !"     ← afficher un message à tous
#   ./utils/console.sh "time set day"        ← mettre le jour
#   ./utils/console.sh "difficulty peaceful" ← pacifique
#   ./utils/console.sh "list"                ← qui est connecté
#
# Toute commande Minecraft/Forge comprise par le serveur fonctionne.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

usage() {
    sed -n 's/^# \{0,1\}//p' "$0" | sed -n '3,14p'
}

if [[ $# -lt 1 ]]; then
    usage >&2
    exit 1
fi

# Commande complète (les mots sont recollés).
# Sécurité : la commande voyage via un argument positionnel du shell distant
# (bash -s -- "$CMD"), JAMAIS interpolée dans une chaîne — aucun caractère
# spécial ($, backticks, quotes...) ne peut s'exécuter sur la VM.
CMD="$*"

load_server_conf "${SCRIPT_DIR}/.server.conf"

# base64 évite tout problème de quoting à travers SSH.
CMD_B64="$(printf '%s' "$CMD" | base64 | tr -d '\n')"
run_ssh "sudo bash -s -- '${CMD_B64}'" <<'REMOTE'
set -euo pipefail
CMD="$(printf '%s' "$1" | base64 -d)"
# shellcheck disable=SC1091
. /opt/minecraft/server/.rcon-credentials
python3 /opt/minecraft/bin/rcon_client.py 127.0.0.1 "$RCON_PORT" "$RCON_PASSWORD" "$CMD"
REMOTE

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

# Commande complète (les mots sont recollés) + échappement des guillemets
# pour le passage à travers SSH.
CMD="$*"
CMD="${CMD//\"/\\\"}"

load_server_conf "${SCRIPT_DIR}/.server.conf"

run_ssh "sudo bash -c '. /opt/minecraft/server/.rcon-credentials && \
python3 /opt/minecraft/bin/rcon_client.py 127.0.0.1 \$RCON_PORT \$RCON_PASSWORD \"${CMD}\"'"

#!/usr/bin/env bash
# =============================================================================
# lib.sh — Fonctions partagées du projet oracle-minecraft-5min-setup
# Sourcing :
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "${SCRIPT_DIR}/scripts/lib.sh"
# Contient : couleurs, journalisation, validations pures (unit-testées),
#            questions interactives et invocation SSH.
# =============================================================================

# --- Couleurs terminal (désactivées si la sortie n'est pas un terminal) ---
if [[ -t 1 ]]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; NC=''
fi

info()    { printf '%s\n' "${BLUE}[INFO]${NC} $*"; }
success() { printf '%s\n' "${GREEN}[OK]${NC} $*"; }
warn()    { printf '%s\n' "${YELLOW}[ATTENTION]${NC} $*"; }
die()     { printf '%s\n' "${RED}[ERREUR]${NC} $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Validations pures (testées dans tests/test_lib.sh)
# ---------------------------------------------------------------------------

# IPv4 valide : 4 octets numériques 0-255. Retourne 0 si valide, 1 sinon.
is_valid_ipv4() {
    local ip="$1" octet
    local -a octets=()
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        (( 10#$octet <= 255 )) || return 1
    done
    return 0
}

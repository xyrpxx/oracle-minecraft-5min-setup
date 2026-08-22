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

# Tags localisables : les fichiers scripts/lang_*.sh peuvent les surcharger.
info()    { printf '%s\n' "${BLUE}${INFO_TAG:-[INFO]}${NC} $*"; }
success() { printf '%s\n' "${GREEN}${OK_TAG:-[OK]}${NC} $*"; }
warn()    { printf '%s\n' "${YELLOW}${WARN_TAG:-[ATTENTION]}${NC} $*"; }
die()     { printf '%s\n' "${RED}${ERROR_TAG:-[ERREUR]}${NC} $*" >&2; exit 1; }

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

# Version Minecraft valide : X.Y ou X.Y.Z (ex. 1.20.1).
is_valid_mc_version() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]
}

# RAM Go valide pour l'Always Free (12 Go au total, 4 Go réservés au système).
# Maximum strict : 8 Go — au-delà, le Linux OOM Killer fait planter le serveur.
is_valid_ram() {
    [[ "$1" =~ ^[0-9]+$ ]] || return 1
    (( 10#$1 >= 2 && 10#$1 <= 8 ))
}

# Nombre de joueurs simultanés raisonnable (1 à 100).
is_valid_player_count() {
    [[ "$1" =~ ^[0-9]+$ ]] || return 1
    (( 10#$1 >= 1 && 10#$1 <= 100 ))
}

# Pseudo Minecraft officiel : 3 à 16 caractères alphanumériques ou _.
is_valid_mc_username() {
    [[ "$1" =~ ^[A-Za-z0-9_]{3,16}$ ]]
}

# Nom de fichier de sauvegarde sûr (pas d'espace, pas de traversée de chemin).
is_valid_backup_name() {
    [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}

# URL directe acceptable pour un téléchargement (http/https, jeu de caractères
# restreint : aucun espace, quote, point-virgule, $ ou backtick — évite toute
# injection lors de la construction de commandes SSH distantes).
is_valid_url() {
    local re='^https?://[A-Za-z0-9._~:/?#@!&()*+,=%-]+$'
    [[ "$1" =~ $re ]]
}

# Échappe une valeur pour un fichier destiné à être sourcé (source-safety) :
# les chemins Windows/macOS contenant espaces ou quotes restent lisibles.
shell_quote() {
    local s="$1"
    s="${s//\'/\'\\\'\'}"
    printf "'%s'\n" "$s"
}

# Vérifie qu'un identifiant de modpack figure dans le registre (sans jq local).
modpack_id_exists() {
    local id="$1" manifest="${2:-modpacks/manifest.json}"
    grep -q "\"id\"[[:space:]]*:[[:space:]]*\"$id\"" "$manifest" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Questions interactives (non testées automatiquement)
# ---------------------------------------------------------------------------

# ask_yes_no "Question ?" [y|n]  → retourne 0 si oui, 1 si non.
ask_yes_no() {
    local question="$1" default="${2:-n}" prompt response
    if [[ "$default" == "y" ]]; then
        prompt="${ASK_YES_NO_PROMPT_Y:-[O/n]}"
    else
        prompt="${ASK_YES_NO_PROMPT_N:-[o/N]}"
    fi
    read -r -p "$question $prompt : " response
    response="${response:-$default}"
    case "$response" in
        [oO]|[oO][uU][iI]|[yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# ask_number "Question" défaut min max → affiche la valeur saisie sur stdout.
ask_number() {
    local question="$1" default="$2" min="$3" max="$4" value
    while true; do
        read -r -p "$question [$default] : " value
        value="${value:-$default}"
        if [[ "$value" =~ ^[0-9]+$ ]] && (( 10#$value >= min && 10#$value <= max )); then
            printf '%s\n' "$value"
            return 0
        fi
        warn "Valeur invalide (entier entre $min et $max)."
    done
}

# ask_choice "Question ?" "Option 1" "Option 2" ... → remplit SELECTED_CHOICE.
ask_choice() {
    local question="$1"; shift
    local i=1 opt choice n=$#
    printf '\n%s\n' "$question"
    for opt in "$@"; do
        printf '  %d) %s\n' "$i" "$opt"
        i=$((i + 1))
    done
    while true; do
        read -r -p "→ ${ASK_CHOICE_WORD:-Choix} (1-$n) : " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( 10#$choice >= 1 && 10#$choice <= n )); then
            SELECTED_CHOICE="$choice"
            return 0
        fi
        warn "Choix invalide."
    done
}

# ---------------------------------------------------------------------------
# Configuration locale + SSH (utilisés par setup.sh, utils/, security/, uninstall.sh)
# ---------------------------------------------------------------------------

# Charge .server.conf généré par setup.sh (IP, clé, type de serveur...).
load_server_conf() {
    local conf="${1:-./.server.conf}"
    [[ -f "$conf" ]] || die "Configuration locale introuvable ($conf). Lancez d'abord ./setup.sh."
    # shellcheck disable=SC1090
    . "$conf"
    [[ -n "${ORACLE_IP:-}" && -n "${SSH_KEY_PATH:-}" ]] || die "$conf est incomplet (ORACLE_IP/SSH_KEY_PATH)."
}

# Invocation SSH standard vers la VM Oracle.
run_ssh() {
    ssh -i "${SSH_KEY_PATH:?SSH_KEY_PATH non défini}" \
        -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 \
        "${SSH_USER:-ubuntu}@${ORACLE_IP:?ORACLE_IP non définie}" "$@"
}

# Ouvre une URL dans le navigateur par défaut (silencieux, best effort).
open_url() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*) cmd //c start "" "$1" >/dev/null 2>&1 || return 1 ;;
        Darwin)               open "$1" >/dev/null 2>&1 || return 1 ;;
        *)                    xdg-open "$1" >/dev/null 2>&1 || return 1 ;;
    esac
}

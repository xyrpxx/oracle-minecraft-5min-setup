#!/usr/bin/env bash
# =============================================================================
# setup.sh — LOCAL deployment orchestrator (runs on the user's machine).
#
# Transfers deploy/, configs/, modpacks/ and utils/rcon_client.py to the VM
# into /tmp/setup/, then runs deploy/remote_provision.sh over SSH.
# No provisioning command is ever executed locally.
#
# Languages  : UI_LANG=fr (default on French systems) or en — see --lang.
# Interactive: ./setup.sh            (guided wizard, perfect for beginners)
# Scripted   : ./setup.sh --lang en --ip IP --key PATH --type forge ... --yes
# =============================================================================
set -euo pipefail

VERSION="3.3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

STAGING="/tmp/setup"
CONF_FILE="${SCRIPT_DIR}/.server.conf"

# --- Configuration (filled by questions or options) ---
ORACLE_IP="" SSH_KEY_PATH="" SSH_USER="ubuntu"
SERVER_TYPE="vanilla" MC_VERSION="1.20.1" RAM_GB="8"
PLAYERS="10" INSTALL_CRAFTY="true" MODPACK="none" PACK_URL="-"
ASSUME_YES="false" DRY_RUN="false" GUIDED_MODE="true"

# --- Language detection (overridable with --lang fr|en) ---
detect_language() {
    case "${LC_ALL:-${LANG:-}}" in
        fr*) UI_LANG="fr" ;;
        *)   UI_LANG="en" ;;
    esac
}
detect_language

# shellcheck source=scripts/lang_fr.sh
# shellcheck source=scripts/lang_en.sh
load_language() {
    . "${SCRIPT_DIR}/scripts/lang_${UI_LANG}.sh"
}

usage() {
    cat <<'EOF'
Usage: setup.sh [options]
  (No option: interactive guided wizard — ideal for beginners.
   On Windows you can also simply double-click start-windows.bat)

  --lang <fr|en>        Interface language (auto-detected from your system)
  --mode <guide|expert> guide (default) | expert
  --ip <address>        Public IP of the Oracle VM
  --key <path>          SSH private key (.key / .pem)
  --type <type>         vanilla | forge | fabric | modpack
  --mc-version <ver>    Minecraft version (default: 1.20.1)
  --ram <GB>            JVM RAM, 2 to 8 (default: 8)
  --players <n>         Max players (default: 10)
  --crafty <bool>       Install the Crafty panel (default: true)
  --modpack <id>        Modpack id (better-minecraft, atm9-light, vanilla-plus)
  --pack-url <url>      Direct server-pack URL (required if --type modpack)
  --yes                 Non-interactive (requires all options above)
  --dry-run             Simulation: print actions without executing anything
  -h, --help            This help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lang)        UI_LANG="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
                           case "$UI_LANG" in
                               fr|en) ;;
                               *) printf '[ERROR] --lang expects fr or en\n' >&2; exit 1 ;;
                           esac
                           shift 2 ;;
            --mode)        case "$2" in
                               guide|guided) GUIDED_MODE="true" ;;
                               expert)       GUIDED_MODE="false" ;;
                               *) printf '[ERROR] --mode expects guide or expert\n' >&2; exit 1 ;;
                           esac; shift 2 ;;
            --ip)          ORACLE_IP="$2"; shift 2 ;;
            --key)         SSH_KEY_PATH="$2"; shift 2 ;;
            --type)        SERVER_TYPE="$2"; shift 2 ;;
            --mc-version)  MC_VERSION="$2"; shift 2 ;;
            --ram)         RAM_GB="$2"; shift 2 ;;
            --players)     PLAYERS="$2"; shift 2 ;;
            --crafty)      INSTALL_CRAFTY="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"; shift 2 ;;
            --modpack)     MODPACK="$2"; shift 2 ;;
            --pack-url)    PACK_URL="$2"; shift 2 ;;
            --yes)         ASSUME_YES="true"; shift ;;
            --dry-run)     DRY_RUN="true"; shift ;;
            -h|--help)     usage; exit 0 ;;
            *) load_language; die "${M_ERR_OPT} $1 (--help)" ;;
        esac
    done
}

check_local_prerequisites() {
    case "$(uname -s)" in
        Linux|Darwin|MINGW*|MSYS*|CYGWIN*)
            info "$(uname -s)" ;;
        *) die "${M_ERR_OS} $(uname -s). ${M_ERR_OS_HINT}" ;;
    esac
    local tool
    for tool in ssh scp curl; do
        command -v "$tool" >/dev/null 2>&1 || die "${M_ERR_TOOL} $tool"
    done
}

show_expert_checklist() {
    echo
    info "Mode expert — vérifie avant de continuer :"
    echo "  1. Compte Oracle Cloud actif (https://cloud.oracle.com)"
    echo "  2. VM Ubuntu ARM : image Ubuntu 22.04+, Ampere A1, 2 OCPU / 12 Go"
    echo "  3. IP publique de la VM (console → Compute → Instances)"
    echo "  4. Clé SSH privée téléchargée à la création de la VM"
    echo
    if ! ask_yes_no "Tout est prêt ?" "y"; then
        echo
        info "Le guide complet pas à pas : docs/guide-debutant-fr.md (docs/en/getting-started.md)"
        exit 0
    fi
}

# Waits patiently until the user has finished a step in their browser.
wait_until_done() { # tip
    local tip="$1"
    while true; do
        if ask_yes_no "$M_WAIT_Q" "y"; then return 0; fi
        echo
        info "$M_WAIT_REASSURE"
        info "${M_WAIT_TIPPREFIX}${tip}"
    done
}

wizard_account() {
    echo
    echo "──────────────────────────────────────────────────────────────"
    echo "  ${M_W1_TITLE}"
    echo "──────────────────────────────────────────────────────────────"
    if ask_yes_no "$M_W1_HAVE" "n"; then
        success "$M_W1_SKIP"
        return 0
    fi
    echo
    info "$M_W1_L1"
    info "$M_W1_L2"
    info "$M_W1_L3"
    echo
    echo "   $M_W1_S1"
    echo "   $M_W1_S2"
    echo "   $M_W1_S3"
    echo "   $M_W1_S4"
    echo "   $M_W1_S4b"
    echo "   $M_W1_S4c"
    echo "   $M_W1_S5"
    echo "   $M_W1_S5b"
    echo "   $M_W1_S5c"
    echo "   $M_W1_S5d"
    echo
    if ask_yes_no "$M_W1_OPENQ" "y"; then
        open_url "https://cloud.oracle.com" || info "$M_W1_OPENFAIL"
    fi
    echo
    warn "$M_W1_WARN"
    wait_until_done "$M_W1_WAITTIP"
}

wizard_vm() {
    echo
    echo "──────────────────────────────────────────────────────────────"
    echo "  ${M_W2_TITLE}"
    echo "──────────────────────────────────────────────────────────────"
    if ask_yes_no "$M_W2_HAVE" "n"; then
        success "$M_W2_SKIP"
        return 0
    fi
    echo
    info "$M_W2_L1"
    info "$M_W2_L2"
    echo
    echo "   $M_W2_S1"
    echo "   $M_W2_S2"
    echo "   $M_W2_S3"
    echo "   $M_W2_S3b"
    echo "   $M_W2_S4"
    echo "   $M_W2_S4b"
    echo "   $M_W2_S4c"
    echo "   $M_W2_S4d"
    echo "   $M_W2_S4e"
    echo "   $M_W2_S5"
    echo
    if ask_yes_no "$M_W2_OPENQ" "y"; then
        open_url "https://cloud.oracle.com" || info "$M_W2_OPENFAIL"
    fi
    wait_until_done "$M_W2_WAITTIP"
    echo
    success "$M_W2_DONE1"
    success "$M_W2_DONE2"
}

ask_ip() {
    if [[ "$GUIDED_MODE" == "true" ]]; then
        echo
        echo "──────────────────────────────────────────────────────────────"
        echo "  ${M_STEP3_TITLE}"
        echo "──────────────────────────────────────────────────────────────"
        info "$M_IP_HINT1"
        info "$M_IP_HINT2"
        info "$M_IP_HINT3"
    fi
    while true; do
        read -r -p "$M_IP_PROMPT" ORACLE_IP
        ORACLE_IP="${ORACLE_IP// /}"
        if is_valid_ipv4 "$ORACLE_IP"; then
            success "$M_IP_OK $ORACLE_IP"
            break
        fi
        warn "$M_IP_BAD"
        info "$M_IP_WHERE"
    done
}

ask_ssh_key() {
    echo
    if [[ "$GUIDED_MODE" == "true" ]]; then
        info "$M_KEY_INTRO_G1"
        info "$M_KEY_INTRO_G2"
        info "$M_KEY_INTRO_G3"
    else
        info "$M_KEY_INTRO_E1"
        info "$M_KEY_INTRO_E2"
    fi
    local default_found=""
    local candidate
    for candidate in "$HOME"/Downloads/ssh-key-*.key "$HOME"/Downloads/*.pem \
                     "$HOME"/.ssh/id_*.pem "$HOME"/.ssh/id_rsa; do
        if [[ -f "$candidate" ]]; then
            if ask_yes_no "${M_KEY_FOUNDQ} ${candidate} ${M_KEY_USEQ}" "y"; then
                SSH_KEY_PATH="$candidate"
                default_found="yes"
                break
            fi
        fi
    done
    if [[ -z "$default_found" ]]; then
        while true; do
            read -r -e -p "$M_KEY_PROMPT" SSH_KEY_PATH
            if [[ -f "$SSH_KEY_PATH" ]]; then
                break
            fi
            warn "${M_KEY_NOTFOUND} ${SSH_KEY_PATH}"
        done
    fi
    chmod 600 "$SSH_KEY_PATH" 2>/dev/null || warn "$M_KEY_PERMWARN"
    success "$M_KEY_OK $SSH_KEY_PATH"
}

list_modpack_ids() {
    grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' "${SCRIPT_DIR}/modpacks/manifest.json" \
        | sed 's/.*"\([^"]*\)"$/\1/'
}

show_modpack_info() { # id
    local f="${SCRIPT_DIR}/modpacks/$1.json"
    [[ -f "$f" ]] || return 0
    sed -n 's/.*"nom"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/  Nom : \1/p; s/.*"description"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/  Description : \1/p; s/.*"ram_recommandee_go"[[:space:]]*:[[:space:]]*\([0-9]*\).*/  RAM recommandée : \1 Go/p' "$f"
    sed -n 's/.*"page_curseforge"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/  Page : \1/p' "$f"
}

ask_server_config() {
    echo
    info "$M_HINT_ENTER1"
    info "$M_HINT_ENTER2"
    echo
    ask_choice "$M_TYPE_Q" \
        "$M_TYPE_OPT1" \
        "$M_TYPE_OPT2" \
        "$M_TYPE_OPT3" \
        "$M_TYPE_OPT4"
    case "$SELECTED_CHOICE" in
        1) SERVER_TYPE="vanilla" ;;
        2) SERVER_TYPE="forge" ;;
        3) SERVER_TYPE="fabric" ;;
        4) SERVER_TYPE="modpack" ;;
    esac

    while true; do
        read -r -p "$M_VER_PROMPT" MC_VERSION
        MC_VERSION="${MC_VERSION:-1.20.1}"
        is_valid_mc_version "$MC_VERSION" && break
        warn "$M_VER_BAD"
    done
    success "$M_VER_OK $MC_VERSION"

    RAM_GB="$(ask_number "$M_RAM_LABEL" 8 2 8)"
    success "$M_RAM_OK ${RAM_GB} GB"

    PLAYERS="$(ask_number "$M_PLAYERS_LABEL" 10 1 100)"

    if ask_yes_no "$M_CRAFTY_Q" "y"; then
        INSTALL_CRAFTY="true"
        info "$M_CRAFTY_INFO1"
    else
        INSTALL_CRAFTY="false"
        info "$M_CRAFTY_INFO2"
    fi

    if [[ "$SERVER_TYPE" == "modpack" ]]; then
        echo
        info "$M_MOD_TITLE"
        local ids id
        ids="$(list_modpack_ids)"
        local i=1
        for id in $ids; do
            echo "  ${i}) ${id}"
            show_modpack_info "$id"
            i=$((i + 1))
        done
        while true; do
            read -r -p "$M_MOD_PROMPT" MODPACK
            if modpack_id_exists "$MODPACK" "${SCRIPT_DIR}/modpacks/manifest.json"; then
                break
            fi
            warn "$M_MOD_BAD $MODPACK"
        done
        echo
        info "$M_URL_INFO1"
        info "$M_URL_INFO2"
        info "$M_URL_INFO3"
        info "$M_URL_INFO4"
        info "$M_URL_EXAMPLE"
        while true; do
            read -r -p "$M_URL_PROMPT" PACK_URL
            is_valid_url "$PACK_URL" && break
            warn "$M_URL_BAD"
        done
    fi
}

validate_non_interactive_config() {
    is_valid_ipv4 "$ORACLE_IP" || die "${M_ERR_IP} $ORACLE_IP"
    case "$SERVER_TYPE" in
        vanilla|forge|fabric|modpack) ;;
        *) die "${M_ERR_TYPE} $SERVER_TYPE" ;;
    esac
    is_valid_mc_version "$MC_VERSION" || die "${M_ERR_VER} $MC_VERSION"
    is_valid_ram "$RAM_GB" || die "${M_ERR_RAM}"
    [[ -f "$SSH_KEY_PATH" ]] || die "${M_ERR_KEY} $SSH_KEY_PATH"
    [[ "$INSTALL_CRAFTY" == "true" || "$INSTALL_CRAFTY" == "false" ]] || die "$M_ERR_CRAFTY"
    if [[ "$SERVER_TYPE" == "modpack" ]]; then
        modpack_id_exists "$MODPACK" "${SCRIPT_DIR}/modpacks/manifest.json" || die "${M_ERR_MOD} $MODPACK"
        is_valid_url "$PACK_URL" || die "$M_ERR_URL"
    fi
}

confirm_summary() {
    echo
    echo "════════════════════════════════════════════════════════"
    echo "$M_SUM_TITLE"
    echo "════════════════════════════════════════════════════════"
    echo "  $M_SUM_IP      : $ORACLE_IP"
    echo "  $M_SUM_TYPE   : $SERVER_TYPE"
    [[ "$SERVER_TYPE" == "modpack" ]] && echo "  $M_SUM_MOD    : $MODPACK"
    echo "  $M_SUM_VER    : $MC_VERSION"
    echo "  $M_SUM_RAM    : ${RAM_GB} GB"
    echo "  $M_SUM_PLAYERS: $PLAYERS"
    echo "  $M_SUM_CRAFTY : $INSTALL_CRAFTY"
    echo "════════════════════════════════════════════════════════"
    echo
    if [[ "$ASSUME_YES" != "true" ]]; then
        ask_yes_no "$M_CONFIRM_Q" "y" || { info "$M_CANCELLED"; exit 0; }
    fi
}

setup_ssh() {
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 \
        "${SSH_USER}@${ORACLE_IP}" "$@"
}

test_ssh_connectivity() {
    info "$M_SSH_TEST ${SSH_USER}@${ORACLE_IP} ..."
    if setup_ssh "true" 2>/dev/null; then
        success "$M_SSH_OK"
    else
        die "$M_SSH_FAIL_L1
$M_SSH_FAIL_1
$M_SSH_FAIL_2
$M_SSH_FAIL_2b
$M_SSH_FAIL_3
$M_SSH_FAIL_HELP"
    fi
}

transfer_files() {
    info "$M_TRANSFER_1 (${STAGING}) ..."
    setup_ssh "sudo rm -rf ${STAGING} && mkdir -p ${STAGING}/utils"
    scp -q -r -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new \
        "${SCRIPT_DIR}/deploy" "${SCRIPT_DIR}/configs" "${SCRIPT_DIR}/modpacks" \
        "${SSH_USER}@${ORACLE_IP}:${STAGING}/"
    scp -q -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new \
        "${SCRIPT_DIR}/utils/rcon_client.py" "${SSH_USER}@${ORACLE_IP}:${STAGING}/utils/"
    success "$M_TRANSFER_2"
}

execute_remote_provision() {
    info "$M_PROV_1"
    info "$M_PROV_2"
    info "$M_PROV_3"
    setup_ssh "sudo bash ${STAGING}/deploy/remote_provision.sh \
        --ip '${ORACLE_IP}' --server-type '${SERVER_TYPE}' --mc-version '${MC_VERSION}' \
        --ram '${RAM_GB}' --players '${PLAYERS}' --crafty '${INSTALL_CRAFTY}' \
        --modpack '${MODPACK}' --pack-url '${PACK_URL}'"
}

save_server_conf() {
    # shell_quote : les chemins contenant espaces/quotes restent sourçables.
    cat > "$CONF_FILE" <<EOF
# Généré par setup.sh — configuration locale (ne pas versionner)
ORACLE_IP=$(shell_quote "$ORACLE_IP")
SSH_KEY_PATH=$(shell_quote "$SSH_KEY_PATH")
SSH_USER=$(shell_quote "$SSH_USER")
SERVER_TYPE=$(shell_quote "$SERVER_TYPE")
MC_VERSION=$(shell_quote "$MC_VERSION")
RAM_GB=$(shell_quote "$RAM_GB")
MODPACK=$(shell_quote "$MODPACK")
EOF
    chmod 600 "$CONF_FILE" 2>/dev/null || true
    success "$M_CONF_SAVED"
}

final_banner() {
    echo
    success "$M_FINAL_OK"
    echo
    echo "══════════════════════════════════════════════════════════════"
    echo "   $M_FINAL_ADDR"
    echo
    echo "          ${ORACLE_IP}:25565"
    echo "══════════════════════════════════════════════════════════════"
    echo
    echo "  $M_FINAL_KNOW"
    echo
    echo "  $M_FINAL_1"
    echo "  $M_FINAL_1b"
    if [[ "$SERVER_TYPE" == "modpack" || "$SERVER_TYPE" == "forge" || "$SERVER_TYPE" == "fabric" ]]; then
        echo "  $M_FINAL_2_MOD"
        echo "  $M_FINAL_2_MODb"
    else
        echo "  $M_FINAL_2_VAN"
        echo "  $M_FINAL_2_VANb"
    fi
    echo "  $M_FINAL_3"
    echo "  $M_FINAL_3b"
    echo
    echo "  $M_FINAL_TOOLS"
    echo "  $M_FINAL_HELP"
    echo
    if [[ "$ASSUME_YES" != "true" ]]; then
        if ask_yes_no "$M_FINAL_GUIDEQ" "y"; then
            open_url "https://github.com/xyrpxx/oracle-minecraft-5min-setup/blob/main/docs/en/vcn-setup.md" \
                || open_url "https://github.com/xyrpxx/oracle-minecraft-5min-setup/blob/main/docs/oci-vcn-config.md" \
                || info "$M_FINAL_GUIDEFALL"
        fi
        if [[ "$INSTALL_CRAFTY" == "true" ]] && ask_yes_no "$M_FINAL_CRAFTYQ" "y"; then
            open_url "https://${ORACLE_IP}:8443" || info "$M_FINAL_CRAFTYFALL https://${ORACLE_IP}:8443"
        fi
    fi
}

main() {
    parse_args "$@"
    load_language
    echo
    echo "=============================================================="
    echo "   Oracle Cloud Minecraft — Auto Setup v${VERSION}"
    echo "   ${M_TAGLINE}"
    echo "=============================================================="

    check_local_prerequisites

    if [[ "$ASSUME_YES" == "true" ]]; then
        validate_non_interactive_config
    else
        ask_choice "$M_WELCOME_Q" \
            "$M_OPT_GUIDE" \
            "$M_OPT_EXPERT"
        if [[ "$SELECTED_CHOICE" == "1" ]]; then
            GUIDED_MODE="true"
        else
            GUIDED_MODE="false"
        fi
        echo
        if [[ "$GUIDED_MODE" == "true" ]]; then
            info "$M_LETS_GO"
            wizard_account
            wizard_vm
        else
            show_expert_checklist
        fi
        ask_ip
        ask_ssh_key
        ask_server_config
        validate_non_interactive_config
    fi

    confirm_summary

    if [[ "$DRY_RUN" == "true" ]]; then
        echo
        warn "$M_DRY_WARN"
        echo "  $M_WOULD_RUN"
        echo "    scp -r deploy configs modpacks + utils/rcon_client.py → ${SSH_USER}@${ORACLE_IP}:${STAGING}/"
        echo "    ssh ${SSH_USER}@${ORACLE_IP} 'sudo bash ${STAGING}/deploy/remote_provision.sh --ip ${ORACLE_IP} --server-type ${SERVER_TYPE} --mc-version ${MC_VERSION} --ram ${RAM_GB} --players ${PLAYERS} --crafty ${INSTALL_CRAFTY} --modpack ${MODPACK} --pack-url ${PACK_URL}'"
        exit 0
    fi

    test_ssh_connectivity
    transfer_files
    execute_remote_provision
    save_server_conf
    final_banner
}

main "$@"

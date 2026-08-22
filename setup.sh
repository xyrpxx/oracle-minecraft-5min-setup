#!/usr/bin/env bash
# =============================================================================
# setup.sh — Orchestrateur LOCAL du déploiement (machine de l'utilisateur).
#
# Transfère deploy/, configs/, modpacks/ et utils/rcon_client.py vers la VM
# dans /tmp/setup/, puis exécute deploy/remote_provision.sh via SSH.
# Aucune commande de provisioning n'est exécutée localement.
#
# Usage interactif :  ./setup.sh
# Usage scripté   :  ./setup.sh --ip IP --key CHEMIN --type forge ... --yes [--dry-run]
# =============================================================================
set -euo pipefail

VERSION="3.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

STAGING="/tmp/setup"
CONF_FILE="${SCRIPT_DIR}/.server.conf"

# --- Configuration (remplie par les questions ou les options) ---
ORACLE_IP="" SSH_KEY_PATH="" SSH_USER="ubuntu"
SERVER_TYPE="vanilla" MC_VERSION="1.20.1" RAM_GB="8"
PLAYERS="10" INSTALL_CRAFTY="true" MODPACK="none" PACK_URL="-"
ASSUME_YES="false" DRY_RUN="false"

usage() {
    cat <<EOF
Usage : setup.sh [options]
  --ip <adresse>        IP publique de la VM Oracle
  --key <chemin>        Clé privée SSH (.key / .pem)
  --type <type>         vanilla | forge | fabric | modpack
  --mc-version <ver>    Version Minecraft (défaut : 1.20.1)
  --ram <Go>            RAM JVM, 2 à 8 (défaut : 8)
  --players <n>         Joueurs maximum (défaut : 10)
  --crafty <bool>       Installer le panel Crafty (défaut : true)
  --modpack <id>        Identifiant du modpack (better-minecraft, atm9-light, vanilla-plus)
  --pack-url <url>      URL directe du server pack (requis si --type modpack)
  --yes                 Non interactif (nécessite toutes les options ci-dessus)
  --dry-run             Simulation : affiche les actions sans rien exécuter
  -h, --help            Cette aide
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ip)          ORACLE_IP="$2"; shift 2 ;;
            --key)         SSH_KEY_PATH="$2"; shift 2 ;;
            --type)        SERVER_TYPE="$2"; shift 2 ;;
            --mc-version)  MC_VERSION="$2"; shift 2 ;;
            --ram)         RAM_GB="$2"; shift 2 ;;
            --players)     PLAYERS="$2"; shift 2 ;;
            --crafty)      INSTALL_CRAFTY="${2,,}"; shift 2 ;;
            --modpack)     MODPACK="$2"; shift 2 ;;
            --pack-url)    PACK_URL="$2"; shift 2 ;;
            --yes)         ASSUME_YES="true"; shift ;;
            --dry-run)     DRY_RUN="true"; shift ;;
            -h|--help)     usage; exit 0 ;;
            *) die "Option inconnue : $1 (voir --help)" ;;
        esac
    done
}

check_local_prerequisites() {
    case "$(uname -s)" in
        Linux|Darwin|MINGW*|MSYS*|CYGWIN*)
            info "Système détecté : $(uname -s)" ;;
        *) die "OS non supporté : $(uname -s). Utilisez Linux, macOS ou Git Bash (Windows)." ;;
    esac
    local tool
    for tool in ssh scp curl; do
        command -v "$tool" >/dev/null 2>&1 || die "Outil requis manquant : $tool"
    done
}

show_preflight_checklist() {
    echo
    info "AVANT DE CONTINUER, vérifiez que vous avez :"
    echo "  1. Un compte Oracle Cloud actif        (https://cloud.oracle.com)"
    echo "  2. Une VM Ubuntu ARM créée : image Ubuntu 22.04+, shape Ampere A1"
    echo "     avec 2 OCPU / 12 Go de RAM (quota Always Free actuel)"
    echo "  3. L'IP publique de la VM (console → Compute → Instances)"
    echo "  4. Votre clé SSH privée téléchargée lors de la création de la VM"
    echo
    if ! ask_yes_no "Tout est prêt ?" "y"; then
        echo
        info "Consultez le guide pas à pas : docs/guide-debutant-fr.md"
        exit 0
    fi
}

ask_ip() {
    while true; do
        read -r -p "→ IP publique de votre VM Oracle : " ORACLE_IP
        ORACLE_IP="${ORACLE_IP// /}"
        if is_valid_ipv4 "$ORACLE_IP"; then
            success "IP valide : $ORACLE_IP"
            break
        fi
        warn "Format invalide. Exemple attendu : 129.213.56.123"
    done
}

ask_ssh_key() {
    echo
    info "Clé SSH privée téléchargée depuis la console Oracle"
    info "(fichier du type ssh-key-2026-XX-XX.key ou *.pem, souvent dans Téléchargements)."
    local default_found=""
    local candidate
    for candidate in "$HOME"/Downloads/ssh-key-*.key "$HOME"/Downloads/*.pem \
                     "$HOME"/.ssh/id_*.pem "$HOME"/.ssh/id_rsa; do
        if [[ -f "$candidate" ]]; then
            if ask_yes_no "Clé trouvée : ${candidate} — l'utiliser ?" "y"; then
                SSH_KEY_PATH="$candidate"
                default_found="yes"
                break
            fi
        fi
    done
    if [[ -z "$default_found" ]]; then
        while true; do
            read -r -e -p "→ Chemin de la clé privée SSH : " SSH_KEY_PATH
            if [[ -f "$SSH_KEY_PATH" ]]; then
                break
            fi
            warn "Fichier introuvable : ${SSH_KEY_PATH}"
        done
    fi
    chmod 600 "$SSH_KEY_PATH" 2>/dev/null || warn "Impossible d'ajuster les permissions de la clé (ignoré sous Windows)."
    success "Clé SSH : $SSH_KEY_PATH"
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
    ask_choice "Quel type de serveur Minecraft ?" \
        "Vanilla (pur, sans mods)" \
        "Forge (mods classiques — recommandé pour 1.20.1)" \
        "Fabric (mods modernes, léger)" \
        "Modpack préconfiguré (server pack CurseForge)"
    case "$SELECTED_CHOICE" in
        1) SERVER_TYPE="vanilla" ;;
        2) SERVER_TYPE="forge" ;;
        3) SERVER_TYPE="fabric" ;;
        4) SERVER_TYPE="modpack" ;;
    esac

    while true; do
        read -r -p "Version Minecraft [1.20.1] : " MC_VERSION
        MC_VERSION="${MC_VERSION:-1.20.1}"
        is_valid_mc_version "$MC_VERSION" && break
        warn "Version invalide (formats attendus : 1.20.1, 1.21...)"
    done
    success "Version Minecraft : $MC_VERSION"

    RAM_GB="$(ask_number "RAM pour le serveur en Go (max 8 sur l'Always Free)" 8 2 8)"
    success "RAM allouée à la JVM : ${RAM_GB} Go"

    PLAYERS="$(ask_number "Nombre maximum de joueurs" 10 1 100)"

    if ask_yes_no "Installer Crafty Controller (panel web d'administration) ?" "y"; then
        INSTALL_CRAFTY="true"
        info "Panel accessible après installation sur https://<IP>:8443"
    else
        INSTALL_CRAFTY="false"
        info "Gestion via SSH et les scripts utils/ uniquement."
    fi

    if [[ "$SERVER_TYPE" == "modpack" ]]; then
        echo
        info "Modpacks disponibles :"
        local ids id
        ids="$(list_modpack_ids)"
        local i=1
        for id in $ids; do
            echo "  ${i}) ${id}"
            show_modpack_info "$id"
            i=$((i + 1))
        done
        while true; do
            read -r -p "→ Identifiant du modpack : " MODPACK
            if modpack_id_exists "$MODPACK" "${SCRIPT_DIR}/modpacks/manifest.json"; then
                break
            fi
            warn "Modpack inconnu : $MODPACK"
        done
        echo
        info "Collez l'URL DIRECTE du fichier « Server Pack » ( CurseForge →"
        info "  onglet Files → version ${MC_VERSION} → Additional Files → Server Pack )."
        info "Détails : docs/guide-debutant-fr.md (section modpacks)."
        while true; do
            read -r -p "→ URL du server pack (.zip) : " PACK_URL
            [[ "$PACK_URL" == http* ]] && break
            warn "URL invalide (doit commencer par http)"
        done
    fi
}

validate_non_interactive_config() {
    is_valid_ipv4 "$ORACLE_IP" || die "IP invalide : $ORACLE_IP"
    case "$SERVER_TYPE" in
        vanilla|forge|fabric|modpack) ;;
        *) die "Type de serveur invalide : $SERVER_TYPE" ;;
    esac
    is_valid_mc_version "$MC_VERSION" || die "Version Minecraft invalide : $MC_VERSION"
    is_valid_ram "$RAM_GB" \
        || die "RAM invalide : ${RAM_GB} Go (entre 2 et 8 — quota Always Free 12 Go)"
    [[ -f "$SSH_KEY_PATH" ]] || die "Clé SSH introuvable : $SSH_KEY_PATH"
    [[ "$INSTALL_CRAFTY" == "true" || "$INSTALL_CRAFTY" == "false" ]] || die "--crafty doit valoir true ou false"
    if [[ "$SERVER_TYPE" == "modpack" ]]; then
        modpack_id_exists "$MODPACK" "${SCRIPT_DIR}/modpacks/manifest.json" || die "Modpack inconnu : $MODPACK"
        [[ "$PACK_URL" == http* ]] || die "--pack-url requis pour un modpack"
    fi
}

confirm_summary() {
    echo
    echo "════════════════════════════════════════════════════════"
    echo "                 RÉSUMÉ DE CONFIGURATION"
    echo "════════════════════════════════════════════════════════"
    echo "  IP Oracle      : $ORACLE_IP"
    echo "  Type serveur   : $SERVER_TYPE"
    [[ "$SERVER_TYPE" == "modpack" ]] && echo "  Modpack        : $MODPACK"
    echo "  Version MC     : $MC_VERSION"
    echo "  RAM JVM        : ${RAM_GB} Go"
    echo "  Joueurs max    : $PLAYERS"
    echo "  Panel Crafty   : $INSTALL_CRAFTY"
    echo "════════════════════════════════════════════════════════"
    echo
    if [[ "$ASSUME_YES" != "true" ]]; then
        ask_yes_no "Confirmer et lancer l'installation ?" "y" || { info "Installation annulée."; exit 0; }
    fi
}

setup_ssh() {
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 \
        "${SSH_USER}@${ORACLE_IP}" "$@"
}

test_ssh_connectivity() {
    info "Test de connexion SSH vers ${SSH_USER}@${ORACLE_IP} ..."
    if setup_ssh "true" 2>/dev/null; then
        success "Connexion SSH OK."
    else
        die "Connexion SSH impossible. Vérifiez l'IP, la clé et que la VM est Running (voir docs/troubleshooting.md)."
    fi
}

transfer_files() {
    info "Transfert des fichiers vers la VM (${STAGING}) ..."
    setup_ssh "sudo rm -rf ${STAGING} && mkdir -p ${STAGING}/utils"
    scp -q -r -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new \
        "${SCRIPT_DIR}/deploy" "${SCRIPT_DIR}/configs" "${SCRIPT_DIR}/modpacks" \
        "${SSH_USER}@${ORACLE_IP}:${STAGING}/"
    scp -q -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new \
        "${SCRIPT_DIR}/utils/rcon_client.py" "${SSH_USER}@${ORACLE_IP}:${STAGING}/utils/"
    success "Fichiers transférés."
}

execute_remote_provision() {
    info "Exécution du provisionnement sur la VM (5 à 10 minutes) ..."
    setup_ssh "sudo bash ${STAGING}/deploy/remote_provision.sh \
        --ip '${ORACLE_IP}' --server-type '${SERVER_TYPE}' --mc-version '${MC_VERSION}' \
        --ram '${RAM_GB}' --players '${PLAYERS}' --crafty '${INSTALL_CRAFTY}' \
        --modpack '${MODPACK}' --pack-url '${PACK_URL}'"
}

save_server_conf() {
    cat > "$CONF_FILE" <<EOF
# Généré par setup.sh — configuration locale (ne pas versionner)
ORACLE_IP=${ORACLE_IP}
SSH_KEY_PATH=${SSH_KEY_PATH}
SSH_USER=${SSH_USER}
SERVER_TYPE=${SERVER_TYPE}
MC_VERSION=${MC_VERSION}
RAM_GB=${RAM_GB}
MODPACK=${MODPACK}
EOF
    chmod 600 "$CONF_FILE" 2>/dev/null || true
    success "Configuration locale sauvegardée dans .server.conf"
}

final_banner() {
    echo
    success "INSTALLATION TERMINÉE !"
    echo
    echo "  Prochaines étapes :"
    echo "   1. Ouvrez les Ingress Rules du VCN Oracle si ce n'est pas fait :"
    echo "      docs/oci-vcn-config.md  (TCP+UDP 25565, TCP 8443)"
    echo "   2. Dans Minecraft Java Edition : Multijoueur → Ajouter un serveur"
    echo "      Adresse : ${ORACLE_IP}:25565"
    if [[ "$SERVER_TYPE" == "modpack" || "$SERVER_TYPE" == "forge" || "$SERVER_TYPE" == "fabric" ]]; then
        echo "   3. Chaque joueur doit installer les MÊMES mods côté client"
        echo "      (CurseForge App → même modpack/version)."
    fi
    echo
    echo "  Sauvegardes : ./utils/backup.sh   —  Surveillance : ./utils/monitor.sh"
    echo "  Dépannage   : docs/troubleshooting.md"
}

main() {
    parse_args "$@"
    echo
    echo "=============================================================="
    echo "   Oracle Cloud Minecraft — Auto Setup v${VERSION}"
    echo "   Forge / Fabric / Vanilla / Modpacks — Always Free (ARM)"
    echo "=============================================================="

    check_local_prerequisites

    if [[ "$ASSUME_YES" == "true" ]]; then
        validate_non_interactive_config
    else
        show_preflight_checklist
        ask_ip
        ask_ssh_key
        ask_server_config
        validate_non_interactive_config
    fi

    confirm_summary

    if [[ "$DRY_RUN" == "true" ]]; then
        echo
        warn "MODE SIMULATION (--dry-run) : aucune action distante ne sera exécutée."
        echo "  Commandes qui seraient exécutées :"
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

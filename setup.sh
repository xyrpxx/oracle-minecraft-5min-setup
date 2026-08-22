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
ASSUME_YES="false" DRY_RUN="false" GUIDED_MODE="true"

usage() {
    cat <<EOF
Usage : setup.sh [options]
  (Sans option : assistant interactif en Mode guide, parfait pour débuter.
   Sous Windows, tu peux aussi simplement double-cliquer sur start-windows.bat)

  --mode <mode>         guide (défaut) | expert
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
            --mode)        case "$2" in
                               guide|guided) GUIDED_MODE="true" ;;
                               expert)       GUIDED_MODE="false" ;;
                               *) die "--mode attend 'guide' ou 'expert'" ;;
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
        info "Le guide complet pas à pas : docs/guide-debutant-fr.md"
        exit 0
    fi
}

# Attend patiemment que l'utilisateur ait fini une étape sur le navigateur.
wait_until_done() { # conseil
    local tip="$1"
    while true; do
        if ask_yes_no "C'est fait ?" "y"; then return 0; fi
        echo
        info "Pas de souci, prends ton temps — le programme attend sagement ici."
        info "Astuce : $tip"
    done
}

wizard_account() {
    echo
    echo "──────────────────────────────────────────────────────────────"
    echo "  ÉTAPE 1/3 — Ton compte Oracle (à ne faire qu'UNE seule fois)"
    echo "──────────────────────────────────────────────────────────────"
    if ask_yes_no "As-tu déjà un compte Oracle Cloud ?" "n"; then
        success "Parfait, on passe directement à la suite !"
        return 0
    fi
    echo
    info "Oracle va te PRÊTER gratuitement, à vie, un ordinateur dans le cloud."
    info "(C'est leur façon d'attirer des clients — et toi, tu en profites.)"
    info "Pour ça, il te faut un compte. Voici comment faire :"
    echo
    echo "   1. Va sur https://cloud.oracle.com → bouton « Start for free »"
    echo "   2. Donne un email + un mot de passe  (note-les quelque part !)"
    echo "   3. Nom, pays, numéro de téléphone (pour vérifier que tu existes)"
    echo "   4. Une carte bancaire sera demandée : c'est JUSTE une vérification"
    echo "      d'identité. Rien n'est prélevé tant que tu restes en gratuit."
    echo "      Demande l'autorisation d'un adulte si besoin 😉"
    echo "   5. Région (« Home Region ») : choisis UK South (Londres) ou"
    echo "      Germany Central (Francfort) — le plus proche = le moins de lag."
    echo "      ⚠ Ce choix est définitif et l'email de confirmation peut"
    echo "        mettre 30 minutes à arriver."
    echo
    if ask_yes_no "Veux-tu que j'ouvre la page d'inscription dans ton navigateur ?" "y"; then
        open_url "https://cloud.oracle.com" \
            || info "Impossible d'ouvrir le navigateur — va sur https://cloud.oracle.com"
    fi
    echo
    warn "Si Oracle propose « Upgrade to Pay As You Go » : REFUSE. Reste en gratuit."
    wait_until_done "l'email de confirmation peut prendre 30 minutes, va boire un verre d'eau 🥤"
}

wizard_vm() {
    echo
    echo "──────────────────────────────────────────────────────────────"
    echo "  ÉTAPE 2/3 — Créer la machine (la « VM ») de ton serveur"
    echo "──────────────────────────────────────────────────────────────"
    if ask_yes_no "Ta machine est-elle déjà créée (avec son adresse IP) ?" "n"; then
        success "Super, on passe à la configuration !"
        return 0
    fi
    echo
    info "Sur cloud.oracle.com : menu ☰ (en haut à gauche) → Compute → Instances"
    info "→ gros bouton bleu « Create instance ». Remplis EXACTEMENT ceci :"
    echo
    echo "   • Name          : ce que tu veux (ex. minecraft)"
    echo "   • Image [Edit]  : Ubuntu 22.04 ou 24.04   (PAS « Minimal »)"
    echo "   • Shape [Edit]  : onglet Ampere → VM.Standard.A1.Flex"
    echo "                     → OCPUs : 2    Memory : 12 GB"
    echo "   • SSH keys  ⚠ L'ÉTAPE LA PLUS IMPORTANTE ⚠"
    echo "       1. « Generate a key pair »"
    echo "       2. « Save Private Key » → garde ce fichier PRÉCIEUSEMENT :"
    echo "          c'est la clé de ta machine. Perdue = machine perdue !"
    echo "       3. « Save Public Key »"
    echo "   • Bouton « Create », puis patiente 2 à 5 minutes..."
    echo
    if ask_yes_no "Ouvrir la console Oracle dans ton navigateur ?" "y"; then
        open_url "https://cloud.oracle.com" \
            || info "Impossible d'ouvrir le navigateur — va sur https://cloud.oracle.com"
    fi
    wait_until_done "attends le statut vert « Running » sur la page de l'instance"
    echo
    success "Note bien le « Public IP Address » affiché (ex. 129.213.56.123) :"
    success "on va te le demander à l'étape suivante."
}

ask_ip() {
    if [[ "$GUIDED_MODE" == "true" ]]; then
        echo
        echo "──────────────────────────────────────────────────────────────"
        echo "  ÉTAPE 3/3 — Les informations de ton serveur"
        echo "──────────────────────────────────────────────────────────────"
        info "L'IP est l'« adresse postale » de ta machine : console Oracle →"
        info "Compute → Instances → colonne « Public IP Address »."
        info "Elle ressemble à : 129.213.56.123"
    fi
    while true; do
        read -r -p "→ IP publique de ta VM Oracle : " ORACLE_IP
        ORACLE_IP="${ORACLE_IP// /}"
        if is_valid_ipv4 "$ORACLE_IP"; then
            success "IP valide : $ORACLE_IP"
            break
        fi
        warn "Ce n'est pas une adresse IP valide. Exemple : 129.213.56.123"
        info "(copie-colle la valeur « Public IP Address » de la console Oracle)"
    done
}

ask_ssh_key() {
    echo
    if [[ "$GUIDED_MODE" == "true" ]]; then
        info "Maintenant, ta CLÉ : le fichier « Save Private Key » téléchargé quand tu"
        info "as créé la machine. C'est la clé de ta maison 🔑 — on va l'utiliser pour"
        info "ouvrir la porte de ton serveur. Elle se trouve souvent dans Téléchargements."
    else
        info "Clé SSH privée téléchargée depuis la console Oracle"
        info "(fichier du type ssh-key-2026-XX-XX.key ou *.pem, souvent dans Téléchargements)."
    fi
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
    info "💡 Astuce : pour chaque question, appuie simplement sur ENTRÉE pour"
    info "   garder la réponse conseillée — c'est ce qu'il y a de plus simple !"
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
        info "Dernière chose : l'adresse de téléchargement du « Server Pack »."
        info "Sur la page CurseForge du modpack : onglet Files → choisis une version"
        info "${MC_VERSION} → section Additional Files → clic droit sur le fichier"
        info "« Server Pack » → « Copier l'adresse du lien »."
        info "Exemple d'URL : https://mediafilez.forgecdn.net/files/1234/567/pack.zip"
        while true; do
            read -r -p "→ URL du server pack (.zip) : " PACK_URL
            is_valid_url "$PACK_URL" && break
            warn "URL invalide (URL http(s) directe, sans espaces ni caractères spéciaux)."
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
        is_valid_url "$PACK_URL" || die "--pack-url requis pour un modpack (URL http(s) directe valide)"
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
        success "Connexion réussie — la porte s'ouvre avec ta clé 🔓"
    else
        die "Impossible d'ouvrir la porte de ta machine 😕 Vérifie dans l'ordre :
  1. L'IP : c'est bien celle de « Public IP Address » sur la page de ton instance ?
  2. La clé : c'est bien le fichier « Save Private Key » téléchargé à la création ?
     (pas le « Public Key », et pas un autre fichier)
  3. La machine est « Running » (point vert) dans la console Oracle ?
Aide détaillée : docs/troubleshooting.md (section « Permission denied »)"
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
    info "C'est parti ! L'installation dure 5 à 10 minutes et tourne toute seule :"
    info "ton serveur est en train de naître 🐣 (tu peux aller boire un verre d'eau 🥤)"
    info "Exécution du provisionnement sur la VM ..."
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
    success "Configuration locale sauvegardée dans .server.conf"
}

final_banner() {
    echo
    success "INSTALLATION TERMINÉE ! 🎉"
    echo
    echo "══════════════════════════════════════════════════════════════"
    echo "   📍 L'ADRESSE DE TON SERVEUR (envoie-la à tes amis !) :"
    echo
    echo "          ${ORACLE_IP}:25565"
    echo "══════════════════════════════════════════════════════════════"
    echo
    echo "  ET MAINTENANT, 3 choses à savoir :"
    echo
    echo "  1️⃣  IL FAUT OUVRIR LES PORTS (une seule fois, 3 minutes, sinon"
    echo "     personne ne peut se connecter) → docs/oci-vcn-config.md"
    if [[ "$SERVER_TYPE" == "modpack" || "$SERVER_TYPE" == "forge" || "$SERVER_TYPE" == "fabric" ]]; then
        echo "  2️⃣  Chaque joueur doit installer les MÊMES mods sur SON ordi"
        echo "     avec l'app CurseForge (même modpack, même version)."
    else
        echo "  2️⃣  Dans Minecraft : Multijoueur → Ajouter un serveur → colle"
        echo "     l'adresse ci-dessus → Rejoindre !"
    fi
    echo "  3️⃣  Pour devenir le chef en jeu (admin), tape :"
    echo "         ./utils/console.sh \"op TonPseudo\""
    echo
    echo "  Boîte à outils : ./utils/backup.sh (sauvegarde) — ./utils/monitor.sh (surveillance)"
    echo "  Un problème ?  : docs/troubleshooting.md"
    echo
    if [[ "$ASSUME_YES" != "true" ]]; then
        if ask_yes_no "Ouvrir le guide « ouvrir les ports » dans ton navigateur maintenant ?" "y"; then
            open_url "https://github.com/xyrpxx/oracle-minecraft-5min-setup/blob/main/docs/oci-vcn-config.md" \
                || info "Lis le fichier docs/oci-vcn-config.md"
        fi
        if [[ "$INSTALL_CRAFTY" == "true" ]] \
           && ask_yes_no "Ouvrir le panel Crafty (interface web de ton serveur) ?" "y"; then
            open_url "https://${ORACLE_IP}:8443" \
                || info "Panel : https://${ORACLE_IP}:8443"
        fi
    fi
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
        ask_choice "Bienvenue ! Comment veux-tu procéder ?" \
            "Mode guide — je t'accompagne étape par étape (recommandé)" \
            "Mode expert — je sais déjà faire, va droit au but"
        if [[ "$SELECTED_CHOICE" == "1" ]]; then
            GUIDED_MODE="true"
        else
            GUIDED_MODE="false"
        fi
        echo
        if [[ "$GUIDED_MODE" == "true" ]]; then
            info "C'est parti ! On va faire ça ensemble, sans stress 😊"
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

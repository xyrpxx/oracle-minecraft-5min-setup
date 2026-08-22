#!/usr/bin/env bash
# =============================================================================
# update.sh — Met à jour le serveur (exécuté LOCALEMENT, via SSH).
# Réutilise /opt/minecraft/bin/remote_provision.sh --update-server :
# le monde, la configuration et l'EULA sont TOUJOURS préservés.
#
# Trois mises à jour possibles :
#   1. Moteur Vanilla/Fabric  → nouvelle version Minecraft
#   2. Forge                  → nouveau build Forge (même version MC)
#   3. Modpack                → nouveau server pack CurseForge (URL)
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

load_server_conf "${SCRIPT_DIR}/.server.conf"

echo
info "Serveur actuel : type=${SERVER_TYPE} version=${MC_VERSION} modpack=${MODPACK}"
ask_choice "Que voulez-vous mettre à jour ?" \
    "Moteur Vanilla/Fabric (changer de version Minecraft)" \
    "Forge (changer de build)" \
    "Modpack (nouveau server pack)"

COMMON_ARGS=(--ip "${ORACLE_IP}" --ram "${RAM_GB}" --server-type "${SERVER_TYPE}" --update-server)

case "$SELECTED_CHOICE" in
    1)
        while true; do
            read -r -p "→ Nouvelle version Minecraft (actuelle : ${MC_VERSION}) : " NEW_VERSION
            is_valid_mc_version "$NEW_VERSION" && break
            warn "Version invalide (ex. 1.20.1 ou 1.21)."
        done
        run_ssh "sudo bash /opt/minecraft/bin/remote_provision.sh \
            ${COMMON_ARGS[*]} --mc-version '${NEW_VERSION}' --modpack none --pack-url -"
        ;;
    2)
        while true; do
            read -r -p "→ Nouveau build Forge, format 47.2.0 (voir files.minecraftforge.net) : " NEW_BUILD
            is_valid_mc_version "$NEW_BUILD" && break
            warn "Format attendu : X.Y.Z (ex. 47.4.10)."
        done
        run_ssh "sudo bash /opt/minecraft/bin/remote_provision.sh \
            ${COMMON_ARGS[*]} --mc-version '${MC_VERSION}' --forge-build '${NEW_BUILD}' \
            --modpack none --pack-url -"
        ;;
    3)
        echo
        info "Collez l'URL DIRECTE du nouveau fichier « Server Pack » (CurseForge)."
        while true; do
            read -r -p "→ URL du server pack (.zip) : " NEW_PACK_URL
            is_valid_url "$NEW_PACK_URL" && break
            warn "URL invalide (URL http(s) directe, sans espaces ni caractères spéciaux)."
        done
        warn "Les fichiers du pack (mods/configs) seront remplacés ; le monde est conservé."
        ask_yes_no "Confirmer ?" "n" || { info "Mise à jour annulée."; exit 0; }
        run_ssh "sudo bash /opt/minecraft/bin/remote_provision.sh \
            ${COMMON_ARGS[*]} --mc-version '${MC_VERSION}' --server-type modpack \
            --modpack '${MODPACK}' --pack-url '${NEW_PACK_URL}'"
        ;;
esac

success "Mise à jour terminée. Vérifiez : ./utils/monitor.sh"

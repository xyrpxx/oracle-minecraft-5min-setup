#!/usr/bin/env bash
# =============================================================================
# remote_provision.sh — Provisionnement du serveur Minecraft sur la VM OCI.
#
# ⚠️ S'EXÉCUTE SUR LA VM Ubuntu (ARM64), jamais sur la machine locale.
#    setup.sh le transfère dans /tmp/setup/ puis le lance via SSH.
#
# Usage :
#   sudo bash remote_provision.sh --ip <IP_PUBLIQUE> \
#        --server-type <vanilla|forge|fabric|modpack> \
#        --mc-version <version> --ram <Go> [--players <n>] \
#        [--crafty <true|false>] [--modpack <id|none>] [--pack-url <url|->] \
#        [--forge-build <build>] [--update-server]
#
# Garanties :
#   - Idempotent : ré-exécutable sans dupliquer les règles ni écraser un monde.
#   - Le serveur tourne sous l'utilisateur dédié 'minecraft' (jamais root).
#   - Forge 1.17+ : lancement via @unix_args.txt (jamais java -jar).
# =============================================================================
set -euo pipefail

# --- Constantes ---
MOJANG_MANIFEST="https://piston-meta.mojang.com/mc/game/version_manifest.json"
FABRIC_META="https://meta.fabricmc.net/v2/versions/loader"
INSTALL_ROOT="/opt/minecraft"
SERVER_DIR="${INSTALL_ROOT}/server"
STAGING="/tmp/setup"

# Build Forge par défaut pour MC 1.20.1 (modifiable via --forge-build).
FORGE_BUILD="47.2.0"

# --- Variables remplies par les arguments ---
REMOTE_IP="" SERVER_TYPE="" MC_VERSION="" RAM_GB=""
PLAYERS="20" INSTALL_CRAFTY="false" MODPACK="none" PACK_URL="-" MODE="install"

die() { printf '\n[ERREUR FATALE] %s\n' "$*" >&2; exit 1; }
log()  { printf '[provision] %s\n' "$*"; }

usage() {
    sed -n 's/^# \{0,1\}//p' "$0" | sed -n '3,20p'
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ip)           REMOTE_IP="$2"; shift 2 ;;
            --server-type)  SERVER_TYPE="$2"; shift 2 ;;
            --mc-version)   MC_VERSION="$2"; shift 2 ;;
            --ram)          RAM_GB="$2"; shift 2 ;;
            --players)      PLAYERS="$2"; shift 2 ;;
            --crafty)       INSTALL_CRAFTY="$2"; shift 2 ;;
            --modpack)      MODPACK="$2"; shift 2 ;;
            --pack-url)     PACK_URL="$2"; shift 2 ;;
            --forge-build)  FORGE_BUILD="$2"; shift 2 ;;
            --update-server) MODE="update"; shift ;;
            -h|--help)      usage; exit 0 ;;
            *) die "Argument inconnu : $1 (voir --help)" ;;
        esac
    done
    [[ -n "$REMOTE_IP" ]]      || die "--ip requis"
    [[ -n "$SERVER_TYPE" ]]    || die "--server-type requis"
    case "$SERVER_TYPE" in
        vanilla|forge|fabric|modpack) ;;
        *) die "--server-type invalide : $SERVER_TYPE" ;;
    esac
    [[ "$MC_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || die "--mc-version invalide : $MC_VERSION"
    [[ "$RAM_GB" =~ ^[0-9]+$ ]] || die "--ram invalide : $RAM_GB"
    (( 10#$RAM_GB >= 2 && 10#$RAM_GB <= 8 )) \
        || die "--ram doit être entre 2 et 8 Go (12 Go au total, 4 Go réservés au système)"
    [[ "$PLAYERS" =~ ^[0-9]+$ && 10#$PLAYERS -ge 1 ]] || die "--players invalide"
    [[ "$INSTALL_CRAFTY" == "true" || "$INSTALL_CRAFTY" == "false" ]] || die "--crafty doit valoir true ou false"
    [[ "$FORGE_BUILD" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "--forge-build invalide : $FORGE_BUILD"
    if [[ "$SERVER_TYPE" == "modpack" ]]; then
        [[ "$PACK_URL" != "-" ]] || die "--pack-url requis pour un modpack (URL du server pack)"
        if [[ "$MODE" == "install" ]]; then
            [[ -f "${STAGING}/modpacks/${MODPACK}.json" ]] || die "Modpack inconnu : $MODPACK"
        fi
    fi
}

step_system_packages() {
    log "Mise à jour du système et installation des paquets..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq \
        openjdk-21-jre-headless \
        netfilter-persistent iptables-persistent \
        curl wget jq unzip screen htop python3 >/dev/null
    # Docker : best effort — certains miroirs 22.04 n'ont pas docker-compose-v2.
    # step_crafty réinstalle via get.docker.com si 'docker compose' manque.
    apt-get install -y -qq docker.io docker-compose-v2 >/dev/null 2>&1 || true
    log "Java installé : $(java -version 2>&1 | head -n 1)"
}

step_minecraft_user() {
    if id -u minecraft >/dev/null 2>&1; then
        log "Utilisateur système 'minecraft' déjà présent."
    else
        log "Création de l'utilisateur système 'minecraft' (sans privilèges)..."
        useradd -r -m -U -d "$INSTALL_ROOT" -s /usr/sbin/nologin minecraft
    fi
}

step_directories() {
    mkdir -p "${INSTALL_ROOT}/server" "${INSTALL_ROOT}/backups" "${INSTALL_ROOT}/bin"
    # Copie des outils d'administration (présents uniquement en mode install,
    # lorsque le staging /tmp/setup existe).
    if [[ -d "${STAGING}/utils" ]]; then
        cp "${STAGING}/utils/rcon_client.py" "${INSTALL_ROOT}/bin/rcon_client.py"
        cp "${STAGING}/deploy/remote_provision.sh" "${INSTALL_ROOT}/bin/remote_provision.sh"
        chmod 755 "${INSTALL_ROOT}/bin/rcon_client.py" "${INSTALL_ROOT}/bin/remote_provision.sh"
    fi
    chown -R minecraft:minecraft "$INSTALL_ROOT"
}

step_firewall() {
    log "Configuration du pare-feu iptables (OCI — ufw proscrit)..."
    bash "${STAGING}/deploy/configure_iptables.sh"
}

step_crafty() {
    if [[ "$INSTALL_CRAFTY" != "true" ]]; then return 0; fi
    log "Déploiement de Crafty Controller via Docker Compose..."
    if ! docker compose version >/dev/null 2>&1; then
        log "Plugin 'docker compose' indisponible — installation via le script officiel Docker..."
        curl -fsSL https://get.docker.com | sh
        docker compose version >/dev/null 2>&1 || die "Docker Compose reste indisponible après installation"
    fi
    systemctl enable --now docker >/dev/null 2>&1 || true
    mkdir -p "${INSTALL_ROOT}/docker-crafty"
    cp "${STAGING}/deploy/docker-compose.crafty.yml" "${INSTALL_ROOT}/docker-crafty/docker-compose.yml"
    chown -R minecraft:minecraft "${INSTALL_ROOT}/docker-crafty"
    ( cd "${INSTALL_ROOT}/docker-crafty" && docker compose up -d )
    log "Crafty Controller accessible sur https://${REMOTE_IP}:8443"
}

download_file() { # url destination
    curl -fsSL --retry 3 -o "$2" "$1" || die "Téléchargement échoué : $1"
}

generate_forge_start_script() {
    # Depuis Forge 1.17 : l'installateur ne produit plus un JAR autonome mais
    # libraries/ + unix_args.txt. Le lancement DOIT passer par @unix_args.txt.
    local unix_args rel
    unix_args="$(find "${SERVER_DIR}/libraries/net/minecraftforge/forge" \
        -name unix_args.txt -type f 2>/dev/null | head -n 1)"
    [[ -n "$unix_args" ]] || die "unix_args.txt introuvable — installation Forge en échec"
    rel="${unix_args#"${SERVER_DIR}/"}"
    cat > "${SERVER_DIR}/start.sh" <<EOF
#!/bin/bash
# Démarrage Forge — généré par remote_provision.sh (amorçage @unix_args.txt)
cd "\$(dirname "\$0")"
exec java @user_jvm_args.txt @${rel} nogui "\$@"
EOF
    chown minecraft:minecraft "${SERVER_DIR}/start.sh"
    chmod 755 "${SERVER_DIR}/start.sh"
}

write_simple_start_script() { # jar_name
    cat > "${SERVER_DIR}/start.sh" <<EOF
#!/bin/bash
# Démarrage ${SERVER_TYPE} — généré par remote_provision.sh
cd "\$(dirname "\$0")"
exec java @user_jvm_args.txt -jar "$1" nogui "\$@"
EOF
    chown minecraft:minecraft "${SERVER_DIR}/start.sh"
    chmod 755 "${SERVER_DIR}/start.sh"
}

install_engine_vanilla() {
    log "Installation Vanilla ${MC_VERSION} (résolution via piston-meta)..."
    local version_url server_url
    version_url="$(curl -fsSL "$MOJANG_MANIFEST" \
        | jq -r --arg v "$MC_VERSION" '.versions[] | select(.id==$v) | .url')"
    [[ -n "$version_url" && "$version_url" != "null" ]] \
        || die "Version Vanilla introuvable : ${MC_VERSION}"
    server_url="$(curl -fsSL "$version_url" | jq -r '.downloads.server.url')"
    [[ -n "$server_url" && "$server_url" != "null" ]] \
        || die "Pas de binaire serveur pour ${MC_VERSION}"
    download_file "$server_url" "${SERVER_DIR}/server.jar"
    chown minecraft:minecraft "${SERVER_DIR}/server.jar"
    write_simple_start_script "server.jar"
}

resolve_forge_build() {
    # Dernier build « recommended » publié pour cette version MC, avec repli
    # sur le build épinglé (FORGE_BUILD) si l'API Forge est injoignable.
    local build=""
    build="$(curl -fsSL --max-time 20 \
        https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json \
        | jq -r --arg v "$MC_VERSION" \
            '.promos[$v + "-recommended"] // .promos[$v + "-latest"] // empty' 2>/dev/null || true)"
    if [[ "$build" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        FORGE_BUILD="$build"
        log "Build Forge résolu dynamiquement : ${FORGE_BUILD}"
    else
        log "Résolution Forge impossible — repli sur le build épinglé ${FORGE_BUILD}"
    fi
}

install_engine_forge() {
    resolve_forge_build
    local coords="${MC_VERSION}-${FORGE_BUILD}"
    local base="https://maven.minecraftforge.net/net/minecraftforge/forge/${coords}"
    local installer="forge-${coords}-installer.jar"
    log "Installation Forge ${coords} (2 à 3 minutes)..."
    download_file "${base}/${installer}" "${SERVER_DIR}/${installer}"
    ( cd "$SERVER_DIR" && sudo -u minecraft java -jar "$installer" --installServer "$SERVER_DIR" )
    rm -f "${SERVER_DIR:?}/${installer}"
    generate_forge_start_script
}

install_engine_fabric() {
    log "Installation Fabric ${MC_VERSION}..."
    local loader launcher dest="${SERVER_DIR}/fabric-server-launch.jar"
    # Loader compatible avec CETTE version du jeu (et non le dernier loader
    # global, qui peut ne plus la supporter).
    loader="$(curl -fsSL "${FABRIC_META}/${MC_VERSION}" | jq -r '.[0].loader.version')"
    [[ -n "$loader" && "$loader" != "null" ]] || die "Loader Fabric introuvable pour ${MC_VERSION}"
    # L'API meta exige une URL à 3 segments (jeu/loader/launcher) : on résout
    # le launcher dynamiquement, avec repli sur une version épinglée.
    launcher="$(curl -fsSL --max-time 20 "https://meta.fabricmc.net/v2/versions/installer" \
        | jq -r '.[0].version' 2>/dev/null || true)"
    [[ "$launcher" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || launcher="1.1.0"
    local url_ok=""
    for u in "${FABRIC_META}/${MC_VERSION}/${loader}/${launcher}/server/jar" \
             "${FABRIC_META}/${MC_VERSION}/${loader}/1.1.0/server/jar"; do
        if curl -fsSL --retry 2 -o "$dest" "$u"; then
            url_ok="$u"
            break
        fi
    done
    [[ -n "$url_ok" ]] || die "Server jar Fabric introuvable pour ${MC_VERSION} (loader ${loader})"
    log "Server jar Fabric : ${url_ok}"
    chown minecraft:minecraft "$dest"
    write_simple_start_script "fabric-server-launch.jar"
}

install_modpack_pack() {
    log "Installation du modpack '${MODPACK}' depuis le server pack..."
    local zip="${SERVER_DIR}/modpack-server-pack.zip"
    download_file "$PACK_URL" "$zip"
    ( cd "$SERVER_DIR" && unzip -oq "$zip" )
    rm -f "$zip"
    chown -R minecraft:minecraft "$SERVER_DIR"

    # Certains server packs s'extraient dans un sous-dossier unique :
    # on remonte son contenu à la racine du serveur.
    local sub="" has_engine=0
    find "${SERVER_DIR}/libraries" -name unix_args.txt -type f 2>/dev/null | grep -q . && has_engine=1
    [[ -f "${SERVER_DIR}/run.sh" ]] && has_engine=1
    if (( has_engine == 0 )); then
        sub="$(find "$SERVER_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
        if [[ -n "$sub" ]] && { [[ -f "${sub}/run.sh" ]] || find "$sub" -name unix_args.txt -type f | grep -q .; }; then
            log "Server pack extrait dans '${sub##*/}' — remontée du contenu..."
            ( cd "$sub" && find . -mindepth 1 -maxdepth 1 -exec mv -t "$SERVER_DIR" -- {} + )
            rmdir "$sub" 2>/dev/null || true
            chown -R minecraft:minecraft "$SERVER_DIR"
        fi
    fi

    if find "${SERVER_DIR}/libraries" -name unix_args.txt -type f 2>/dev/null | grep -q .; then
        generate_forge_start_script        # server pack Forge standard
    elif [[ -f "${SERVER_DIR}/run.sh" ]]; then
        printf '#!/bin/bash\ncd "$(dirname "$0")"\nexec bash run.sh nogui "$@"\n' \
            > "${SERVER_DIR}/start.sh"     # server pack avec run.sh
        chown minecraft:minecraft "${SERVER_DIR}/start.sh"
        chmod 755 "${SERVER_DIR}/start.sh"
    else
        die "Server pack inattendu : ni unix_args.txt ni run.sh trouvé (layout non standard)"
    fi
}

apply_server_config() {
    log "Application de la configuration (properties, EULA, JVM, RCON)..."
    local props="${SERVER_DIR}/server.properties"
    cp "${STAGING}/configs/server.properties.template" "$props"
    sed -i "s/^max-players=.*/max-players=${PLAYERS}/" "$props"
    # Mot de passe RCON aléatoire, injecté puis stocké localement à la VM.
    local rcon_pass
    rcon_pass="$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)"
    [[ ${#rcon_pass} -ge 16 ]] || die "Génération du mot de passe RCON échouée"
    sed -i "s/__RCON_PASSWORD__/${rcon_pass}/" "$props"
    printf 'RCON_HOST=127.0.0.1\nRCON_PORT=25575\nRCON_PASSWORD=%s\n' "$rcon_pass" \
        > "${SERVER_DIR}/.rcon-credentials"
    chmod 600 "${SERVER_DIR}/.rcon-credentials"
    cp "${STAGING}/configs/eula.txt" "${SERVER_DIR}/eula.txt"
    sed "s/__RAM__/${RAM_GB}/g" "${STAGING}/configs/user_jvm_args.txt.template" \
        > "${SERVER_DIR}/user_jvm_args.txt"
    chown -R minecraft:minecraft "$SERVER_DIR"
}

step_systemd() {
    log "Installation du service systemd 'minecraft'..."
    cat > /etc/systemd/system/minecraft.service <<'EOF'
[Unit]
Description=Serveur Minecraft (oracle-minecraft-5min-setup)
After=network.target

[Service]
User=minecraft
Group=minecraft
WorkingDirectory=/opt/minecraft/server
ExecStart=/bin/bash /opt/minecraft/server/start.sh
Restart=on-failure
RestartSec=20s
SuccessExitStatus=0 143
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable minecraft >/dev/null
}

step_first_boot() {
    log "Démarrage du serveur (génération du monde : 1 à 5 minutes)..."
    systemctl restart minecraft
    local i
    for i in $(seq 1 60); do
        if ss -tln | grep -q ':25565 '; then
            log "Port 25565 en écoute — serveur démarré."
            return 0
        fi
        systemctl is-active --quiet minecraft || break
        sleep 5
    done
    echo "---- 50 dernières lignes du journal du service ----"
    journalctl -u minecraft -n 50 --no-pager || true
    die "Le serveur n'est pas encore en écoute (voir journal ci-dessus). S'il s'agit d'un gros modpack, il peut simplement être lent : surveillez 'systemctl status minecraft'."
}

final_summary() {
    echo
    echo "=============================================================="
    echo "  Serveur Minecraft opérationnel !"
    echo "  Adresse de connexion : ${REMOTE_IP}:25565"
    if [[ "$INSTALL_CRAFTY" == "true" ]]; then
        echo "  Panel Crafty         : https://${REMOTE_IP}:8443"
    fi
    echo "  Gestion              : ssh ${SUDO_USER:-ubuntu}@${REMOTE_IP} 'systemctl status minecraft'"
    echo "=============================================================="
    echo "  Si la connexion depuis Minecraft échoue : ouvrez les"
    echo "  Ingress Rules du VCN Oracle (docs/oci-vcn-config.md)."
    echo "=============================================================="
}

main() {
    parse_args "$@"
    [[ $EUID -eq 0 ]] || die "Ce script doit être lancé avec sudo"

    step_system_packages
    step_minecraft_user
    step_directories

    if [[ "$MODE" == "install" ]]; then
        step_firewall
    fi

    if [[ "$MODE" == "install" && -d "${SERVER_DIR}/world" && -f "${SERVER_DIR}/server.properties" ]]; then
        log "Monde existant détecté — préservé (utilisez --update-server pour changer de version)."
    else
        case "$SERVER_TYPE" in
            vanilla) install_engine_vanilla ;;
            forge)   install_engine_forge ;;
            fabric)  install_engine_fabric ;;
            modpack) install_modpack_pack ;;
        esac
        # En mode update, on ne touche NI au monde NI à la configuration.
        if [[ "$MODE" == "install" ]]; then
            apply_server_config
        fi
    fi

    if [[ "$MODE" == "install" ]]; then
        step_crafty
    fi

    step_systemd
    step_first_boot

    [[ -d "$STAGING" ]] && rm -rf "$STAGING"
    final_summary
}

main "$@"

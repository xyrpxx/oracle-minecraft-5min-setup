#!/usr/bin/env bash
# =============================================================================
# crafty-seed.sh — Auto-import du serveur dans Crafty Controller via son API.
#
# Contexte : Crafty Controller expose une API v2. Par défaut, l'utilisateur
# doit cliquer "Import Server" et pointer vers un dossier. Ce script fait ça
# en headless : l'utilisateur n'a plus qu'à se connecter et cliquer "Start".
#
# Prérequis : le mot de passe admin Crafty dans $ENV_FILE
#   (CRAFTY_ADMIN_PASSWORD=...). Au premier démarrage, Crafty l'affiche dans :
#     ssh ubuntu@IP 'sudo docker logs crafty_controller'
# Copiez-le dans /opt/minecraft/.env (chmod 600), puis lancez :
#     sudo /opt/minecraft/bin/crafty-seed.sh
#
# Étapes :
#   1. Attend que l'API Crafty réponde (jusqu'à 3 min — premier boot lent).
#   2. Login POST /api/v2/auth/login  → récupère un JWT (en mémoire only).
#   3. Crée le serveur POST /api/v2/servers avec type=download_jar
#      puis on met à jour le chemin via PATCH /api/v2/servers/{id}.
#
# Idempotent : si le serveur existe déjà (nom exact), on n'en crée pas de second.
# Certificat : Crafty utilise un cert auto-signé → curl -k (documenté, LAN only).
# =============================================================================
set -euo pipefail

CRAFTY_URL="${CRAFTY_URL:-https://127.0.0.1:8443}"
SERVER_DIR="${SERVER_DIR:-/opt/minecraft/server}"
ENV_FILE="${ENV_FILE:-/opt/minecraft/.env}"
SERVER_NAME="${SERVER_NAME:-minecraft}"
CRAFTY_PUBLIC_IP="${CRAFTY_PUBLIC_IP:-}"

# Ne lit QUE les clés connues (jamais 'source' : une ligne malveillante
# dans .env ne doit pas s'exécuter comme du code).
[[ -f "$ENV_FILE" ]] || { printf '[crafty-seed] %s introuvable\n' "$ENV_FILE" >&2; exit 1; }
CRAFTY_ADMIN_PASSWORD="$(grep -E '^CRAFTY_ADMIN_PASSWORD=' "$ENV_FILE" | cut -d= -f2- | tail -1)"
[[ -n "${CRAFTY_ADMIN_PASSWORD:-}" ]] \
    || { printf '[crafty-seed] CRAFTY_ADMIN_PASSWORD absent de %s\n' "$ENV_FILE" >&2; exit 1; }
export CRAFTY_ADMIN_PASSWORD

CURL_OPTS=(--max-time 15 --retry 2 --retry-delay 5)

# 1. Attendre que l'API soit up (premier boot Crafty = migrations lentes).
printf '[crafty-seed] Attente de %s ...\n' "$CRAFTY_URL"
for _ in $(seq 1 36); do
    if curl -fsSL -k "${CURL_OPTS[@]}" "${CRAFTY_URL}/api/v2/auth/login" \
        -X POST -H "Content-Type: application/json" -d '{}' >/dev/null 2>&1; then
        break # l'API répond (même en 4xx : le serveur est up)
    fi
    # L'endpoint login peut ne pas exister sur vieilles versions : on teste
    # aussi la racine web comme signal de vie.
    if curl -fsSL -k "${CURL_OPTS[@]}" "${CRAFTY_URL}/" >/dev/null 2>&1; then
        break
    fi
    sleep 5
done
curl -fsk "${CURL_OPTS[@]}" "${CRAFTY_URL}/" >/dev/null 2>&1 \
    || { printf '[crafty-seed] API injoignable après 3 min.\n' >&2; exit 1; }

# JSON construit via python3 : aucun caractère du mot de passe (", \, $...)
# ne peut casser le payload ni fuiter via ps (lu depuis l'environnement).
json_login() {
    python3 -c 'import json,os; print(json.dumps({"username":"admin","password":os.environ["CRAFTY_ADMIN_PASSWORD"]}))'
}

login() {
    curl -fsSL -k "${CURL_OPTS[@]}" -X POST "${CRAFTY_URL}/api/v2/auth/login" \
        -H "Content-Type: application/json" \
        -d "$(json_login)" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["token"])'
}

list_servers() {
    curl -fsSL -k "${CURL_OPTS[@]}" -H "Authorization: Bearer ${TOKEN}" \
        "${CRAFTY_URL}/api/v2/servers" \
        | python3 -c 'import sys,json
data=json.load(sys.stdin)["data"]
for s in data: print(s["server_id"], s.get("server_name",""))'
}

create_server() {
    local payload
    payload="$(SERVER_NAME="$SERVER_NAME" python3 -c 'import json,os; print(json.dumps({"server_name":os.environ["SERVER_NAME"],"type":"download_jar"}))')"
    curl -fsSL -k "${CURL_OPTS[@]}" -X POST "${CRAFTY_URL}/api/v2/servers" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["server_id"])'
}

patch_server_path() { # $1 = server_id (numérique, validé ci-dessous)
    [[ "$1" =~ ^[0-9]+$ ]] || { printf '[crafty-seed] server_id inattendu : %s\n' "$1" >&2; exit 1; }
    local payload
    payload="$(SERVER_DIR="$SERVER_DIR" python3 -c 'import json,os; print(json.dumps({"server_path":os.environ["SERVER_DIR"],"executable":"java","executable_args":"-Xms4G -Xmx8G -jar @unix_args.txt","stop_command":"stop"}))')"
    curl -fsSL -k "${CURL_OPTS[@]}" -X PATCH "${CRAFTY_URL}/api/v2/servers/$1" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$payload"
}

TOKEN="$(login)"
printf '[crafty-seed] Connecté à Crafty.\n'

# Idempotence : comparaison sur le nom EXACT (pas de substring : "mine"
# ne doit pas matcher "minecraft").
if list_servers | awk '{print $2}' | grep -q -x -F "${SERVER_NAME}"; then
    printf '[crafty-seed] Serveur "%s" déjà présent dans Crafty. Aucun changement.\n' "${SERVER_NAME}"
    exit 0
fi

ID="$(create_server)"
printf '[crafty-seed] Serveur "%s" créé (id=%s).\n' "${SERVER_NAME}" "${ID}"
patch_server_path "${ID}"
printf '[crafty-seed] Chemin d'"'"'exécution pointé vers %s.\n' "${SERVER_DIR}"

# IP publique : override explicite > première IP non-Docker (172.x = bridges).
PUB_IP="$CRAFTY_PUBLIC_IP"
if [[ -z "$PUB_IP" ]]; then
    PUB_IP="$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v -E '^(172\.|127\.)' | head -1)"
    [[ -n "$PUB_IP" ]] || PUB_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
printf '[crafty-seed] Terminé. Ouvre https://%s:8443 et clique "Start".\n' "$PUB_IP"

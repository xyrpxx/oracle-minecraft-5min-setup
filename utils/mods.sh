#!/usr/bin/env bash
# =============================================================================
# mods.sh — Installer des mods et modpacks depuis Modrinth, façon Aternos.
# (exécuté LOCALEMENT ; la recherche et l'installation tournent sur la VM)
#
#   ./utils/mods.sh
#
# - Catalogue : api.modrinth.com (gratuit, sans clé ni compte)
# - On cherche → on choisit un numéro → c'est installé et le serveur redémarre
# - Les modpacks (.mrpack) sont résolus sur la VM (jq y est installé) :
#   chaque fichier est téléchargé avec vérification sha1, ceux marqués
#   « non supporté côté serveur » sont sautés, les overrides sont appliqués
# - Une sauvegarde éclair de mods/ + config/ est faite avant modification
#
# CurseForge reste possible via ./utils/update.sh (URL de server pack).
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

UA="oracle-minecraft-setup/3.6 (https://github.com/xyrpxx/oracle-minecraft-5min-setup)"

if [[ $# -gt 0 ]]; then
    sed -n 's/^# \{0,1\}//p' "$0" | sed -n '3,14p'
    exit 0
fi

load_server_conf "${SCRIPT_DIR}/.server.conf"

echo
info "Catalogue de mods et modpacks — Modrinth (gratuit, sans compte)"

ask_choice "Que veux-tu installer ?" \
    "Un modpack complet (remplace les mods actuels)" \
    "Un mod individuel (s'ajoute aux mods existants)"
KIND="mod"
[[ "$SELECTED_CHOICE" == "1" ]] && KIND="modpack"

case "$SERVER_TYPE" in
    forge)   LOADER="forge" ;;
    fabric)  LOADER="fabric" ;;
    modpack) LOADER="forge" ;;
    *) die "Ton serveur est Vanilla : il ne charge pas de mods. Utilise d'abord « Mettre à jour » (menu 5 ou ./utils/update.sh) pour passer sur Forge ou Fabric."
esac
read -r -p "→ Loader [${LOADER}] : " LOADER_IN
LOADER="${LOADER_IN:-$LOADER}"
[[ "$LOADER" == "forge" || "$LOADER" == "fabric" ]] || die "Loader invalide : forge ou fabric uniquement."

read -r -p "→ Version Minecraft [${MC_VERSION}] : " MCV_IN
MCV="${MCV_IN:-$MC_VERSION}"
is_valid_mc_version "$MCV" || die "Version invalide : $MCV"

read -r -p "→ Recherche (mots-clés, ex. create, sodium, better mc) : " QUERY
QUERY="${QUERY// / }"
local_re='^[A-Za-z0-9 _.-]{2,60}$'
[[ "$QUERY" =~ $local_re ]] || die "Recherche invalide (lettres, chiffres, espaces, - _ . uniquement)."

FACETS="[[\"project_type:${KIND}\"],[\"versions:${MCV}\"],[\"loaders:${LOADER}\"]]"
echo
info "Résultats pour « ${QUERY} » (${KIND} · ${MCV} · ${LOADER}, triés par popularité) :"

LISTING="$(run_ssh "sudo bash -s -- '${QUERY}' '${KIND}' '${MCV}' '${LOADER}'" <<'REMOTE'
set -euo pipefail
Q="$1"; KIND="$2"; MCV="$3"; LOADER="$4"
curl -fsSL -A "oracle-minecraft-setup/3.6" -G "https://api.modrinth.com/v2/search" \
    --data-urlencode "limit=10" \
    --data-urlencode "index=downloads" \
    --data-urlencode "query=${Q}" \
    --data-urlencode "facets=[[\"project_type:${KIND}\"],[\"versions:${MCV}\"],[\"loaders:${LOADER}\"]]" \
    | jq -r '.hits[] | "\(.title) | \(.slug) | \(.downloads) téléchargements"'
REMOTE
)" || die "Recherche impossible (connexion ? catalogue vide pour ces critères ?)"
[[ -n "$LISTING" ]] || die "Aucun résultat pour ces critères."

i=1
while IFS= read -r line; do
    printf '  %2d) %s\n' "$i" "$line"
    i=$((i + 1))
done <<< "$LISTING"

TOTAL=$(( i - 1 ))
while true; do
    read -r -p "→ Numéro à installer [1] : " pick
    pick="${pick:-1}"
    [[ "$pick" =~ ^[0-9]+$ && 10#$pick -ge 1 && 10#$pick -le 10#$TOTAL ]] && break
    warn "Choix invalide."
done
SLUG="$(sed -n "${pick}p" <<< "$LISTING" | awk -F'|' '{print $2}' | tr -d ' ')"
[[ "$SLUG" =~ ^[a-z0-9][a-z0-9_-]{0,63}$ ]] || die "Identifiant de projet inattendu : $SLUG"

warn "Le contenu actuel de mods/config sera remplacé si le pack le prévoit"
warn "(une sauvegarde éclair est faite automatiquement avant)."
ask_yes_no "Installer maintenant ?" "y" || { info "Annulé."; exit 0; }

run_ssh "sudo bash -s -- '${SLUG}' '${KIND}' '${MCV}' '${LOADER}'" <<'REMOTE'
set -euo pipefail
SLUG="$1"; KIND="$2"; MCV="$3"; LOADER="$4"
UA="oracle-minecraft-setup/3.6"
S=/opt/minecraft/server
B=/opt/minecraft/backups
mkdir -p "$B"

meta() { curl -fsSL -A "$UA" "$1"; }

# Sauvegarde éclair avant modification (mods + configs)
tar czf "${B}/pre-mods-$(date +%Y%m%d-%H%M%S).tar.gz" -C "$S" mods config 2>/dev/null || true
echo "[backup] Copie de sécurité créée dans /opt/minecraft/backups/"

API="https://api.modrinth.com/v2/project/${SLUG}/version?game_versions=%5B%22${MCV}%22%5D&loaders=%5B%22${LOADER}%22%5D"

fetch_primary() { # json_version -> url fichier principal
    jq -r '[.[0].files[] | select(.primary)][0].url // .[0].files[0].url'
}

if [[ "$KIND" == "mod" ]]; then
    V="$(meta "$API")"
    URL="$(jq -r . <<<"$V" | fetch_primary)"
    NAME="$(jq -r '[.[0].files[] | select(.primary)][0].filename // .[0].files[0].filename' <<<"$V")"
    SHA="$(jq -r '[.[0].files[] | select(.primary)][0].hashes.sha1 // ""' <<<"$V")"
    curl -fsSL -A "$UA" -o "${S}/mods/${NAME}" "$URL"
    if [[ -n "$SHA" ]]; then
        echo "$SHA  ${S}/mods/${NAME}" | sha1sum -c - >/dev/null \
            || { echo "[ERREUR] sha1 incorrect pour ${NAME}" >&2; rm -f "${S}/mods/${NAME}"; exit 1; }
        echo "[ok] sha1 vérifié : ${NAME}"
    fi
    echo "[+] Mod installé : ${NAME}"
else
    URL="$(meta "$API" | fetch_primary)"
    T="$(mktemp -d)"
    curl -fsSL -A "$UA" -o "${T}/pack.mrpack" "$URL"
    mkdir -p "${T}/x"
    unzip -q "${T}/pack.mrpack" -d "${T}/x"
    IDX="${T}/x/modrinth.index.json"
    TOTAL="$(jq -r '.files | length' "$IDX")"
    echo "[+] Pack « $(jq -r '.name // "'$SLUG'"' "$IDX") » — ${TOTAL} fichiers serveur…"
    N=0
    jq -r '.files[]
        | select((.env.server // "required") != "unsupported")
        | [.downloads[0], .path, (.hashes.sha1 // "")] | @tsv' "$IDX" > "${T}/list.tsv"
    while IFS=$'\t' read -r url path sha; do
        dest="${S}/${path}"
        mkdir -p "$(dirname "$dest")"
        curl -fsSL -A "$UA" -o "$dest" "$url"
        if [[ -n "$sha" ]]; then
            echo "$sha  $dest" | sha1sum -c - >/dev/null \
                || { echo "[ERREUR] sha1 incorrect : $path" >&2; exit 1; }
        fi
        N=$((N + 1))
        echo "  [$N/$TOTAL] $path"
    done < "${T}/list.tsv"
    if [[ -d "${T}/x/overrides" ]]; then
        cp -a "${T}/x/overrides/." "$S/"
        echo "[+] Overrides du pack appliqués (configs…)"
    fi
    rm -rf "$T"
fi

chown -R minecraft:minecraft /opt/minecraft/server
systemctl restart minecraft
echo "[ok] Serveur redémarré avec le nouveau contenu."
REMOTE

success "Installation terminée ! Rejoins le serveur et vérifie en jeu."

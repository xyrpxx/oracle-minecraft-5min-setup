#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"

# shellcheck source=scripts/lib.sh
. "${REPO_ROOT}/scripts/lib.sh"

echo "-- présence --"
for f in manifest.json better-minecraft.json atm9-light.json vanilla-plus.json; do
    assert_file_exists "modpacks/$f" "modpacks/$f présent"
done

echo "-- cohérence du registre --"
assert_exit_zero "better-minecraft référencé"  modpack_id_exists better-minecraft "${REPO_ROOT}/modpacks/manifest.json"
assert_exit_zero "atm9-light référencé"        modpack_id_exists atm9-light       "${REPO_ROOT}/modpacks/manifest.json"
assert_exit_zero "vanilla-plus référencé"      modpack_id_exists vanilla-plus     "${REPO_ROOT}/modpacks/manifest.json"

echo "-- champs obligatoires par modpack --"
check_pack() { # fichier
    local f="modpacks/$1"
    for key in '"id"' '"nom"' '"description"' '"difficulte"' '"loader"' '"mc_version"' '"ram_recommandee_go"' '"instructions"'; do
        assert_file_contains "$f" "$key" "$1 contient $key"
    done
}
check_pack better-minecraft.json
check_pack atm9-light.json
check_pack vanilla-plus.json

echo "-- validation JSON (si python3 disponible) --"
if command -v python3 >/dev/null 2>&1; then
    for f in manifest.json better-minecraft.json atm9-light.json vanilla-plus.json; do
        assert_exit_zero "JSON valide : $f" python3 -m json.tool "modpacks/$f"
    done
else
    echo "  (python3 absent — validation JSON syntaxique sautée)"
fi

finish_tests

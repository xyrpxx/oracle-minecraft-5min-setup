#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"

echo "-- manage.sh (menu unique de gestion) --"
assert_file_exists manage.sh "manage.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n manage.sh
assert_file_contains manage.sh "load_server_conf" "utilise .server.conf"
assert_file_contains manage.sh "utils/monitor.sh"        "entrée : état du serveur"
assert_file_contains manage.sh "utils/console.sh"        "entrée : commandes de jeu"
assert_file_contains manage.sh "utils/backup.sh"         "entrée : sauvegarde"
assert_file_contains manage.sh "utils/restore.sh"        "entrée : restauration"
assert_file_contains manage.sh "utils/update.sh"         "entrée : mise à jour"
assert_file_contains manage.sh "whitelist_manager.sh"    "entrée : whitelist"
assert_file_contains manage.sh "hardening.sh"            "entrée : sécurité"
assert_file_contains manage.sh "setup.sh"                "entrée : réinstaller/réparer"
assert_file_contains manage.sh "open_url"                "entrée : ouvrir Crafty (web)"
assert_file_not_contains manage.sh "ufw allow"           "aucune commande ufw"

echo "-- comportement non interactif (choix 0 = quitter) --"
out="$(printf '0\n' | bash manage.sh 2>&1)" && rc=0 || rc=1
assert_equals "0" "$rc" "menu sort proprement sur 0"
assert_contains "$out" "MENU" "le menu s'affiche"

finish_tests

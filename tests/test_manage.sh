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
assert_file_contains manage.sh "utils/mods.sh"           "entrée : mods/modpacks Modrinth"
assert_file_contains manage.sh "whitelist_manager.sh"    "entrée : whitelist"
assert_file_contains manage.sh "hardening.sh"            "entrée : sécurité"
assert_file_contains manage.sh "setup.sh"                "entrée : réinstaller/réparer"
assert_file_contains manage.sh "open_url"                "entrée : ouvrir Crafty (web)"
assert_file_not_contains manage.sh "ufw allow"           "aucune commande ufw"

echo "-- cohérence du menu (10 entrées, pas 9) --"
assert_file_contains manage.sh "M_MENU_BAD"   "le message d'erreur passe par i18n"
assert_file_contains manage.sh "M_MENU_10"    "l'entrée 10 passe par i18n (installer/réparer)"
assert_file_contains manage.sh "M_MENU_9"     "l'entrée 9 passe par i18n (sous-menu OCI)"
assert_file_contains scripts/lang_fr.sh "0 à 10" "le message d'erreur FR annonce '0 à 10'"

echo "-- comportement non interactif (choix 0 = quitter) --"
out="$(printf '0\n' | bash manage.sh 2>&1)" && rc=0 || rc=1
assert_equals "0" "$rc" "menu sort proprement sur 0"
assert_contains "$out" "MENU" "le menu s'affiche"

echo "-- internationalisation (fr/en via lang_*.sh) --"
assert_file_contains manage.sh 'lang_${UI_LANG}' "chargement dynamique de la langue"
assert_file_contains manage.sh 'M_MENU_TITLE'   "titre du menu via i18n"
assert_file_contains manage.sh 'M_OCI_TITLE'    "sous-menu OCI via i18n"
assert_file_not_contains manage.sh 'GESTION DU SERVEUR' "plus de titre français en dur"
assert_file_not_contains manage.sh 'Appuie sur Entrée' "plus de pause française en dur"
assert_file_contains scripts/lang_fr.sh 'M_MENU_TITLE' "catalogue menu (fr)"
assert_file_contains scripts/lang_en.sh 'M_MENU_TITLE' "catalogue menu (en)"
assert_file_contains scripts/lang_fr.sh 'M_OCI_E'      "auto-import Crafty documenté (fr)"
assert_file_contains scripts/lang_en.sh 'M_OCI_E'      "auto-import Crafty documenté (en)"
out_fr="$(printf '0\n' | bash manage.sh --lang fr 2>&1)" && rc=0 || rc=1
assert_equals "0" "$rc" "menu FR sort proprement sur 0"
assert_contains "$out_fr" "GESTION DU SERVEUR" "menu FR en français"
out_en="$(printf '0\n' | bash manage.sh --lang en 2>&1)" && rc=0 || rc=1
assert_equals "0" "$rc" "menu EN sort proprement sur 0"
assert_contains "$out_en" "MANAGEMENT" "menu EN en anglais"

finish_tests

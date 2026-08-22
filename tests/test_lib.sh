#!/usr/bin/env bash
# Tests unitaires de scripts/lib.sh — partie validations de base
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"
# shellcheck source=scripts/lib.sh
. "${REPO_ROOT}/scripts/lib.sh"

echo "-- is_valid_ipv4 --"
assert_exit_zero    "IPv4 192.168.1.1 valide"          is_valid_ipv4 192.168.1.1
assert_exit_zero    "IPv4 0.0.0.0 valide"              is_valid_ipv4 0.0.0.0
assert_exit_zero    "IPv4 255.255.255.255 valide"      is_valid_ipv4 255.255.255.255
assert_exit_zero    "IPv4 129.213.56.123 valide"       is_valid_ipv4 129.213.56.123
assert_exit_nonzero "IPv4 256.1.1.1 invalide"          is_valid_ipv4 256.1.1.1
assert_exit_nonzero "IPv4 1.2.3 invalide"              is_valid_ipv4 1.2.3
assert_exit_nonzero "IPv4 1.2.3.4.5 invalide"          is_valid_ipv4 1.2.3.4.5
assert_exit_nonzero "IPv4 a.b.c.d invalide"            is_valid_ipv4 a.b.c.d
assert_exit_nonzero "IPv4 vide invalide"               is_valid_ipv4 ""
assert_exit_nonzero "IPv4 999.1.1.1 invalide"          is_valid_ipv4 999.1.1.1
assert_exit_nonzero "IPv4 avec texte invalide"         is_valid_ipv4 "1.2.3.4 x"
assert_exit_zero    "IPv4 1.2.3.04 (zéro initial) valide" is_valid_ipv4 1.2.3.04

echo "-- is_valid_mc_version --"
assert_exit_zero    "Version 1.20.1 valide"        is_valid_mc_version 1.20.1
assert_exit_zero    "Version 1.21 valide"          is_valid_mc_version 1.21
assert_exit_nonzero "Version abc invalide"         is_valid_mc_version abc
assert_exit_nonzero "Version 1.20. invalide"       is_valid_mc_version "1.20."
assert_exit_nonzero "Version vide invalide"        is_valid_mc_version ""

echo "-- is_valid_ram --"
assert_exit_zero    "RAM 4 valide"                 is_valid_ram 4
assert_exit_zero    "RAM 8 valide (max free tier)" is_valid_ram 8
assert_exit_nonzero "RAM 9 invalide (> 8 Go)"      is_valid_ram 9
assert_exit_nonzero "RAM 1 invalide (< 2 Go)"      is_valid_ram 1
assert_exit_nonzero "RAM abc invalide"             is_valid_ram abc
assert_exit_nonzero "RAM vide invalide"            is_valid_ram ""

echo "-- is_valid_player_count --"
assert_exit_zero    "10 joueurs valide"            is_valid_player_count 10
assert_exit_nonzero "0 joueur invalide"            is_valid_player_count 0
assert_exit_nonzero "101 joueurs invalide"         is_valid_player_count 101

echo "-- is_valid_mc_username --"
assert_exit_zero    "Pseudo Notch valide"          is_valid_mc_username Notch
assert_exit_zero    "Pseudo avec underscore"       is_valid_mc_username "player_one"
assert_exit_nonzero "Pseudo 2 caractères"          is_valid_mc_username ab
assert_exit_nonzero "Pseudo 17 caractères"         is_valid_mc_username abcdefghijklmnopq
assert_exit_nonzero "Pseudo avec espace"           is_valid_mc_username "play er"

echo "-- is_valid_backup_name --"
assert_exit_zero    "Nom backup valide"            is_valid_backup_name backup-20260822-101010.tar.gz
assert_exit_nonzero "Nom backup avec espace"       is_valid_backup_name "backup bad.tar.gz"
assert_exit_nonzero "Nom backup avec /"            is_valid_backup_name "../etc/passwd"

echo "-- modpack_id_exists --"
TMP_MANIFEST="$(mktemp)"
printf '{ "modpacks": [ { "id": "better-minecraft" }, { "id": "atm9-light" } ] }\n' > "$TMP_MANIFEST"
assert_exit_zero    "Modpack known (manifest)"     modpack_id_exists better-minecraft "$TMP_MANIFEST"
assert_exit_nonzero "Modpack inconnu"              modpack_id_exists inexistant "$TMP_MANIFEST"
rm -f "$TMP_MANIFEST"
assert_exit_nonzero "Manifest absent"              modpack_id_exists better-minecraft /tmp/manifest.inexistant.json

echo "-- load_server_conf --"
TMP_CONF="$(mktemp)"
printf 'ORACLE_IP=192.0.2.10\nSSH_KEY_PATH=/tmp/faux.key\nSSH_USER=ubuntu\n' > "$TMP_CONF"
ORACLE_IP=""; SSH_KEY_PATH=""
load_server_conf "$TMP_CONF"
assert_equals "192.0.2.10" "$ORACLE_IP"  "load_server_conf renseigne ORACLE_IP"
assert_equals "/tmp/faux.key" "$SSH_KEY_PATH" "load_server_conf renseigne SSH_KEY_PATH"
rm -f "$TMP_CONF"

finish_tests

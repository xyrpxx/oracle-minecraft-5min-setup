#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"

echo "-- présence et syntaxe --"
assert_file_exists setup.sh "setup.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n setup.sh

echo "-- contenu attendu --"
assert_file_contains setup.sh "scripts/lib.sh"          "source lib.sh"
assert_file_contains setup.sh "remote_provision.sh"     "appelle le provisionnement distant"
assert_file_contains setup.sh ".server.conf"            "sauvegarde la configuration locale"
assert_file_contains setup.sh "StrictHostKeyChecking"   "SSH non interactif"
assert_file_contains setup.sh "docs/oci-vcn-config.md"  "rappel des Ingress Rules VCN"
assert_file_contains setup.sh "is_valid_url"            "validation stricte de l'URL du server pack"
assert_file_contains setup.sh "shell_quote"             "valeurs quotées dans .server.conf (chemins avec espaces)"
assert_file_not_contains setup.sh '${2,,}'               "pas de syntaxe bash4 (compat macOS bash 3.2)"

echo "-- assistant interactif (accessible débutants) --"
assert_file_contains scripts/lang_fr.sh "Mode guide"    "mode guide pas-à-pas (fr)"
assert_file_contains setup.sh "wizard_account"          "assistant création de compte Oracle"
assert_file_contains setup.sh "wizard_vm"               "assistant création de la VM"
assert_file_contains setup.sh "open_url"                "ouverture du navigateur proposée"
assert_file_contains scripts/lang_fr.sh "C'est fait ?"  "attente patiente entre les étapes (fr)"
assert_file_contains scripts/lang_fr.sh "op TonPseudo"  "astuce commande op (fr)"
assert_file_contains setup.sh "start-windows.bat"       "référence au lanceur Windows"

echo "-- internationalisation (fr/en) --"
assert_file_exists scripts/lang_fr.sh "scripts/lang_fr.sh présent"
assert_file_exists scripts/lang_en.sh "scripts/lang_en.sh présent"
assert_file_contains setup.sh "--lang"                 "option --lang"
assert_file_contains setup.sh 'lang_${UI_LANG}'         "chargement dynamique de la langue"
assert_file_contains scripts/lang_fr.sh "Mode guide"   "mode guide (fr) présent"
assert_file_contains scripts/lang_fr.sh "C'est fait ?" "attente patiente (fr)"
assert_file_contains scripts/lang_fr.sh "op TonPseudo" "astuce op (fr)"
assert_file_contains scripts/lang_en.sh "SIMULATION MODE" "bannière dry-run (en)"
assert_file_contains scripts/lang_en.sh "op YourName"   "astuce op (en)"

echo "-- mode guidé/expert scriptable --"
TMP2="$(mktemp -d)"
printf 'fake\n' > "${TMP2}/fake.key"
out="$(bash setup.sh --mode expert --ip 192.0.2.10 --key "${TMP2}/fake.key" --type vanilla \
      --mc-version 1.20.1 --ram 4 --players 5 --crafty false --modpack none \
      --yes --dry-run 2>&1)" && rc=0 || rc=1
assert_equals "0" "$rc" "--mode expert accepté en dry-run"
bash setup.sh --mode turbo --ip 192.0.2.10 --key "${TMP2}/fake.key" --type vanilla \
     --mc-version 1.20.1 --ram 4 --players 5 --crafty false --modpack none \
     --yes --dry-run >/dev/null 2>&1 && rc=0 || rc=1
assert_equals "1" "$rc" "--mode invalide rejeté"
rm -rf "${TMP2}"

echo "-- mode simulation (dry-run) --"
TMP="$(mktemp -d)"
printf 'fake\n' > "${TMP}/fake.key"
out="$(bash setup.sh --lang fr --ip 192.0.2.10 --key "${TMP}/fake.key" --type vanilla \
      --mc-version 1.20.1 --ram 4 --players 5 --crafty false --modpack none \
      --yes --dry-run 2>&1)" && rc=0 || rc=1
assert_equals "0" "$rc" "dry-run sort avec code 0"
assert_contains "$out" "192.0.2.10" "dry-run affiche l'IP"
assert_contains "$out" "vanilla"    "dry-run affiche le type de serveur"
assert_contains "$out" "SIMULATION" "dry-run se présente comme simulation"

out_en="$(bash setup.sh --lang en --mode expert --ip 192.0.2.10 --key "${TMP}/fake.key" \
      --type vanilla --mc-version 1.20.1 --ram 4 --players 5 --crafty false --modpack none \
      --yes --dry-run 2>&1)" && rc=0 || rc=1
assert_equals "0" "$rc" "dry-run anglais sort avec code 0"
assert_contains "$out_en" "SIMULATION MODE" "bannière dry-run en anglais"
assert_contains "$out_en" "192.0.2.10"      "dry-run EN affiche l'IP"
if [[ -f "${REPO_ROOT}/.server.conf" ]]; then
    t_fail "dry-run ne doit pas écrire .server.conf"
else
    t_pass "dry-run n'écrit pas .server.conf"
fi

echo "-- validations en mode non interactif --"
bash setup.sh --ip 999.1.1.1 --key "${TMP}/fake.key" --type vanilla \
     --mc-version 1.20.1 --ram 4 --players 5 --crafty false --modpack none \
     --yes --dry-run >/dev/null 2>&1 && rc=0 || rc=1
assert_equals "1" "$rc" "IP invalide rejetée"
bash setup.sh --ip 192.0.2.10 --key "${TMP}/fake.key" --type vanilla \
     --mc-version 1.20.1 --ram 12 --players 5 --crafty false --modpack none \
     --yes --dry-run >/dev/null 2>&1 && rc=0 || rc=1
assert_equals "1" "$rc" "RAM > 8 rejetée"

rm -rf "$TMP"
finish_tests

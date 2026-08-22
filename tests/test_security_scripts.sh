#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"

echo "-- hardening.sh --"
assert_file_exists security/hardening.sh "hardening.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n security/hardening.sh
assert_file_contains security/hardening.sh "load_server_conf"      "utilise .server.conf"
assert_file_contains security/hardening.sh "PermitRootLogin no"     "root SSH interdit"
assert_file_contains security/hardening.sh "PasswordAuthentication no" "SSH par clé uniquement"
assert_file_contains security/hardening.sh "sshd -t"                "validation config avant rechargement"
assert_file_contains security/hardening.sh "fail2ban"               "protection brute-force"
assert_file_contains security/hardening.sh "unattended-upgrades"    "mises à jour sécurité automatiques"
assert_file_not_contains security/hardening.sh "ufw allow"          "aucune commande 'ufw allow'"
assert_file_not_contains security/hardening.sh "ufw enable"         "aucune commande 'ufw enable'"

finish_tests

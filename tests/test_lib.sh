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

finish_tests

#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"

echo "-- configure_iptables.sh --"
assert_file_exists deploy/configure_iptables.sh "configure_iptables.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n deploy/configure_iptables.sh
assert_file_contains deploy/configure_iptables.sh "iptables -C"                "vérification d'existence (idempotence)"
assert_file_contains deploy/configure_iptables.sh "iptables -I INPUT"          "insertion dans la chaîne INPUT"
assert_file_contains deploy/configure_iptables.sh "REJECT"                     "détection de la règle REJECT d'Oracle"
assert_file_contains deploy/configure_iptables.sh "netfilter-persistent save"  "persistance des règles"
assert_file_contains deploy/configure_iptables.sh "25565"                      "port Minecraft"
assert_file_contains deploy/configure_iptables.sh "8443"                       "port Crafty"
assert_file_not_contains deploy/configure_iptables.sh "ufw allow"              "aucune commande 'ufw allow'"
assert_file_not_contains deploy/configure_iptables.sh "ufw enable"             "aucune commande 'ufw enable'"

echo "-- docker-compose.crafty.yml --"
assert_file_exists deploy/docker-compose.crafty.yml "docker-compose.crafty.yml présent"
assert_file_contains deploy/docker-compose.crafty.yml "registry.gitlab.com/crafty-controller/crafty-4" "image officielle Crafty 4"
assert_file_contains deploy/docker-compose.crafty.yml "8443:8443"              "port web Crafty"
assert_file_contains deploy/docker-compose.crafty.yml "/opt/minecraft/server:/crafty/servers" "serveur MC exposé à Crafty"
assert_file_contains deploy/docker-compose.crafty.yml "restart: always"        "redémarrage automatique"

finish_tests

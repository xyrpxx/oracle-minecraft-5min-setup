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

echo "-- remote_provision.sh --"
assert_file_exists deploy/remote_provision.sh "remote_provision.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n deploy/remote_provision.sh
assert_file_contains deploy/remote_provision.sh "set -euo pipefail"            "mode strict"
assert_file_contains deploy/remote_provision.sh "openjdk-21-jre-headless"      "OpenJDK 21"
assert_file_contains deploy/remote_provision.sh "useradd"                      "utilisateur dédié minecraft"
assert_file_contains deploy/remote_provision.sh "usr/sbin/nologin"             "shell nologin"
assert_file_contains deploy/remote_provision.sh "--installServer"              "installation silencieuse Forge"
assert_file_contains deploy/remote_provision.sh "unix_args.txt"                "amorçage Forge moderne"
assert_file_not_contains deploy/remote_provision.sh "minecraft_server.jar"     "java -jar obsolète interdit"
assert_file_not_contains deploy/remote_provision.sh "ufw allow"                "aucune commande 'ufw allow'"
assert_file_not_contains deploy/remote_provision.sh "ufw enable"               "aucune commande 'ufw enable'"
assert_file_contains deploy/remote_provision.sh "minecraft.service"            "unité systemd"
assert_file_contains deploy/remote_provision.sh "Restart=on-failure"           "redémarrage auto"
assert_file_contains deploy/remote_provision.sh "SuccessExitStatus=0 143"      "arrêt propre (SIGTERM)"
assert_file_contains deploy/remote_provision.sh "docker compose up -d"         "Crafty via compose"
assert_file_contains deploy/remote_provision.sh "ss -tln"                      "vérification port 25565"
assert_file_contains deploy/remote_provision.sh "piston-meta.mojang.com"      "résolution vanilla dynamique"
assert_file_contains deploy/remote_provision.sh "meta.fabricmc.net"            "résolution fabric dynamique"
assert_file_contains deploy/remote_provision.sh "__RCON_PASSWORD__"            "injection mot de passe RCON"
assert_file_contains deploy/remote_provision.sh "__RAM__"                      "injection RAM JVM"
assert_file_contains deploy/remote_provision.sh "--update-server"              "mode mise à jour"

finish_tests

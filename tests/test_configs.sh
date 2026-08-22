#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"

echo "-- présence des fichiers --"
assert_file_exists configs/server.properties.template "server.properties.template présent"
assert_file_exists configs/user_jvm_args.txt.template  "user_jvm_args.txt.template présent"
assert_file_exists configs/eula.txt                    "eula.txt présent"

echo "-- server.properties.template --"
assert_file_contains configs/server.properties.template "max-players=20"           "max-players présent"
assert_file_contains configs/server.properties.template "server-port=25565"        "port serveur 25565"
assert_file_contains configs/server.properties.template "view-distance=8"          "view-distance optimisée"
assert_file_contains configs/server.properties.template "simulation-distance=8"   "simulation-distance optimisée"
assert_file_contains configs/server.properties.template "enable-rcon=true"         "RCON activé"
assert_file_contains configs/server.properties.template "rcon.password=__RCON_PASSWORD__" "mot de passe RCON à injecter"
assert_file_contains configs/server.properties.template "white-list=false"         "whitelist désactivée par défaut"
assert_file_not_contains configs/server.properties.template "allow-the-end"        "clé inventée absente"
assert_file_not_contains configs/server.properties.template "spawn-monsters=70"    "valeur numérique invalide absente"

echo "-- user_jvm_args.txt.template --"
assert_file_contains configs/user_jvm_args.txt.template "-Xms__RAM__G"             "Xms paramétré"
assert_file_contains configs/user_jvm_args.txt.template "-Xmx__RAM__G"             "Xmx paramétré (parité Xms/Xmx)"
assert_file_contains configs/user_jvm_args.txt.template "-XX:+UseZGC"              "GC ZGC"
assert_file_contains configs/user_jvm_args.txt.template "-XX:+ZGenerational"       "ZGC générationnel (JDK 21)"
assert_file_contains configs/user_jvm_args.txt.template "-XX:+UnlockExperimentalVMOptions" "déverrouillage options expérimentales"
assert_file_contains configs/user_jvm_args.txt.template "-XX:+AlwaysPreTouch"      "AlwaysPreTouch"
assert_file_contains configs/user_jvm_args.txt.template "-XX:+UseStringDeduplication" "déduplication des chaînes"
assert_file_contains configs/user_jvm_args.txt.template "-XX:+DisableExplicitGC"   "DisableExplicitGC"
assert_file_not_contains configs/user_jvm_args.txt.template "SilentGCThreads"      "flag obsolète absent"

echo "-- eula.txt --"
assert_file_contains configs/eula.txt "eula=true" "EULA acceptée"

finish_tests

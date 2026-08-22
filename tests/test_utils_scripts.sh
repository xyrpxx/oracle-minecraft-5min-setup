#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"

echo "-- backup.sh --"
assert_file_exists utils/backup.sh "backup.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n utils/backup.sh
assert_file_contains utils/backup.sh "save-off"        "sauvegarde à chaud (save-off)"
assert_file_contains utils/backup.sh "save-all flush"  "flush des chunks avant archive"
assert_file_contains utils/backup.sh "save-on"         "réactivation des sauvegardes"
assert_file_contains utils/backup.sh "tar czf"         "archivage tar.gz"
assert_file_contains utils/backup.sh "load_server_conf" "utilise .server.conf"
assert_file_contains utils/backup.sh "systemctl stop minecraft" "repli à froid si RCON absent"

echo "-- restore.sh --"
assert_file_exists utils/restore.sh "restore.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n utils/restore.sh
assert_file_contains utils/restore.sh "tar xzf"        "extraction"
assert_file_contains utils/restore.sh "systemctl stop minecraft" "arrêt avant restauration"
assert_file_contains utils/restore.sh "systemctl start minecraft" "redémarrage après restauration"
assert_file_contains utils/restore.sh "is_valid_backup_name"      "validation du nom d'archive"

echo "-- monitor.sh --"
assert_file_exists utils/monitor.sh "monitor.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n utils/monitor.sh
assert_file_contains utils/monitor.sh "load_server_conf"   "utilise .server.conf"
assert_file_contains utils/monitor.sh "systemctl is-active minecraft" "état du service"
assert_file_contains utils/monitor.sh "free -h"            "mémoire système"
assert_file_contains utils/monitor.sh "df -h"              "espace disque"
assert_file_contains utils/monitor.sh '"list"'              "joueurs connectés via RCON"
assert_file_contains utils/monitor.sh '"forge tps"'         "TPS (Forge)"

echo "-- update.sh --"
assert_file_exists utils/update.sh "update.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n utils/update.sh
assert_file_contains utils/update.sh "load_server_conf"    "utilise .server.conf"
assert_file_contains utils/update.sh "--update-server"     "réutilise remote_provision en mode update"
assert_file_contains utils/update.sh "--forge-build"       "changement de build Forge"
assert_file_contains utils/update.sh "--pack-url"          "mise à jour de modpack via server pack"
assert_file_contains utils/update.sh "is_valid_mc_version" "validation de la version saisie"

echo "-- uninstall.sh --"
assert_file_exists uninstall.sh "uninstall.sh présent"
assert_exit_zero "syntaxe bash valide" bash -n uninstall.sh
assert_file_contains uninstall.sh "load_server_conf"           "utilise .server.conf"
assert_file_contains uninstall.sh "systemctl disable --now minecraft" "arrêt du service"
assert_file_contains uninstall.sh "docker compose down"        "arrêt de Crafty"
assert_file_contains uninstall.sh "iptables -D INPUT"          "retrait des règles pare-feu"
assert_file_contains uninstall.sh "netfilter-persistent save"  "persistance du retrait"
assert_file_contains uninstall.sh "userdel minecraft"          "suppression de l'utilisateur dédié"
assert_file_contains uninstall.sh ".server.conf"               "suppression conf locale"

finish_tests

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

finish_tests

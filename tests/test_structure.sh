#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"

echo "-- arborescence complète --"
for f in README.md LICENSE .gitignore .gitattributes setup.sh uninstall.sh \
         scripts/lib.sh \
         deploy/remote_provision.sh deploy/configure_iptables.sh \
         deploy/docker-compose.crafty.yml deploy/oci_ingress_setup.sh \
         configs/server.properties.template configs/user_jvm_args.txt.template configs/eula.txt \
         modpacks/manifest.json modpacks/better-minecraft.json modpacks/atm9-light.json modpacks/vanilla-plus.json \
         utils/rcon_client.py utils/backup.sh utils/restore.sh utils/monitor.sh utils/update.sh \
         security/hardening.sh security/whitelist_manager.sh \
         docs/guide-debutant-fr.md docs/oci-vcn-config.md docs/troubleshooting.md; do
    assert_file_exists "$f" "présent : $f"
done

echo "-- syntaxe de tous les scripts bash --"
while IFS= read -r f; do
    assert_exit_zero "bash -n $f" bash -n "$f"
done < <(find . -type f -name '*.sh' -not -path './.git/*')

echo "-- fins de ligne LF (pas de CRLF) --"
while IFS= read -r f; do
    if LC_ALL=C grep -q "$(printf '\r')" "$f"; then t_fail "CRLF détecté : $f"; else t_pass "LF : $f"; fi
done < <(find . -type f \( -name '*.sh' -o -name '*.py' -o -name '*.yml' -o -name '*.json' -o -name '*.template' \) -not -path './.git/*')

echo "-- shellcheck (si installé) --"
if command -v shellcheck >/dev/null 2>&1; then
    sc_err=0
    while IFS= read -r f; do
        shellcheck -S warning "$f" || sc_err=1
    done < <(find . -type f -name '*.sh' -not -path './.git/*')
    if (( sc_err == 0 )); then t_pass "shellcheck global"; else t_fail "shellcheck global"; fi
else
    echo "  (shellcheck absent — contrôle sauté)"
fi

echo "-- absence de régressions interdites --"
assert_file_not_contains deploy/remote_provision.sh "minecraft_server.jar" "pas de java -jar Forge obsolète"
assert_file_not_contains deploy/configure_iptables.sh "ufw allow"          "pas de commande ufw allow"

finish_tests

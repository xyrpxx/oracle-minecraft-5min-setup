#!/usr/bin/env bash
# run_tests.sh — Exécute tous les tests. Code retour non nul si un échec.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

overall=0
for t in tests/test_*.sh; do
    echo "==> $t"
    if ! bash "$t"; then
        overall=1
        echo "    [ÉCHEC] $t"
    fi
done

# Test python optionnel (client RCON)
if command -v python3 >/dev/null 2>&1; then
    echo "==> tests/test_rcon.py"
    if ! python3 tests/test_rcon.py; then
        overall=1
        echo "    [ÉCHEC] tests/test_rcon.py"
    fi
else
    echo "==> tests/test_rcon.py (python3 absent — sauté)"
fi

if (( overall == 0 )); then
    echo "SUITE : SUCCÈS"
else
    echo "SUITE : ÉCHECS"
fi
exit "$overall"

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
PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1 && python --version >/dev/null 2>&1; then
    PYTHON_BIN="python"
fi
if [[ -n "$PYTHON_BIN" ]]; then
    echo "==> tests/test_rcon.py (${PYTHON_BIN})"
    if ! "$PYTHON_BIN" tests/test_rcon.py; then
        overall=1
        echo "    [ÉCHEC] tests/test_rcon.py"
    fi
else
    echo "==> tests/test_rcon.py (python absent — sauté)"
fi

if (( overall == 0 )); then
    echo "SUITE : SUCCÈS"
else
    echo "SUITE : ÉCHECS"
fi
exit "$overall"

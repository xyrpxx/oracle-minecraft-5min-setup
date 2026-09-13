#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers.sh
. "${REPO_ROOT}/tests/helpers.sh"

echo "-- launcher (GUI graphique) --"
assert_file_exists launcher/gui_launcher.py "gui_launcher.py présent"
assert_file_exists launcher/launch-gui.bat "launch-gui.bat présent"
assert_file_exists launcher/BUILD-EXE.md "BUILD-EXE.md présent"
assert_file_not_contains launcher/gui_launcher.py "import requests" "stdlib uniquement (pas de requests)"
assert_file_not_contains launcher/gui_launcher.py "import PyQt"     "stdlib uniquement (pas de PyQt)"
assert_file_contains launcher/gui_launcher.py "tkinter"             "interface tkinter (stdlib)"
assert_file_contains launcher/gui_launcher.py "find_git_bash"       "détection Git Bash (pas WSL)"
assert_file_contains launcher/gui_launcher.py "CREATE_NEW_CONSOLE"  "terminal visible pour les scripts interactifs"
assert_file_contains launcher/gui_launcher.py "shell_quote"         "arguments cités façon shell (anti-injection)"
assert_file_contains launcher/gui_launcher.py "setup.sh"            "délègue à setup.sh (source de vérité)"
assert_file_contains launcher/gui_launcher.py "manage.sh"           "délègue à manage.sh"
assert_file_contains launcher/gui_launcher.py '"fr"'                "support du français"
assert_file_contains launcher/launch-gui.bat "start-windows.bat"    "repli vers l'installeur classique"
assert_file_contains launcher/BUILD-EXE.md "pyinstaller"            "procédure .exe documentée"
assert_file_contains launcher/BUILD-EXE.md "Do **not** commit"       "doc : ne pas versionner le .exe"

echo "-- logique pure du launcher (sans affichage) --"
if command -v python >/dev/null 2>&1; then
    assert_exit_zero "compilation python" python -m py_compile launcher/gui_launcher.py
    out="$(python - "$REPO_ROOT" <<'PYEOF'
import sys
sys.path.insert(0, sys.argv[1] + '/launcher')
import gui_launcher as g
assert g.valid_ipv4('129.213.56.123')
assert not g.valid_ipv4('999.1.1.1')
assert g.valid_mc_version('1.20.1') and g.valid_mc_version('26.2')
assert not g.valid_mc_version('latest')
assert set(g.STRINGS['en']) == set(g.STRINGS['fr'])
assert g.load_modpacks() == ['better-minecraft', 'atm9-light', 'vanilla-plus']
q = g.shell_quote("a'b")
assert q == "'a'\\''b'", q
print('launcher-logic OK')
PYEOF
)"
    assert_contains "$out" "launcher-logic OK" "validation IP/version/parité FR-EN/modpacks/shell_quote"
else
    echo "  (python absent — contrôle logique sauté)"
fi

finish_tests

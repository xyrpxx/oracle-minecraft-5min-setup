#!/usr/bin/env bash
# helpers.sh — Assertions minimales pour la suite de tests (compatible Git Bash)
PASS_COUNT=0
FAIL_COUNT=0

t_pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  OK    %s\n' "$1"; }
t_fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '  ÉCHEC %s\n' "$1" >&2; }

assert_equals() { # attendu obtenu message
    if [[ "$1" == "$2" ]]; then t_pass "$3"; else t_fail "$3 (attendu '$1', obtenu '$2')"; fi
}
assert_contains() { # botte_aiguille aiguille message
    if [[ "$1" == *"$2"* ]]; then t_pass "$3"; else t_fail "$3 ('$2' introuvable)"; fi
}
assert_file_exists() {
    if [[ -f "$1" ]]; then t_pass "$2"; else t_fail "$2 (fichier absent : $1)"; fi
}
assert_file_contains() { # fichier aiguille message
    if grep -qF -- "$2" "$1" 2>/dev/null; then t_pass "$3"; else t_fail "$3 ('$2' introuvable dans $1)"; fi
}
assert_file_not_contains() {
    if grep -qF -- "$2" "$1" 2>/dev/null; then t_fail "$3 ('$2' trouvé dans $1 alors qu'interdit)"; else t_pass "$3"; fi
}
assert_exit_zero() { # message commande...
    local msg="$1"; shift
    if "$@" >/dev/null 2>&1; then t_pass "$msg"; else t_fail "$msg"; fi
}
assert_exit_nonzero() {
    local msg="$1"; shift
    if "$@" >/dev/null 2>&1; then t_fail "$msg"; else t_pass "$msg"; fi
}
finish_tests() {
    printf '\nRésultats : %d OK, %d échec(s)\n' "$PASS_COUNT" "$FAIL_COUNT"
    [[ "$FAIL_COUNT" -eq 0 ]]
}

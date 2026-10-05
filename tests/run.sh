#!/usr/bin/env bash
# Runner de tests sans dépendance : chaque fonction test_* de tests/test_*.sh
# s'exécute dans son propre processus, au sein d'un bac à sable jetable.
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_SRC="$(cd "$TESTS_DIR/.." && pwd -P)"
export TESTS_DIR REPO_SRC

# shellcheck source=tests/helpers.sh
source "$TESTS_DIR/helpers.sh"
for f in "$TESTS_DIR"/test_*.sh; do
  [[ -e "$f" ]] || continue
  # shellcheck source=/dev/null
  source "$f"
done

# Mode interne : exécute un seul test (processus séparé pour que set -e s'applique).
if [[ "${1:-}" == "--one" ]]; then
  setup_sandbox
  "$2"
  exit 0
fi

filter="${1:-}"
passed=0
failed=0
out="$(mktemp)"
trap 'rm -f "$out"' EXIT

while IFS= read -r t; do
  if [[ -n "$filter" && "$t" != *"$filter"* ]]; then
    continue
  fi
  if bash "${BASH_SOURCE[0]}" --one "$t" >"$out" 2>&1; then
    passed=$((passed + 1))
    printf 'PASS  %s\n' "$t"
  else
    failed=$((failed + 1))
    printf 'FAIL  %s\n' "$t"
    sed 's/^/      /' "$out"
  fi
done < <(declare -F | awk '{print $3}' | grep '^test_' | sort || true)

if [[ -z "$filter" ]]; then
  if command -v shellcheck >/dev/null 2>&1; then
    mapfile -t files < <(cd "$REPO_SRC" && ls -d bin/claude-config deps.sh lib/*.sh tests/*.sh 2>/dev/null || true)
    if (cd "$REPO_SRC" && shellcheck -x "${files[@]}"); then
      passed=$((passed + 1))
      printf 'PASS  shellcheck\n'
    else
      failed=$((failed + 1))
      printf 'FAIL  shellcheck\n'
    fi
  else
    printf 'SKIP  shellcheck (non installé)\n'
  fi
fi

printf '\n%d réussi(s), %d échec(s)\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]

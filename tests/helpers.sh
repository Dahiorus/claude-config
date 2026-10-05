# shellcheck shell=bash
# Outils partagés par les tests : bac à sable, assertions, stubs.
# Les variables définies ici sont utilisées par les fichiers test_*.sh.
# shellcheck disable=SC2034

# Crée un bac à sable jetable (chemin avec espaces) contenant une copie du repo.
setup_sandbox() {
  SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/claude config test.XXXXXX")"
  SANDBOX="$(cd "$SANDBOX" && pwd -P)"
  trap 'rm -rf "$SANDBOX"' EXIT
  REPO="$SANDBOX/repo"
  mkdir -p "$REPO" "$SANDBOX/home"
  tar -C "$REPO_SRC" --exclude=./.git --exclude=./settings/local.json -cf - . | tar -C "$REPO" -xf -
  export HOME="$SANDBOX/home"
  export CLAUDE_HOME="$HOME/.claude"
  export CALLS_LOG="$SANDBOX/calls.log"
  STUBS="$SANDBOX/stubs"
  CLI="$REPO/bin/claude-config"
}

fail() {
  printf 'ÉCHEC : %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  [[ "$1" == "$2" ]] || fail "${3:-valeur} : attendu [$2], obtenu [$1]"
}

assert_contains() {
  [[ "$1" == *"$2"* ]] || fail "[$2] absent de : $1"
}

assert_not_contains() {
  [[ "$1" != *"$2"* ]] || fail "[$2] présent dans : $1"
}

# Vérifie qu'une ligne « <statut> <message> » figure dans la sortie (espacement ignoré).
assert_has_line() {
  sed -E 's/^([a-z-]+) +/\1 /' <<<"$1" | grep -qxF -- "$2 $3" || fail "ligne [$2 $3] absente de : $1"
}

assert_symlink_to() {
  [[ -L "$1" ]] || fail "$1 n'est pas un symlink"
  assert_eq "$(readlink "$1")" "$2" "cible de $1"
}

assert_json_eq() {
  assert_eq "$(jq -S . "$1")" "$(jq -S . <<<"$2")" "contenu JSON de $1"
}

count_backups() {
  find "$1" -name '*.bak-*' | wc -l
}

# Empreinte d'une arborescence : chemins, types, cibles de liens et contenus.
snapshot() {
  (cd "$1" && find . -printf '%p|%y|%l|%m\n' | sort && find . -type f -exec md5sum {} + | sort)
}

# Crée un faux exécutable qui journalise son appel dans $CALLS_LOG et sort avec <code_sortie>.
make_stub() {
  local name="$1" code="${2:-0}"
  mkdir -p "$STUBS"
  {
    printf '#!/usr/bin/env bash\n'
    # Le stub doit développer $* et $CALLS_LOG à son exécution, pas ici.
    # shellcheck disable=SC2016
    printf 'printf "%%s\\n" "%s $*" >> "$CALLS_LOG"\n' "$name"
    printf 'exit %s\n' "$code"
  } > "$STUBS/$name"
  chmod +x "$STUBS/$name"
}

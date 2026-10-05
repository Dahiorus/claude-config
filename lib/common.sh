# shellcheck shell=bash
# Fonctions partagées : journalisation, erreurs, sauvegardes.
# Sourcé par bin/claude-config, qui définit REPO_ROOT, CLAUDE_HOME et DRY_RUN.
# shellcheck disable=SC2154

log() {
  printf '%-9s %s\n' "$1" "$2"
}

die() {
  printf 'error     %s\n' "$1" >&2
  exit "${2:-1}"
}

timestamp() {
  date +%Y%m%d-%H%M%S
}

# Déplace <chemin> vers <chemin>.bak-<timestamp>, avec un suffixe -N si ce nom existe déjà.
backup_path() {
  local path="$1" base candidate n=1
  base="$path.bak-$(timestamp)"
  candidate="$base"
  while [[ -e "$candidate" || -L "$candidate" ]]; do
    candidate="$base-$n"
    n=$((n + 1))
  done
  if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
    mv "$path" "$candidate"
  fi
  log backup "$path -> $candidate"
}

require_jq() {
  command -v jq >/dev/null 2>&1 || die "jq est requis (sudo apt install jq)"
}

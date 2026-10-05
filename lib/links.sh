# shellcheck shell=bash
# Éléments de global/ installés par symlink dans $CLAUDE_HOME.
# Sourcé par bin/claude-config, qui définit REPO_ROOT, CLAUDE_HOME et DRY_RUN.
# shellcheck disable=SC2154

# Chemins relatifs gérés : fichiers de global/ (hors skills/) puis chaque dossier global/skills/*.
managed_links() {
  find "$REPO_ROOT/global" -mindepth 1 -maxdepth 1 ! -name skills -printf '%P\n' | sort
  if [[ -d "$REPO_ROOT/global/skills" ]]; then
    find "$REPO_ROOT/global/skills" -mindepth 1 -maxdepth 1 -type d -printf 'skills/%P\n' | sort
  fi
}

link_item() {
  local rel="$1"
  local src="$REPO_ROOT/global/$rel" dest="$CLAUDE_HOME/$rel"
  if [[ -L "$dest" ]]; then
    if [[ "$(readlink "$dest")" == "$src" ]]; then
      log ok "$rel"
      return 0
    fi
    if [[ "$DRY_RUN" -eq 0 ]]; then
      rm "$dest"
      ln -s "$src" "$dest"
    fi
    log relinked "$rel"
    return 0
  fi
  if [[ -e "$dest" ]]; then
    backup_path "$dest"
  fi
  if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
  fi
  log linked "$rel"
}

install_links() {
  local rel
  while IFS= read -r rel; do
    link_item "$rel"
  done < <(managed_links)
}

# Renvoie 0 si $CLAUDE_HOME/<rel> est le bon symlink, 1 sinon (avec une ligne de diagnostic).
check_link() {
  local rel="$1"
  local src="$REPO_ROOT/global/$rel" dest="$CLAUDE_HOME/$rel"
  if [[ -L "$dest" ]]; then
    if [[ "$(readlink "$dest")" == "$src" ]]; then
      log ok "$rel"
      return 0
    fi
    if [[ -e "$dest" ]]; then
      log drift "$rel -> $(readlink "$dest")"
    else
      log broken "$rel"
    fi
  elif [[ -e "$dest" ]]; then
    log drift "$rel (fichier réel, pas un symlink)"
  else
    log missing "$rel"
  fi
  return 1
}

status_links() {
  local rel rc=0
  while IFS= read -r rel; do
    check_link "$rel" || rc=1
  done < <(managed_links)
  return "$rc"
}

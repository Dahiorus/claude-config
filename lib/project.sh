# shellcheck shell=bash
# init-project : copie un template de config Claude dans un repo.
# Sourcé par bin/claude-config, qui définit REPO_ROOT.
# shellcheck disable=SC2154

init_project() {
  local dir="$1" template="$2" force="$3"
  local tpl="$REPO_ROOT/templates/$template" name rel
  [[ -d "$dir" ]] || die "dossier introuvable : $dir"
  if [[ -z "$template" || "$template" == */* || ! -d "$tpl" ]]; then
    die "template inconnu : $template"
  fi
  dir="$(cd "$dir" && pwd -P)"
  name="$(basename "$dir")"
  if ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    log warn "$dir n'est pas un repo git"
  fi
  while IFS= read -r -d '' rel; do
    copy_template_file "$tpl/$rel" "$dir/$rel" "$rel" "$name" "$force"
  done < <(find "$tpl" -type f -printf '%P\0' | sort -z)
  ensure_gitignore_entry "$dir/.gitignore"
}

# Copie un fichier en remplaçant {{PROJECT_NAME}} ; conserve l'existant sauf avec force=1.
copy_template_file() {
  local src="$1" dest="$2" rel="$3" name="$4" force="$5" content
  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ "$force" -ne 1 ]]; then
      log skipped "$rel (exists)"
      return 0
    fi
    backup_path "$dest"
  fi
  mkdir -p "$(dirname "$dest")"
  # Le « x » final préserve les retours à la ligne de fin, que $(...) supprimerait.
  content="$(cat "$src"; printf x)"
  content="${content%x}"
  printf '%s' "${content//"{{PROJECT_NAME}}"/"$name"}" > "$dest"
  log written "$rel"
}

ensure_gitignore_entry() {
  local file="$1" entry=".claude/settings.local.json"
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  if grep -qxF -- "$entry" "$file"; then
    log ok .gitignore
    return 0
  fi
  if [[ -s "$file" && -n "$(tail -c 1 "$file")" ]]; then
    printf '\n' >> "$file"
  fi
  printf '%s\n' "$entry" >> "$file"
  log written ".gitignore (+ $entry)"
}

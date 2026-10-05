# shellcheck shell=bash
# init-project : copie un template de config Claude dans un repo.
# Sourcé par bin/claude-config, qui définit REPO_ROOT.
# shellcheck disable=SC2154

init_project() {
  local dir="$1" template="$2" force="$3"
  local tpl="$REPO_ROOT/templates/$template" name rel
  [[ -d "$dir" ]] || die "dossier introuvable : $dir"
  if [[ ! "$template" =~ ^[A-Za-z0-9._-]+$ || "$template" == . || "$template" == .. || ! -d "$tpl" ]]; then
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
  ensure_gitignore_entry "$dir"
}

# Copie un fichier (droits compris) en remplaçant {{PROJECT_NAME}} ; conserve l'existant sauf avec force=1.
# Un fichier binaire ou sans placeholder est copié tel quel.
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
  # grep -I considère un fichier binaire comme sans correspondance.
  if ! grep -qI -- '' "$src" || ! grep -qF -- "{{PROJECT_NAME}}" "$src"; then
    cp -- "$src" "$dest"
    chmod --reference="$src" -- "$dest"
    log written "$rel"
    return 0
  fi
  # Le « x » final préserve les retours à la ligne de fin, que $(...) supprimerait.
  content="$(cat "$src"; printf x)"
  content="${content%x}"
  printf '%s' "${content//"{{PROJECT_NAME}}"/"$name"}" > "$dest"
  chmod --reference="$src" -- "$dest"
  log written "$rel"
}

# Ajoute .claude/settings.local.json au .gitignore de <dir> s'il existe et ne l'ignore pas déjà.
ensure_gitignore_entry() {
  local dir="$1" entry=".claude/settings.local.json"
  local file="$dir/.gitignore"
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  if grep -qxF -- "$entry" "$file" || gitignore_covers "$dir" "$entry"; then
    log ok .gitignore
    return 0
  fi
  if [[ -s "$file" && -n "$(tail -c 1 "$file")" ]]; then
    printf '\n' >> "$file"
  fi
  printf '%s\n' "$entry" >> "$file"
  log written ".gitignore (+ $entry)"
}

# Vrai si une règle du .gitignore racine de <dir> (et non une config globale) ignore <chemin>.
gitignore_covers() {
  local dir="$1" path="$2" source
  git -C "$dir" check-ignore -q --no-index -- "$path" 2>/dev/null || return 1
  source="$(git -C "$dir" check-ignore -v --no-index -- "$path" 2>/dev/null | cut -d: -f1)"
  [[ "$source" == ".gitignore" ]]
}

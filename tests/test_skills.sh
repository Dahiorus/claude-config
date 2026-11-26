# shellcheck shell=bash

PR_SKILL_DIR="$REPO_SRC/global/skills/pr"

test_pr_skill_table_matches_files() {
  local listed files f
  (( $(wc -l < "$PR_SKILL_DIR/SKILL.md") <= 200 )) || fail "pr/SKILL.md dépasse 200 lignes"
  # shellcheck disable=SC2016 # les accents graves sont ceux du Markdown
  listed="$(grep -oE '^\| `([a-z-]+)` \| `\1\.md` \|' "$PR_SKILL_DIR/SKILL.md" | grep -oE '[a-z-]+\.md' | sort)"
  [[ -n "$listed" ]] || fail "table des fichiers d'action absente de pr/SKILL.md"
  for f in $listed; do
    [[ -f "$PR_SKILL_DIR/$f" ]] || fail "$f cité dans la table mais absent"
  done
  files="$(find "$PR_SKILL_DIR" -maxdepth 1 -name '*.md' ! -name SKILL.md -printf '%f\n' | sort)"
  assert_eq "$files" "$listed" "fichiers d'action présents"
}

test_no_bare_reference_to_pr_action() {
  local hits
  # shellcheck disable=SC2016 # les accents graves sont ceux du Markdown
  hits="$(grep -rnE '(§|étapes?[^|]{0,20} de|comme( dans| pour)?|voir) `(push|squash|rebase|recette|merge|review|comments)`' \
    "$REPO_SRC/global" "$REPO_SRC/docs/domaine.md")" || [[ $? -eq 1 ]] || fail "grep en erreur"
  assert_eq "$hits" "" "renvois à une action de pr sans .md"
}

test_no_per_command_token() {
  local hits
  # shellcheck disable=SC2016 # motif littéral, pas d'expansion voulue
  hits="$(grep -rnE '(GH_TOKEN=|t=)\$\(gh auth token' "$REPO_SRC/global/skills" "$REPO_SRC/mods/profile/skills")" \
    || [[ $? -eq 1 ]] || fail "grep en erreur"
  assert_eq "$hits" "" "préfixe de jeton ponctuel dans un skill"
}

test_skills_call_require_token() {
  local skill
  for skill in pr notify release todo pr-risk; do
    grep -qF 'bash ~/.claude/profile.sh require-token' "$REPO_SRC/global/skills/$skill/SKILL.md" \
      || fail "$skill ne lance pas require-token"
  done
}

# Fichiers qui citent la grille qualité par son ancien emplacement.
quality_grid_old_citations() {  # <chemin>…
  # -z : un fichier par enregistrement, [[:space:]]+ attrape aussi une citation repliée sur deux lignes.
  # shellcheck disable=SC2016 # les accents graves sont ceux du Markdown
  grep -rlzE -e '«[[:space:]]+Grille[[:space:]]+qualité[[:space:]]+»[[:space:]]+de' \
    -e 'grille[[:space:]]+(qualité[[:space:]]+)?de[[:space:]]+`feature`' \
    -e 'grille[[:space:]]+qualité[[:space:]]+du[[:space:]]+skill' \
    -e 'grille[[:space:]]+qualité[[:space:]]+\(ci-dessous\)' \
    -e 'tri[[:space:]]+des[[:space:]]+retours[[:space:]]+et[[:space:]]+la[[:space:]]+grille[[:space:]]+qualité' \
    -e '§ « Grille qualité » \|' "$@"
}

test_quality_grid_cited_by_path() {
  local hits
  [[ -f "$REPO_SRC/global/grille-qualite.md" ]] || fail "global/grille-qualite.md absent"
  hits="$(quality_grid_old_citations "$REPO_SRC/global" "$REPO_SRC/CLAUDE.md" "$REPO_SRC/docs/domaine.md")" \
    || [[ $? -eq 1 ]] || fail "grep en erreur"
  assert_eq "$hits" "" "grille qualité citée par l'ancien emplacement"
}

test_quality_grid_guard_catches_folded_citation() {
  local dir
  dir="$(mktemp -d)"
  # shellcheck disable=SC2016 # les accents graves sont ceux du Markdown
  printf 'la grille\nde `feature`\n' >"$dir/a.md"
  printf 'la « Grille\nqualité » de feature\n' >"$dir/b.md"
  printf 'a|b § « Grille qualité » b\n' >"$dir/c.md"
  assert_eq "$(quality_grid_old_citations "$dir" | sort)" "$(printf '%s\n' "$dir/a.md" "$dir/b.md")" \
    "citations repliées détectées, | hors tableau ignoré"
  rm -rf "$dir"
}

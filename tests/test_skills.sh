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

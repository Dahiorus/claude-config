# shellcheck shell=bash
# shellcheck disable=SC2154
# Règles du CLAUDE.md vérifiées sur la branche courante plutôt qu'écrites en prose.

# Lignes Markdown ajoutées depuis <base> de plus de 120 colonnes, hors tableaux et description de frontmatter.
# shortcut: une ligne de bloc de code longue est comptée aussi (le diff -U0 ne dit pas si elle est dans un bloc).
md_long_lines() {  # <dépôt> <base>
  git -C "$1" diff -U0 "$2" -- CLAUDE.md 'global/*.md' 'mods/*.md' docs/domaine.md docs/reste-a-faire.md \
    | LC_ALL=C.UTF-8 awk '/^\+\+\+ /{f=substr($2,3)} /^\+/ && !/^\+\+\+ / && length>121 \
        && !/^\+[[:space:]]*\|/ && !/^\+description:/ {print f": " length-1 " colonnes"}'
}

# Plugins de mods/ modifiés depuis <base> sans montée de version dans leur plugin.json.
plugins_without_bump() {  # <dépôt> <base>
  local p json
  for p in $(git -C "$1" diff --name-only "$2" -- mods | cut -d/ -f2 | sort -u); do
    json="mods/$p/.claude-plugin/plugin.json"
    [[ -f "$1/$json" ]] || continue
    [[ "$(git -C "$1" show "$2:$json" 2>/dev/null | jq -r .version)" != "$(jq -r .version "$1/$json")" ]] || echo "$p"
  done
}

rules_repo() {
  RULES_REPO="$SANDBOX/rules"
  mkdir -p "$RULES_REPO/global/skills/x" "$RULES_REPO/mods/p/.claude-plugin" "$RULES_REPO/mods/p/scripts"
  printf 'a\n' >"$RULES_REPO/global/skills/x/SKILL.md"
  printf '{"version":"1.0.0"}\n' >"$RULES_REPO/mods/p/.claude-plugin/plugin.json"
  printf 'a\n' >"$RULES_REPO/mods/p/scripts/s.sh"
  printf 'a\n' >"$RULES_REPO/mods/p/README.md"
  git init -q -b main "$RULES_REPO"
  git -C "$RULES_REPO" add -A
  git -C "$RULES_REPO" -c user.name=t -c user.email=t@t commit -q -m init
}

test_md_long_lines_flags_prose_only() {
  rules_repo
  local long
  long="$(printf 'é%.0s' {1..121})"
  printf '%s\n| %s |\ndescription: %s\n%s\n' "$(printf 'é%.0s' {1..120})" "$long" "$long" "$long" \
    >>"$RULES_REPO/global/skills/x/SKILL.md"
  printf '%s\n' "$long" >>"$RULES_REPO/mods/p/README.md"
  assert_eq "$(md_long_lines "$RULES_REPO" HEAD)" \
    "$(printf 'global/skills/x/SKILL.md: 121 colonnes\nmods/p/README.md: 121 colonnes')" "lignes signalées"
}

test_plugins_without_bump() {
  rules_repo
  printf 'b\n' >>"$RULES_REPO/mods/p/scripts/s.sh"
  assert_eq "$(plugins_without_bump "$RULES_REPO" HEAD)" p "plugin modifié sans version"
  printf '{"version":"1.0.1"}\n' >"$RULES_REPO/mods/p/.claude-plugin/plugin.json"
  assert_eq "$(plugins_without_bump "$RULES_REPO" HEAD)" "" "version montée"
}

# Branche courante contre origin/main : rien à vérifier sur main ou sans origin/main.
test_branch_respects_rules() {
  local base
  base="$(git -C "$REPO_SRC" merge-base HEAD origin/main 2>/dev/null)" || return 0
  assert_eq "$(md_long_lines "$REPO_SRC" "$base")" "" "lignes Markdown de plus de 120 colonnes"
  assert_eq "$(plugins_without_bump "$REPO_SRC" "$base")" "" "plugin modifié sans montée de version"
}

# Un githook qui lance les tests ou crée des dépôts hérite de GIT_DIR quand il part d'un worktree.
test_githooks_unset_git_env() {
  local f
  for f in "$REPO_SRC"/githooks/*; do
    grep -qE 'tests/run\.sh|git init' "$f" || continue
    awk '/^[[:space:]]*#/ {next} /unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_COMMON_DIR/ {u=1}
      /tests\/run\.sh|git init/ && !u {exit 1}' "$f" \
      || fail "$(basename "$f") lance des tests avant unset GIT_DIR…"
  done
}

# Tout script shell suivi passe dans shellcheck (motif de tests/run.sh).
test_shell_scripts_in_shellcheck_scope() {
  local f
  while IFS= read -r f; do
    case "$f" in *.sh | bin/* | githooks/*) continue ;; esac
    if head -n1 "$REPO_SRC/$f" | grep -qE '^#!.*[/ ](ba)?sh([[:space:]]|$)'; then
      fail "$f : script shell hors du motif shellcheck de tests/run.sh"
    fi
  done < <(git -C "$REPO_SRC" ls-files)
}

# jq qui lit des lignes brutes (fromjson?) : une ligne non objet ne doit pas faire planter le select.
test_jq_fromjson_selects_objects() {
  local bad
  bad="$(git -C "$REPO_SRC" grep -n 'fromjson?' -- '*.sh' 'bin/*' 'githooks/*' ':!tests/test_rules.sh' \
    | grep -v 'type == "object"' || true)"
  assert_eq "$bad" "" "fromjson? sans select(type == \"object\" …)"
}

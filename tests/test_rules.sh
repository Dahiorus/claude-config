# shellcheck shell=bash
# shellcheck disable=SC2154
# Règles du CLAUDE.md vérifiées sur la branche courante plutôt qu'écrites en prose.

# Lignes Markdown ajoutées depuis <base> de plus de 120 colonnes, hors tableaux, blocs de code et description de
# frontmatter. Le diff à contexte complet montre tout le fichier, pour suivre les clôtures ``` et ~~~ : un bloc ne
# se ferme que par le même caractère, au moins aussi long, sans texte après (CommonMark).
md_long_lines() {  # <dépôt> <base>
  git -C "$1" diff -U1000000 "$2" -- CLAUDE.md 'global/*.md' 'mods/*.md' docs/domaine.md docs/reste-a-faire.md \
    | LC_ALL=C.UTF-8 awk '/^\+\+\+ /{f=substr($0,7); sub(/\t$/, "", f); bloc=""; next}
        /^[ +][[:space:]]*(```|~~~)/{match($0,/```+|~~~+/); m=substr($0,RSTART,RLENGTH)
          if (bloc == "") bloc = m
          else if (index(m, bloc) == 1 && substr($0, RSTART + RLENGTH) ~ /^[[:space:]]*$/) bloc = ""
          next}
        /^\+/ && bloc=="" && length>121 && !/^\+[[:space:]]*\|/ && !/^\+description:/ {print f": " length-1 " colonnes"}'
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

# Fichiers de consignes au-delà de leur budget de lignes. Le budget ne se relève pas pour faire passer une règle :
# une règle ajoutée en retire ou en déplace une autre. Il se baisse à la main quand le fichier rétrécit.
line_budget_overruns() {  # <dépôt>
  local f budget lines
  while read -r f budget; do
    [[ -f "$1/$f" ]] || { echo "$f : absent"; continue; }
    lines="$(wc -l <"$1/$f")"
    (( lines <= budget )) || echo "$f : $lines lignes, budget $budget"
  done <<<"CLAUDE.md 71
global/CLAUDE.md 26"
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

test_md_long_lines_skips_code_blocks() {
  rules_repo
  local long f="$RULES_REPO/global/skills/x/SKILL.md"
  long="$(printf 'é%.0s' {1..121})"
  printf '```bash\nx\n' >>"$f"
  git -C "$RULES_REPO" -c user.name=t -c user.email=t@t commit -qam bloc
  # Bloc ouvert hors du diff, puis bloc ~~~ ajouté, puis prose.
  printf '%s\n```\n~~~\n%s\n~~~\n%s\n' "$long" "$long" "$long" >>"$f"
  assert_eq "$(md_long_lines "$RULES_REPO" HEAD)" "global/skills/x/SKILL.md: 121 colonnes" "seule la prose est signalée"
  # Bloc ```` qui contient ``` et ```bash : seule une clôture du même marqueur, sans texte, le ferme.
  git -C "$RULES_REPO" -c user.name=t -c user.email=t@t commit -qam prose
  # shellcheck disable=SC2016
  printf '````md\n```\n%s\n```bash\n%s\n````\n%s\n' "$long" "$long" "$long" >>"$f"
  assert_eq "$(md_long_lines "$RULES_REPO" HEAD)" "global/skills/x/SKILL.md: 121 colonnes" 'bloc à 4 accents qui en contient 3'
}

test_md_long_lines_keeps_path_with_space() {
  rules_repo
  printf '%s\n' "$(printf 'é%.0s' {1..121})" >"$RULES_REPO/global/sp ace.md"
  git -C "$RULES_REPO" add -A
  assert_eq "$(md_long_lines "$RULES_REPO" HEAD)" "global/sp ace.md: 121 colonnes" "chemin avec espace"
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

test_line_budget_overruns_names_each_file() {
  local repo="$SANDBOX/budget"
  mkdir -p "$repo/global"
  seq 71 >"$repo/CLAUDE.md"
  seq 26 >"$repo/global/CLAUDE.md"
  assert_eq "$(line_budget_overruns "$repo")" "" "fichiers au budget"
  seq 72 >"$repo/CLAUDE.md"
  assert_eq "$(line_budget_overruns "$repo")" "CLAUDE.md : 72 lignes, budget 71" "CLAUDE.md au-delà"
  seq 27 >"$repo/global/CLAUDE.md"
  assert_eq "$(line_budget_overruns "$repo")" \
    "$(printf 'CLAUDE.md : 72 lignes, budget 71\nglobal/CLAUDE.md : 27 lignes, budget 26')" "les deux au-delà"
  seq 71 >"$repo/CLAUDE.md"
  assert_eq "$(line_budget_overruns "$repo")" "global/CLAUDE.md : 27 lignes, budget 26" "global/CLAUDE.md au-delà"
  rm "$repo/CLAUDE.md"
  assert_contains "$(line_budget_overruns "$repo")" "CLAUDE.md : absent" "fichier absent"
}

test_instruction_files_within_line_budget() {
  assert_eq "$(line_budget_overruns "$REPO_SRC")" "" "budget de lignes des CLAUDE.md"
}

# Un agent qui nomme la racine (<racine>) ou l'arbre (<arbre>) de la PR lance git et gh depuis ce dossier : sans
# `git -C <…>` ni `cd <…>`, la commande part du dossier de la session.
# shortcut: une commande coupée sur deux lignes échappe au test, à revoir si un cas réel le demande.
test_agents_with_root_run_git_from_it() {
  local f bad
  while IFS= read -r f; do
    bad="$(grep -nE 'git (grep|diff|log|show)|gh pr' "$REPO_SRC/$f" | grep -vE 'git -C <|cd <' || true)"
    assert_eq "$bad" "" "$f : commande git ou gh sans dossier"
  done < <(git -C "$REPO_SRC" grep -lE '<racine>|<arbre>' -- 'global/agents/*.md')
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

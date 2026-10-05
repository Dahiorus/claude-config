# shellcheck shell=bash
# shellcheck disable=SC2154

new_target() {
  mkdir -p "$SANDBOX/$1"
  printf '%s' "$SANDBOX/$1"
}

test_init_project_copies_template() {
  local t out
  t="$(new_target 'mon projet')"
  git -C "$t" init -q
  out="$("$CLI" init-project "$t")"
  assert_json_eq "$t/.claude/settings.json" '{"permissions":{"deny":["Read(./.env)","Read(./.env.*)","Read(./secrets/**)"]}}'
  assert_eq "$(head -n 1 "$t/CLAUDE.md")" "# mon projet" "titre du CLAUDE.md"
  assert_has_line "$out" written CLAUDE.md
  assert_has_line "$out" written .claude/settings.json
  assert_not_contains "$out" "warn"
}

test_init_project_keeps_existing_files() {
  local t out
  t="$(new_target p)"
  printf 'mien\n' > "$t/CLAUDE.md"
  out="$("$CLI" init-project "$t")"
  assert_has_line "$out" skipped "CLAUDE.md (exists)"
  assert_eq "$(cat "$t/CLAUDE.md")" "mien" "CLAUDE.md conservé"
}

test_init_project_force_backs_up() {
  local t bak
  t="$(new_target p)"
  printf 'mien\n' > "$t/CLAUDE.md"
  "$CLI" init-project "$t" --force >/dev/null
  assert_eq "$(head -n 1 "$t/CLAUDE.md")" "# p" "CLAUDE.md écrasé"
  bak="$(find "$t" -maxdepth 1 -name 'CLAUDE.md.bak-*')"
  [[ -n "$bak" ]] || fail "sauvegarde absente"
  assert_eq "$(cat "$bak")" "mien" "contenu sauvegardé"
}

test_init_project_updates_gitignore() {
  local t
  t="$(new_target p)"
  printf 'node_modules' > "$t/.gitignore"
  "$CLI" init-project "$t" >/dev/null
  assert_eq "$(cat "$t/.gitignore")" $'node_modules\n.claude/settings.local.json' ".gitignore"
  "$CLI" init-project "$t" >/dev/null
  assert_eq "$(grep -c 'settings.local.json' "$t/.gitignore")" 1 "nombre d'entrées"
}

test_init_project_without_gitignore() {
  local t
  t="$(new_target p)"
  "$CLI" init-project "$t" >/dev/null
  [[ ! -e "$t/.gitignore" ]] || fail ".gitignore ne doit pas être créé"
}

test_init_project_warns_outside_git() {
  local t out
  t="$(new_target p)"
  out="$("$CLI" init-project "$t")"
  assert_contains "$out" "pas un repo git"
}

test_init_project_name_with_special_chars() {
  local t
  t="$(new_target 'a&b')"
  "$CLI" init-project "$t" >/dev/null
  assert_eq "$(head -n 1 "$t/CLAUDE.md")" "# a&b" "titre du CLAUDE.md"
}

test_init_project_missing_dir_fails() {
  local rc=0 out
  out="$("$CLI" init-project "$SANDBOX/absent" 2>&1)" || rc=$?
  assert_eq "$rc" 1 "code de sortie"
  assert_contains "$out" "dossier introuvable"
}

test_init_project_unknown_template_fails() {
  local t rc=0 out
  t="$(new_target p)"
  out="$("$CLI" init-project "$t" --template nope 2>&1)" || rc=$?
  assert_eq "$rc" 1 "code de sortie"
  assert_contains "$out" "template inconnu : nope"
}

test_init_project_without_dir_fails() {
  local rc=0
  "$CLI" init-project >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" 2 "code de sortie"
}

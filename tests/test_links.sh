# shellcheck shell=bash
# shellcheck disable=SC2154

add_skill_fixture() {
  mkdir -p "$REPO/global/skills/my-skill"
  printf -- '---\nname: my-skill\n---\n' > "$REPO/global/skills/my-skill/SKILL.md"
}

test_install_links_on_empty_home() {
  add_skill_fixture
  "$CLI" install --no-deps >/dev/null
  local f
  for f in CLAUDE.md RTK.md statusline-command.sh; do
    assert_symlink_to "$CLAUDE_HOME/$f" "$REPO/global/$f"
  done
  assert_symlink_to "$CLAUDE_HOME/skills/my-skill" "$REPO/global/skills/my-skill"
  [[ ! -e "$CLAUDE_HOME/skills/.gitkeep" ]] || fail ".gitkeep ne doit pas être lié"
}

test_install_links_idempotent() {
  add_skill_fixture
  "$CLI" install --no-deps >/dev/null
  local out
  out="$("$CLI" install --no-deps)"
  assert_not_contains "$out" "linked"
  assert_not_contains "$out" "backup"
  assert_has_line "$out" ok CLAUDE.md
  assert_has_line "$out" ok skills/my-skill
  assert_eq "$(count_backups "$CLAUDE_HOME")" 0 "nombre de sauvegardes"
}

test_install_backs_up_real_file() {
  mkdir -p "$CLAUDE_HOME"
  printf 'ancien\n' > "$CLAUDE_HOME/CLAUDE.md"
  local out bak
  out="$("$CLI" install --no-deps)"
  assert_has_line "$out" linked CLAUDE.md
  assert_symlink_to "$CLAUDE_HOME/CLAUDE.md" "$REPO/global/CLAUDE.md"
  bak="$(find "$CLAUDE_HOME" -maxdepth 1 -name 'CLAUDE.md.bak-*')"
  [[ -n "$bak" ]] || fail "sauvegarde de CLAUDE.md absente"
  assert_eq "$(cat "$bak")" "ancien" "contenu sauvegardé"
}

test_install_relinks_foreign_symlink() {
  mkdir -p "$CLAUDE_HOME"
  ln -s /nonexistent "$CLAUDE_HOME/RTK.md"
  local out
  out="$("$CLI" install --no-deps)"
  assert_has_line "$out" relinked RTK.md
  assert_symlink_to "$CLAUDE_HOME/RTK.md" "$REPO/global/RTK.md"
  assert_eq "$(count_backups "$CLAUDE_HOME")" 0 "nombre de sauvegardes"
}

test_install_keeps_foreign_entries() {
  mkdir -p "$CLAUDE_HOME/skills/synced/abc" "$CLAUDE_HOME/skills/other" "$SANDBOX/agents/angular-developer"
  printf 'x' > "$CLAUDE_HOME/skills/other/SKILL.md"
  ln -s "$SANDBOX/agents/angular-developer" "$CLAUDE_HOME/skills/angular-developer"
  local before
  before="$(snapshot "$CLAUDE_HOME/skills")"
  "$CLI" install --no-deps >/dev/null
  assert_eq "$(snapshot "$CLAUDE_HOME/skills")" "$before" "contenu de skills/"
}

test_install_via_symlinked_cli() {
  mkdir -p "$SANDBOX/bin"
  ln -s "$CLI" "$SANDBOX/bin/claude-config"
  "$SANDBOX/bin/claude-config" install --no-deps >/dev/null
  assert_symlink_to "$CLAUDE_HOME/CLAUDE.md" "$REPO/global/CLAUDE.md"
}

test_install_dry_run_changes_nothing() {
  mkdir -p "$CLAUDE_HOME"
  printf 'ancien\n' > "$CLAUDE_HOME/CLAUDE.md"
  printf '{"x":1}\n' > "$CLAUDE_HOME/settings.json"
  local before out
  before="$(snapshot "$SANDBOX")"
  out="$("$CLI" install --dry-run --no-deps)"
  assert_eq "$(snapshot "$SANDBOX")" "$before" "arborescence"
  assert_has_line "$out" linked CLAUDE.md
}

test_install_dry_run_on_missing_home() {
  "$CLI" install --dry-run --no-deps >/dev/null
  [[ ! -e "$CLAUDE_HOME" ]] || fail "dry-run ne doit pas créer $CLAUDE_HOME"
}

test_install_rejects_unknown_option() {
  local rc=0 out
  out="$("$CLI" install --frobnicate 2>&1)" || rc=$?
  assert_eq "$rc" 2 "code de sortie"
  assert_contains "$out" "option inconnue"
}

test_status_clean_after_install() {
  "$CLI" install --no-deps >/dev/null
  "$CLI" status >/dev/null || fail "status devrait renvoyer 0 juste après install"
}

test_status_reports_link_problems() {
  "$CLI" install --no-deps >/dev/null
  rm "$CLAUDE_HOME/CLAUDE.md"
  rm "$CLAUDE_HOME/RTK.md"
  printf 'x' > "$CLAUDE_HOME/RTK.md"
  rm "$CLAUDE_HOME/statusline-command.sh"
  ln -s /nonexistent "$CLAUDE_HOME/statusline-command.sh"
  local rc=0 out
  out="$("$CLI" status)" || rc=$?
  assert_eq "$rc" 1 "code de sortie"
  assert_has_line "$out" missing CLAUDE.md
  assert_has_line "$out" drift "RTK.md (fichier réel, pas un symlink)"
  assert_has_line "$out" broken statusline-command.sh
}

test_install_skips_hidden_files_and_links_symlinked_skills() {
  printf 'x' > "$REPO/global/.CLAUDE.md.swp"
  mkdir -p "$SANDBOX/ext-skill"
  ln -s "$SANDBOX/ext-skill" "$REPO/global/skills/linked-skill"
  "$CLI" install --no-deps >/dev/null
  [[ ! -e "$CLAUDE_HOME/.CLAUDE.md.swp" && ! -L "$CLAUDE_HOME/.CLAUDE.md.swp" ]] || fail "fichier caché lié"
  assert_symlink_to "$CLAUDE_HOME/skills/linked-skill" "$REPO/global/skills/linked-skill"
}

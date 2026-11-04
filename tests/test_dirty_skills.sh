# shellcheck shell=bash
# shellcheck disable=SC2154

# Dépôt jetable qui contient le hook, comme le dépôt claude-config relié à ~/.claude.
dirty_repo() {
  git init -q -b main "$SANDBOX/cc"
  mkdir -p "$SANDBOX/cc/global/skills/x"
  cp "$REPO/global/dirty-skills-hook.sh" "$SANDBOX/cc/global/"
  echo a >"$SANDBOX/cc/global/skills/x/SKILL.md"
  echo a >"$SANDBOX/cc/README.md"
  git -C "$SANDBOX/cc" add -A
  git -C "$SANDBOX/cc" -c user.name=t -c user.email=t@t commit -q -m init
  ln -s "$SANDBOX/cc/global/dirty-skills-hook.sh" "$SANDBOX/hook.sh"
}

test_dirty_skills_silent_when_clean() {
  dirty_repo
  echo b >"$SANDBOX/cc/README.md"
  assert_eq "$(bash "$SANDBOX/hook.sh")" "" "hors de global/"
}

test_dirty_skills_lists_modified_files() {
  dirty_repo
  echo b >"$SANDBOX/cc/global/skills/x/SKILL.md"
  local out
  out="$(bash "$SANDBOX/hook.sh")"
  assert_contains "$(jq -r .hookSpecificOutput.additionalContext <<<"$out")" "global/skills/x/SKILL.md"
  assert_contains "$(jq -r .systemMessage <<<"$out")" "non commités"
}

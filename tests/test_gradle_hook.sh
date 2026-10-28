# shellcheck shell=bash
# shellcheck disable=SC2154

# Décision du hook Gradle du template android (vide quand il laisse passer).
gradle_hook() {
  jq -nc --arg c "$1" '{tool_input:{command:$c}}' \
    | python3 "$REPO/templates/android/.claude/hooks/exiger-build-brief.py" \
    | jq -r '.hookSpecificOutput.permissionDecision // empty'
}

test_gradle_hook_denies_raw_gradle() {
  assert_eq "$(gradle_hook './gradlew build')" deny "./gradlew"
  assert_eq "$(gradle_hook 'cd app && gradle test')" deny "après &&"
  assert_eq "$(gradle_hook 'sh -c "./gradlew build"')" deny "sh -c"
  assert_eq "$(gradle_hook 'bash -c "./gradlew build"')" deny "bash -c"
}

test_gradle_hook_allows_build_brief() {
  assert_eq "$(gradle_hook 'build-brief ./gradlew build')" "" "build-brief"
  assert_eq "$(gradle_hook 'ls gradle')" "" "autre commande"
}

test_gradle_hook_points_to_shipped_doc() {
  local reason
  reason="$(jq -nc '{tool_input:{command:"./gradlew build"}}' \
    | python3 "$REPO/templates/android/.claude/hooks/exiger-build-brief.py" \
    | jq -r '.hookSpecificOutput.permissionDecisionReason')"
  assert_contains "$reason" "CLAUDE.md"
}

# shellcheck shell=bash
# shellcheck disable=SC2154

# PATH restreint au bac à sable : les vrais rtk et build-brief ne doivent pas répondre à la place des stubs.
# Stubs réalistes : build-brief préfixe les commandes Gradle, rtk préfixe git et ignore build-brief.
stub_rewriters() {
  mkdir -p "$STUBS"
  cat > "$STUBS/build-brief" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == rewrite ]] || exit 1
sed -E 's#(^|&& )\./gradlew#\1build-brief ./gradlew#g' <<<"$2"
EOF
  cat > "$STUBS/rtk" <<'EOF'
#!/usr/bin/env bash
cmd="$(jq -r .tool_input.command)"
new="$(sed -E 's#(^|&& )git #\1rtk git #g' <<<"$cmd")"
[[ "$new" != "$cmd" ]] || exit 0
jq -nc --arg c "$new" '{hookSpecificOutput:{hookEventName:"PreToolUse",updatedInput:{command:$c}}}'
EOF
  chmod +x "$STUBS/build-brief" "$STUBS/rtk"
  ln -s "$(command -v jq)" "$STUBS/jq"
}

run_hook() {
  jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c,description:"d"}}' \
    | PATH="$STUBS:/usr/bin:/bin" bash "$REPO/global/bash-rewrite-hook.sh"
}

hook_command() {
  run_hook "$1" | jq -r '.hookSpecificOutput.updatedInput.command'
}

test_hook_gradle_goes_to_build_brief() {
  stub_rewriters
  assert_eq "$(hook_command './gradlew test')" "build-brief ./gradlew test" "commande"
}

test_hook_build_brief_keeps_other_fields() {
  stub_rewriters
  assert_eq "$(run_hook './gradlew test' | jq -r '.hookSpecificOutput.updatedInput.description')" "d" "description"
}

test_hook_other_commands_go_to_rtk() {
  stub_rewriters
  assert_eq "$(hook_command 'git status')" "rtk git status" "commande"
}

test_hook_mixed_command_uses_both() {
  stub_rewriters
  assert_eq "$(hook_command 'git status && ./gradlew build')" "rtk git status && build-brief ./gradlew build" "commande"
}

test_hook_no_rewrite_prints_nothing() {
  stub_rewriters
  assert_eq "$(run_hook 'echo hi')" "" "sortie"
}

test_hook_without_build_brief_falls_back_to_rtk() {
  stub_rewriters
  rm "$STUBS/build-brief"
  assert_eq "$(hook_command 'git status && ./gradlew build')" "rtk git status && ./gradlew build" "commande"
}

test_hook_failing_build_brief_is_ignored() {
  stub_rewriters
  printf '#!/usr/bin/env bash\nexit 3\n' > "$STUBS/build-brief"
  assert_eq "$(hook_command 'git status')" "rtk git status" "commande"
}

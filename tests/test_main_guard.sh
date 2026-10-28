# shellcheck shell=bash
# shellcheck disable=SC2154

# Dépôt jetable sur main, avec une branche feat/x.
make_repo() {
  GUARD_REPO="$SANDBOX/work"
  git init -q -b main "$GUARD_REPO"
  git -C "$GUARD_REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  git -C "$GUARD_REPO" branch feat/x
}

# Sans sortie, le hook laisse passer.
guard() {
  local out
  out="$(guard_raw "$1")"
  echo "${out:-allow}"
}

guard_raw() {
  jq -nc --arg c "$1" --arg d "$GUARD_REPO" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' \
    | bash "$REPO/global/main-guard-hook.sh" | jq -r '.hookSpecificOutput.permissionDecision'
}

test_guard_denies_commit_on_main() {
  make_repo
  assert_eq "$(guard 'git add -A && rtk git commit -m "x y"')" deny "commit"
}

test_guard_denies_push_of_main() {
  make_repo
  assert_eq "$(guard 'git push')" deny "push"
  assert_eq "$(guard 'git push origin HEAD')" deny "push HEAD"
  assert_eq "$(guard 'git -c a=b push origin main')" deny "push main"
}

test_guard_allows_branch_tag_and_delete_from_main() {
  make_repo
  assert_eq "$(guard 'git push -u origin feat/x')" allow "branche"
  assert_eq "$(guard 'git push origin v1.2.0')" allow "tag"
  assert_eq "$(guard 'git push origin --delete feat/x')" allow "delete"
  assert_eq "$(guard 'git status')" allow "status"
}

test_guard_on_feature_branch() {
  make_repo
  git -C "$GUARD_REPO" switch -q feat/x
  assert_eq "$(guard 'git commit -m x && git push')" allow "commit et push"
  assert_eq "$(guard 'git push origin HEAD:main')" deny "push vers main"
}

test_guard_uses_dash_c_directory() {
  make_repo
  git -C "$GUARD_REPO" switch -q feat/x
  git init -q -b main "$SANDBOX/other"
  assert_eq "$(guard 'git -C ../other commit -m x')" deny "-C"
}

test_guard_judges_only_git_commands() {
  make_repo
  assert_eq "$(guard 'echo git push')" allow "echo"
  assert_eq "$(guard 'grep -rn git commit .')" allow "grep"
  assert_eq "$(guard 'sudo git commit -m x')" deny "sudo"
  assert_eq "$(guard 'GIT_TRACE=1 git push')" deny "variable"
  assert_eq "$(guard '/usr/bin/git push')" deny "chemin"
}

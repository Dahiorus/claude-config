# shellcheck shell=bash
# shellcheck disable=SC2154

# Dépôt jetable avec le pre-push et un tests/run.sh factice qui note les variables GIT_* qu'il reçoit.
hook_repo() {
  HOOK_REPO="$SANDBOX/hr"
  mkdir -p "$HOOK_REPO/githooks" "$HOOK_REPO/tests"
  cp "$REPO/githooks/pre-push" "$HOOK_REPO/githooks/"
  # shellcheck disable=SC2016 # $SANDBOX se développe dans le script factice (exporté par setup_sandbox)
  printf '%s\n' '#!/usr/bin/env bash' 'env | grep -E "^GIT_(DIR|WORK_TREE|INDEX_FILE|PREFIX|COMMON_DIR)=" >"$SANDBOX/git-env" || true' >"$HOOK_REPO/tests/run.sh"
  git init -q -b main "$HOOK_REPO"
  git -C "$HOOK_REPO" add -A
  git -C "$HOOK_REPO" -c user.name=t -c user.email=t@t commit -q -m init
}

pre_push() {  # <dossier> <sha poussé>
  (cd "$1" && printf 'refs/heads/x %s refs/heads/x 0000000000000000000000000000000000000000\n' "$2" \
    | bash githooks/pre-push)
}

test_pre_push_clears_git_env_from_worktree() {
  hook_repo
  git -C "$HOOK_REPO" worktree add -q "$SANDBOX/wt" -b wt
  local gd
  gd="$(git -C "$SANDBOX/wt" rev-parse --absolute-git-dir)"
  # Comme git le fait pour un hook lancé depuis un worktree.
  (export GIT_DIR="$gd" && pre_push "$SANDBOX/wt" "$(git -C "$SANDBOX/wt" rev-parse HEAD)")
  [[ -e "$SANDBOX/git-env" ]] || fail "tests non lancés"
  assert_eq "$(cat "$SANDBOX/git-env")" "" "variables GIT_* reçues par les tests"
}

test_pre_push_refuses_dirty_tree() {
  hook_repo
  echo x >"$HOOK_REPO/README"
  if pre_push "$HOOK_REPO" "$(git -C "$HOOK_REPO" rev-parse HEAD)" 2>/dev/null; then fail "push accepté"; fi
  [[ ! -e "$SANDBOX/git-env" ]] || fail "tests lancés"
}

test_pre_push_refuses_other_branch() {
  hook_repo
  if pre_push "$HOOK_REPO" 1111111111111111111111111111111111111111 2>/dev/null; then fail "push accepté"; fi
}

test_pre_push_skips_branch_deletion() {
  hook_repo
  pre_push "$HOOK_REPO" 0000000000000000000000000000000000000000
  [[ ! -e "$SANDBOX/git-env" ]] || fail "tests lancés"
}

test_install_sets_hooks_path_in_git_repo() {
  git init -q "$REPO"
  "$CLI" install --dry-run --no-deps >/dev/null
  assert_eq "$(git -C "$REPO" config core.hooksPath || true)" "" "après dry-run"
  "$CLI" install --no-deps >/dev/null
  assert_eq "$(git -C "$REPO" config core.hooksPath)" githooks "après install"
}

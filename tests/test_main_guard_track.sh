# shellcheck shell=bash
# shellcheck disable=SC2154
# Caractérisation du suivi des cd et des switch (issue #109) ; make_repo et guard viennent de test_main_guard.sh.

# Chemin relatif : read -ra coupe un chemin à espaces, et le bac à sable en contient.
test_guard_track_reads_dash_c_of_switch() {
  make_repo
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'git -C ../work commit -m x')" deny "commit -C sur main"
  assert_eq "$(guard 'git -C ../work switch -c y && git -C ../work commit -m x')" allow "switch -C"
}

test_guard_track_skips_prefix_of_cd() {
  make_repo
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  assert_eq "$(guard 'env cd ../wt && git commit -m x')" allow "env cd"
}

test_guard_counts_each_segment_once() {
  make_repo
  local c
  c="$(printf 'git status; %.0s' {1..1499})git status"
  assert_eq "$(guard "$c")" allow "1500 git"
}

test_guard_forgets_previous_segment() {
  make_repo
  assert_eq "$(guard 'git switch -c y && git commit -m x; echo ok')" allow "segment non git après un commit permis"
}

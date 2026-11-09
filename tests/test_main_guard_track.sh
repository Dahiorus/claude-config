# shellcheck shell=bash
# shellcheck disable=SC2154
# Caractérisation du suivi des cd et des switch (issue #109) ; make_repo et guard viennent de test_main_guard.sh.

# Chemin relatif : read -ra coupe un chemin à espaces, et le bac à sable en contient.
test_guard_track_reads_dash_c_of_switch() {
  make_repo
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'git -C ../work push')" deny "push -C sur main"
  assert_eq "$(guard 'git -C ../work switch -c y && git -C ../work push')" allow "switch -C"
}

# env cd lance un programme externe : le shell garde son dossier, le push part de main.
# command cd et builtin cd lancent le builtin : le shell change de dossier.
test_guard_track_skips_prefix_of_cd() {
  make_repo
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  assert_eq "$(guard 'env cd ../wt && git push')" deny "env cd"
  assert_eq "$(guard 'builtin cd ../wt && git push')" allow "builtin cd vers le worktree"
  assert_eq "$(guard 'command cd ../wt && git push')" allow "command cd vers le worktree"
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'builtin cd ../work && git push')" deny "builtin cd vers main"
  assert_eq "$(guard 'command cd ../work && git push')" deny "command cd vers main"
}

test_guard_counts_each_segment_once() {
  make_repo
  local c
  c="$(printf 'git status; %.0s' {1..1499})git status"
  assert_eq "$(guard "$c")" allow "1500 git"
}

# Chaque « cd …; » ajoute un état : au-delà de 64, refus d'un appel qui cite git et push.
test_guard_caps_possible_states() {
  make_repo
  local c="" k
  for ((k = 1; k <= 65; k++)); do mkdir -p "$SANDBOX/d/$k"; c+="cd ../d/$k; "; done
  assert_eq "$(guard "${c}git push origin feat/x")" deny "65 états"
  assert_eq "$(guard "${c}ls")" allow "65 états sans push"
}

# Budget de 40 s : MAIN_GUARD_BUDGET le raccourcit, ce qui évite d'attendre.
test_guard_caps_judging_time() {
  make_repo
  assert_eq "$(MAIN_GUARD_BUDGET=0 guard 'git push origin feat/x')" deny "budget dépassé avec push"
  assert_eq "$(MAIN_GUARD_BUDGET=0 guard 'ls')" allow "budget dépassé sans push"
  assert_eq "$(guard 'git push origin feat/x')" allow "dans le budget"
  assert_eq "$(MAIN_GUARD_BUDGET=999 guard 'git push origin feat/x')" allow "budget plafonné à 40 s, pas de refus"
}

# SECONDS venu de l'environnement ne change pas le budget.
test_guard_budget_ignores_inherited_seconds() {
  make_repo
  assert_eq "$(SECONDS=100 guard 'git push origin feat/x')" allow "SECONDS élevé hérité"
  assert_eq "$(SECONDS=-100 guard 'git push origin feat/x')" allow "SECONDS négatif hérité"
}

test_guard_forgets_previous_segment() {
  make_repo
  assert_eq "$(guard 'git switch -c y && git push; echo ok')" allow "segment non git après un push permis"
}

# Caractérisation des cas de push gardés (issue #111), verts avant et après la réduction du hook.
test_guard_keeps_push_through_cd() {
  make_repo
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  assert_eq "$(guard 'cd ../wt && git push')" allow "cd && push"
  assert_eq "$(guard $'cd ../wt &&\ngit push')" allow "&& en fin de ligne"
  assert_eq "$(guard 'cd ../wt; git push')" deny "cd ; push"
  assert_eq "$(guard 'cd ../wt || git push')" deny "cd || push"
  assert_eq "$(guard 'cd ../wt && { git push; }')" allow "{ } après cd"
  assert_eq "$(guard 'cd ../wt && git commit -m "a; b" && git push')" allow "; entre guillemets"
  assert_eq "$(guard $'cd ../wt && git commit -m "titre\n\ncorps" && git push')" allow "saut de ligne entre guillemets"
  assert_eq "$(guard 'git -C ../wt push')" allow "-C vers le worktree"
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'git -C ../work push')" deny "-C vers main"
  assert_eq "$(guard 'cd ../work && git push')" deny "cd vers main"
}

test_guard_keeps_push_through_switch() {
  make_repo
  mkdir "$GUARD_REPO/sub"
  assert_eq "$(guard 'git switch -c z && git push -u origin HEAD')" allow "switch -c && push HEAD"
  assert_eq "$(guard 'git switch -c z && cd sub && git push')" allow "sous-dossier du dépôt"
  assert_eq "$(guard 'git switch -c z && git switch main && git push')" deny "retour sur main"
  assert_eq "$(guard 'git switch -c z; git push')" deny "switch ; push"
}

test_guard_keeps_push_prefixes() {
  make_repo
  assert_eq "$(guard 'rtk git push')" deny "rtk"
  assert_eq "$(guard 'sudo git push')" deny "sudo"
  assert_eq "$(guard 'X=1 git push')" deny "variable"
  assert_eq "$(guard '/usr/bin/git push')" deny "chemin"
  assert_eq "$(guard 'echo git push')" allow "echo"
}

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

# Un code de retour non nul du hook sort « exit <code> » : un plantage ne passe pas pour un allow.
guard_raw() {
  local out
  out="$(jq -nc --arg c "$1" --arg d "$GUARD_REPO" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' \
    | bash "$REPO/global/main-guard-hook.sh")" || { echo "exit $?"; return; }
  jq -r '.hookSpecificOutput.permissionDecision' <<<"$out"
}

test_guard_allows_commit_on_main() {
  make_repo
  assert_eq "$(guard 'git add -A && rtk git commit -m "x y"')" allow "commit"
  assert_eq "$(guard $'cat > f <<\'EOF\'\ngit commit -m x\nEOF')" allow "git commit dans un heredoc"
}

test_guard_denies_push_of_main() {
  make_repo
  assert_eq "$(guard 'git push')" deny "push"
  assert_eq "$(guard 'git push origin HEAD')" deny "push HEAD"
  assert_eq "$(guard 'git push origin +HEAD')" deny "push +HEAD"
  assert_eq "$(guard 'git -c a=b push origin main')" deny "push main"
  assert_eq "$(guard 'git push -f origin main')" deny "-f"
  assert_eq "$(guard 'git push origin +main')" deny "+main"
  assert_eq "$(guard 'git push origin feat/x:main')" deny "src:main"
  assert_eq "$(guard 'git push origin x:refs/heads/main')" deny "refs/heads/main"
  assert_eq "$(guard 'git push origin a b main')" deny "plusieurs refspecs"
  assert_eq "$(guard 'git push origin - main')" deny "- main"
  assert_eq "$(guard 'git --git-dir .git push origin main')" deny "--git-dir et sa valeur"
  assert_eq "$(guard 'git --work-tree . push origin main')" deny "--work-tree et sa valeur"
  assert_eq "$(guard 'git --namespace x push origin main')" deny "--namespace et sa valeur"
}

test_guard_closes_push_holes() {
  make_repo
  assert_eq "$(guard 'git push origin "main"')" deny "main entre guillemets"
  assert_eq "$(guard 'git push --tags origin main')" deny "--tags avec refspec"
  assert_eq "$(guard 'git push origin --delete main')" deny "--delete main"
  assert_eq "$(guard 'git push -d origin main')" deny "-d main"
  assert_eq "$(guard 'git push -o ci.skip origin')" deny "-o et sa valeur"
  assert_eq "$(guard 'git push --push-option ci.skip origin')" deny "--push-option et sa valeur"
  assert_eq "$(guard 'git push --all origin')" deny "--all"
  assert_eq "$(guard 'git push --mirror origin')" deny "--mirror"
  assert_eq "$(guard 'git push origin 2>&1 | tail -5')" deny "redirection 2>&1"
  assert_eq "$(guard 'git push origin main&>/dev/null')" deny "main&> collé"
  assert_eq "$(guard 'git push origin HEAD&>x')" deny "HEAD&> collé"
  assert_eq "$(guard 'git push origin feat/x&>/dev/null')" allow "feat/x&> collé"
  assert_eq "$(guard 'git push >/dev/null 2>&1')" deny "redirections sans refspec"
  assert_eq "$(guard 'git push origin > /tmp/log')" deny "redirection et sa cible"
  assert_eq "$(guard 'git push origin main>/dev/null')" deny "redirection collée à main"
  assert_eq "$(guard 'git push origin feat/x > /tmp/log')" allow "redirection après une autre branche"
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'git push --mirror origin')" deny "--mirror depuis le worktree"
  assert_eq "$(guard 'git push --branches origin')" deny "--branches depuis le worktree"
  GUARD_REPO="$SANDBOX/work"
  assert_eq "$(guard 'git push --branches origin')" deny "--branches depuis main"
}

test_guard_allows_branch_tag_and_delete_from_main() {
  make_repo
  assert_eq "$(guard 'git push -u origin feat/x')" allow "branche"
  assert_eq "$(guard 'git push origin v1.2.0')" allow "tag"
  assert_eq "$(guard 'git push --tags')" allow "--tags sans refspec"
  assert_eq "$(guard 'git push origin --delete feat/x')" allow "delete"
  assert_eq "$(guard 'git push -o ci.skip origin feat/x')" allow "-o vers une branche"
  assert_eq "$(guard 'git status')" allow "status"
}

test_guard_on_feature_branch() {
  make_repo
  git -C "$GUARD_REPO" switch -q feat/x
  assert_eq "$(guard 'git commit -m x && git push')" allow "commit et push"
  assert_eq "$(guard 'git push origin HEAD:main')" deny "push vers main"
  assert_eq "$(guard 'git push --all origin')" deny "--all depuis une branche"
}

test_guard_uses_dash_c_directory() {
  make_repo
  git -C "$GUARD_REPO" switch -q feat/x
  git init -q -b main "$SANDBOX/other"
  assert_eq "$(guard 'git -C ../other push')" deny "-C"
  git -C "$GUARD_REPO" switch -q main
  assert_eq "$(guard 'git -C ../work push')" deny "-C vers le dépôt sur main, depuis main"
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'git -C ../work push')" deny "-C vers le dépôt sur main depuis le worktree"
}

test_guard_judges_only_git_commands() {
  make_repo
  assert_eq "$(guard 'grep -rn git push .')" allow "grep"
  assert_eq "$(guard 'GIT_TRACE=1 git push')" deny "variable"
}

test_guard_follows_cd() {
  make_repo
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  assert_eq "$(guard "cd \"$SANDBOX/wt\" && git add -A && git push")" allow "cd vers un worktree de branche"
  assert_eq "$(guard 'cd ../wt | cat; git push')" deny "cd dans un pipeline"
  assert_eq "$(guard 'false && cd ../wt; git push')" deny "cd sauté"
  assert_eq "$(guard "cd $SANDBOX/wt && cd $GUARD_REPO && git push")" deny "retour sur main"
  ln -s "$SANDBOX/wt" "$HOME/wt"
  assert_eq "$(guard 'cd ~/wt && git push')" allow "cd ~"
  assert_eq "$(guard 'cd -P ../wt && git push')" allow "option de cd"
  assert_eq "$(guard 'pushd ../wt && git push')" allow "pushd"
  assert_eq "$(guard "cd ../wt && cd -- $GUARD_REPO && git push")" deny "cd -- vers main"
  assert_eq "$(guard 'cd ../wt 2>/dev/null && git push')" allow "cd suivi d'une redirection"
  assert_eq "$(guard 'cd ../wt && git log | head -3 && git push')" allow "cd avant un pipeline"
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'pushd ../work >/dev/null && git push')" deny "pushd suivi d'une redirection, vers main"
  assert_eq "$(guard 'cd ../work && git log | head -3 && git push origin HEAD')" deny "cd vers main avant un pipeline"
}

test_guard_reads_lines_and_comments() {
  make_repo
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  assert_eq "$(guard $'cd ../wt\ngit push')" deny "cd puis saut de ligne"
  assert_eq "$(guard $'cd ../wt && \\\ngit add . && \\\ngit push')" allow "suite de ligne par \\"
  assert_eq "$(guard $'git \\\n  push')" deny "commande coupée par \\"
  assert_eq "$(guard $'cd ../wt && # va dans l\'arbre\ngit push')" allow "commentaire avec apostrophe"
  assert_eq "$(guard 'echo a#b; git push')" deny "# dans un mot : pas un commentaire"
  assert_eq "$(guard $'git switch -c feat/y && git commit -m "$(cat <<\'EOF\'\ntitre\n\nl\'appel; a | b\nEOF\n)" && git push -u origin HEAD')" allow "message par \$(cat <<'EOF')"
  assert_eq "$(guard $'cat > f <<\'EOF\'\nl\'erreur\nEOF\ngit push')" deny "apostrophe seule dans un heredoc : repli"
  assert_eq "$(guard 'echo "a; git push')" deny "guillemet seul : repli"
  assert_eq "$(guard 'cd ../wt && git commit -m "a \" ; b" && git push')" allow "\\\" entre guillemets doubles ne ferme pas"
}

test_guard_splits_on_background_and_groups() {
  make_repo
  assert_eq "$(guard 'true & git push')" deny "& seul"
  assert_eq "$(guard 'git log |& git push')" deny "|&"
  assert_eq "$(guard '(git push)')" deny "( )"
  # shellcheck disable=SC2016 # commande littérale
  assert_eq "$(guard 'x=$(git push)')" deny "\$( ) hors guillemets"
  # shellcheck disable=SC2016 # commande littérale
  assert_eq "$(guard 'echo `git push`')" deny "backticks hors guillemets"
  assert_eq "$(guard '{ git push; }')" deny "{ }"
  assert_eq "$(guard 'if true; then git push; fi')" deny "if/then"
  assert_eq "$(guard '(cd ../wt) && git push')" deny "cd dans un sous-shell"
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  # shellcheck disable=SC2016 # commande littérale
  assert_eq "$(guard 'git switch -c z && v=$(git rev-parse HEAD) && git push')" allow "\$( ) garde la branche prise"
  GUARD_REPO="$SANDBOX/wt"
  # shellcheck disable=SC2016 # commande littérale
  assert_eq "$(guard 'cd ../work && v=$(git rev-parse HEAD) && git push')" deny "\$( ) garde le dossier jugé"
  # shellcheck disable=SC2016 # commande littérale
  assert_eq "$(guard 'cd ../work && v=`git rev-parse HEAD` && git push')" deny "backticks gardent le dossier jugé"
  GUARD_REPO="$SANDBOX/work"
  assert_eq "$(guard 'git log 2>&1 | head && git status &>/dev/null')" allow "redirections avec &"
  assert_eq "$(guard $'echo "\ntrue & git push')" deny "& en repli"
  assert_eq "$(guard 'echo a\>& git push')" deny "\\> n'est pas une redirection : & sépare"
}

# Anciennes limites du parseur maison, lues correctement sur l'arbre de shfmt.
test_guard_reads_former_shortcuts() {
  make_repo
  git -C "$GUARD_REPO" worktree add -q -b feat/w "$SANDBOX/wt"
  assert_eq "$(guard $'cd ../wt && git commit -m "a; b" && git push && echo l\'x')" deny "guillemet seul : illisible, refus"
  # shellcheck disable=SC2016 # $W reste littéral : chemin calculé
  assert_eq "$(guard 'cd "$W" && git push')" deny "cd non résolu : dossier inconnu"
  # shellcheck disable=SC2016 # commande littérale
  assert_eq "$(guard 'echo "$(git push)"')" deny "\$( ) entre guillemets doubles jugé"
  # shellcheck disable=SC2016 # commande littérale
  assert_eq "$(guard 'echo "$(printf "%s" "l'\''a")" && git push && echo "$(printf "%s" "c'\''est")"')" deny "apostrophes dans \$( ) entre guillemets"
  # shellcheck disable=SC2016 # commande littérale
  assert_eq "$(guard 'x=$(cd ../wt) && git push')" deny "cd dans \$( ) : sous-shell"
  assert_eq "$(guard $'echo $\'it\\\'s\' ; git push origin main ; echo x\\\'')" deny "\$'…' lu selon bash"
  assert_eq "$(guard $'cat > f <<EOF\ngit push\nEOF')" allow "ligne de heredoc : texte"
  assert_eq "$(guard $'cat > f <<EOF\nl\'un\nEOF\ngit push\ncat > g <<EOF\nl\'autre\nEOF')" deny "apostrophes de heredoc"
  assert_eq "$(guard 'true | cd ../wt && git push')" deny "cd d'un élément de pipeline : sous-shell"
  assert_eq "$(guard 'git push origin {fd}>x')" deny "{fd}> : redirection"
  git -C "$GUARD_REPO" switch -q feat/x
  assert_eq "$(guard 'git switch main; git push')" deny "après ; la branche prise reste possible"
  assert_eq "$(guard 'git push origin >| x main')" deny ">| : redirection"
  assert_eq "$(guard 'git push origin <&0 main')" deny "<& : redirection"
  git -C "$GUARD_REPO" config branch.feat/x.remote origin
  git -C "$GUARD_REPO" config branch.feat/x.merge refs/heads/main
  git -C "$GUARD_REPO" config push.default upstream
  assert_eq "$(guard 'git push')" deny "upstream main"
}

test_guard_caps_forks_not_lines() {
  make_repo
  local c
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  # Deux processus par push depuis le worktree (branche, config) : plus de 2000 au total.
  c="$(printf 'git -C ../wt push; %.0s' {1..1000})git -C ../wt push"
  assert_eq "$(guard "$c")" deny "plus de 2000 processus"
  c="cat > f <<'EOF'"$'\n'"$(printf 'l\n%.0s' {1..2500})"$'\nEOF'
  assert_eq "$(guard "$c")" allow "2500 lignes de heredoc sans git"
}

test_guard_refuses_unreadable_input() {
  make_repo
  local code=0
  echo 'pas du json' | bash "$REPO/global/main-guard-hook.sh" 2>/dev/null || code=$?
  assert_eq "$code" 2 "JSON invalide : refus (exit 2)"
}

test_guard_follows_switch_in_same_command() {
  make_repo
  assert_eq "$(guard 'git switch -q -c feat/y origin/main && git add . && git push')" allow "switch -c"
  assert_eq "$(guard 'git checkout -b feat/y && git push -u origin HEAD')" allow "checkout -b"
  assert_eq "$(guard 'git checkout -qb feat/y && git push')" allow "options courtes collées"
  assert_eq "$(guard 'git switch -C feat/y && git push')" allow "switch -C"
  assert_eq "$(guard 'git checkout -B feat/y && git push')" allow "checkout -B"
  assert_eq "$(guard 'git switch --create feat/y && git push -u origin HEAD')" allow "switch --create"
  assert_eq "$(guard 'git switch --force-create feat/y && git push')" allow "switch --force-create"
  assert_eq "$(guard 'git checkout --orphan feat/y && git push')" allow "checkout --orphan"
  assert_eq "$(guard 'git switch -c a && git log | head -1 && git push origin HEAD')" allow "switch -c avant un pipeline"
  assert_eq "$(guard 'git switch -c a | cat && git push')" deny "switch dans un pipeline"
  assert_eq "$(guard 'git switch -c feat/y || git push')" deny "switch suivi de ||"
  assert_eq "$(guard 'git switch -c feat/y && git checkout main && git push')" deny "checkout main"
  assert_eq "$(guard 'git switch -c feat/y && git switch - && git push')" deny "switch - : inconnue"
  assert_eq "$(guard 'git switch -c feat/y && git checkout README.md && git push')" deny "checkout d'un fichier : inconnue"
  assert_eq "$(guard 'git switch feat/x && git push')" deny "switch vers une branche existante : inconnue"
  assert_eq "$(guard 'git switch -c feat/y && git add . ; git push')" deny "; plus loin dans la chaîne"
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'git switch main && git push')" deny "switch main depuis le worktree"
  assert_eq "$(guard 'git checkout README.md && git push')" deny "checkout d'un fichier depuis le worktree : inconnue"
}

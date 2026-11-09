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

test_guard_follows_cd() {
  make_repo
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  assert_eq "$(guard "cd \"$SANDBOX/wt\" && git add -A && git commit -m x")" allow "cd vers un worktree de branche"
  assert_eq "$(guard 'cd ../wt && git commit -m x')" allow "cd relatif"
  assert_eq "$(guard 'cd ../wt; git commit -m x')" deny "cd suivi de ; : peut avoir échoué"
  assert_eq "$(guard 'cd ../wt || git commit -m x')" deny "cd suivi de ||"
  assert_eq "$(guard 'cd ../wt | cat; git commit -m x')" deny "cd dans un pipeline"
  assert_eq "$(guard 'false && cd ../wt; git commit -m x')" deny "cd sauté"
  assert_eq "$(guard "cd $SANDBOX/wt && cd $GUARD_REPO && git commit -m x")" deny "retour sur main"
  # shellcheck disable=SC2016 # $W reste littéral : chemin calculé
  assert_eq "$(guard 'cd "$W" && git commit -m x')" deny "chemin calculé : dossier de départ"
  ln -s "$SANDBOX/wt" "$HOME/wt"
  assert_eq "$(guard 'cd ~/wt && git commit -m x')" allow "cd ~"
  assert_eq "$(guard 'cd -P ../wt && git commit -m x')" allow "option de cd"
  assert_eq "$(guard 'pushd ../wt && git commit -m x')" allow "pushd"
  assert_eq "$(guard 'cd ../wt && cd - && git commit -m x')" deny "cd - : dossier de départ"
  assert_eq "$(guard "cd ../wt && cd -- $GUARD_REPO && git commit -m x")" deny "cd -- vers main"
}

test_guard_treats_newline_as_semicolon() {
  make_repo
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  assert_eq "$(guard $'cd ../wt\ngit commit -m x')" deny "cd puis saut de ligne"
  assert_eq "$(guard $'git switch -c feat/y && git add .\ngit commit -m x')" deny "saut de ligne plus loin dans la chaîne"
  assert_eq "$(guard $'cd ../wt &&\ngit commit -m x')" allow "&& en fin de ligne"
  assert_eq "$(guard $'cd ../wt && \\\ngit add . && \\\ngit commit -m x')" allow "suite de ligne par \\"
  assert_eq "$(guard $'git \\\n  commit -m x')" deny "commande coupée par \\"
  assert_eq "$(guard $'cd ../wt && # va dans le wt\ngit commit -m x')" allow "&& suivi d'un commentaire"
  assert_eq "$(guard $'cd ../wt && git commit -m "titre\n\ncorps" && git push')" allow "saut de ligne entre guillemets"
  assert_eq "$(guard $'git switch -c feat/y && git commit -m "$(cat <<\'EOF\'\ntitre\n\nl\'appel; a | b\nEOF\n)" && git push -u origin HEAD')" allow "message par \$(cat <<'EOF')"
  assert_eq "$(guard $'cd ../wt && git commit -m "titre\n\ncorps"\ngit commit -m y')" deny "saut de ligne après la chaîne"
  assert_eq "$(guard $'cat > f <<\'EOF\'\nl\'erreur\nEOF\ngit commit -F f')" deny "heredoc nu : coupe à chaque ligne"
  assert_eq "$(guard 'echo a\ #b; git commit -m x')" deny "# après un blanc échappé : pas un commentaire"
  assert_eq "$(guard 'find . -exec echo {} \;#; git commit -m x')" deny "# après \\; : pas un commentaire"
  assert_eq "$(guard $'(true)# it\'s\ngit commit -m x\n(true)# it\'s')" deny "# après ) : commentaire"
}

test_guard_tracks_nested_quotes() {
  make_repo
  assert_eq "$(guard "echo \$'it\\'s'; git commit -m x; echo don\\'t")" deny "\\' dans \$'…'"
  # shellcheck disable=SC2016 # commande littérale
  assert_eq "$(guard 'echo "$(printf "%s" "l'\''appel")" && git commit -am x && echo "$(printf "%s" "c'\''est")"')" deny "guillemets dans \$( )"
  assert_eq "$(guard $'cat > f <<\'EOF\'\ngit log\nEOF\ngit commit -F f')" deny "après un heredoc"
  assert_eq "$(guard $'cat > f <<-EOF\n\tl\'erreur\n\tEOF\ngit push')" deny "heredoc <<- : apostrophe dans le corps"
  assert_eq "$(guard $'git switch -c feat/y && git commit -m "$(cat <<\'EOF\'\nun " seul\nEOF\n)" && git push -u origin HEAD')" allow "\" seul dans un heredoc de \$( )"
  assert_eq "$(guard 'git log <<< "x" && git status')" allow "<<< n'est pas un heredoc"
}

test_guard_splits_on_background_and_groups() {
  make_repo
  assert_eq "$(guard 'true & git commit -m x')" deny "& seul"
  assert_eq "$(guard 'git log |& git commit -m x')" deny "|&"
  assert_eq "$(guard '(git commit -m x)')" deny "( )"
  assert_eq "$(guard '{ git commit -m x; }')" deny "{ }"
  assert_eq "$(guard 'case a in a) git commit -m x;; esac')" deny "case"
  assert_eq "$(guard 'if true; then git commit -m x; fi')" deny "if/then"
  assert_eq "$(guard '(cd ../wt) && git commit -m x')" deny "cd dans un sous-shell"
  assert_eq "$(guard 'git log 2>&1 | head && git status &>/dev/null')" allow "redirections avec &"
  # Repli (<< arithmétique pris pour un heredoc, guillemet seul) : mêmes séparateurs.
  assert_eq "$(guard $'echo $((1<<2))\n(git commit -m x)')" deny "( ) en repli"
  assert_eq "$(guard $'echo "\ntrue & git commit -m x')" deny "& en repli"
  assert_eq "$(guard $'echo "\ntrue |& git commit -m x')" deny "|& en repli"
  assert_eq "$(guard 'echo a\>& git commit -m x')" deny "\\> n'est pas une redirection : & sépare"
}

test_guard_tracks_backticks_params_and_delimiters() {
  make_repo
  assert_eq "$(guard $'echo `true #`\ngit commit -m x\necho `true #`')" deny "# entre backticks"
  # shellcheck disable=SC2016 # commande littérale
  assert_eq "$(guard 'echo $(echo ${x/(/y}); git commit -m x; echo ${y/)/z}')" deny "( dans \${…} de \$( )"
  assert_eq "$(guard $'x=$(cat <<\'E"\'\nb\nE"\n)\ngit commit -m x\ny=$(cat <<E\nE\n)')" deny "délimiteur avec un guillemet"
  assert_eq "$(guard $'echo x\r#\'\n\'; git commit -m y; echo \'\nx\r#\'')" deny "\\r n'est pas un blanc"
  assert_eq "$(guard $'x=$(cat <<E\r\nE\r\n)\ngit commit -m x\ny=$(cat <<E\nE\n)')" deny "\\r dans le délimiteur d'un heredoc"
  # shellcheck disable=SC2016 # commande littérale
  assert_eq "$(guard $'echo ${x:- #}\ngit commit -m x\necho }')" deny "# dans \${…} : pas un commentaire"
  assert_eq "$(guard $'x=$(cat <<$\'E\'\nE\n)\ngit commit -m x\n$E\n)')" deny "délimiteur <<\$'E'"
}

test_guard_caps_forks_not_lines() {
  make_repo
  local c
  c="$(printf 'git status; %.0s' {1..2001})git status"
  assert_eq "$(guard "$c")" deny "plus de 2000 git"
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
  assert_eq "$(guard 'git switch -q -c feat/y origin/main && git add . && git commit -m x')" allow "switch -c"
  assert_eq "$(guard 'git checkout -b feat/y && git commit -m x && git push -u origin feat/y')" allow "checkout -b"
  assert_eq "$(guard 'git checkout README.md && git commit -m x')" deny "checkout d'un fichier"
  assert_eq "$(guard 'git switch feat/x && git switch main && git commit -m x')" deny "retour sur main"
  assert_eq "$(guard 'git switch -c feat/x; git commit -m x')" deny "switch suivi de ; : peut avoir échoué"
  assert_eq "$(guard 'git switch -c feat/y || git commit -m x')" deny "switch suivi de ||"
  assert_eq "$(guard 'git switch -c feat/y && git checkout main && git commit -m x')" deny "checkout main"
  assert_eq "$(guard 'git switch -c feat/y && git switch - && git commit -m x')" deny "switch -"
  assert_eq "$(guard 'git switch -c feat/y && git checkout - && git commit -m x')" deny "checkout -"
  assert_eq "$(guard 'git switch -c feat/y && git checkout @{-1} && git commit -m x')" deny "checkout @{-1}"
  assert_eq "$(guard 'git switch -c feat/y && git switch main; git commit -m x')" deny "retour sur main suivi de ;"
  assert_eq "$(guard 'git switch -c feat/y && git add . ; git commit -m x')" deny "; plus loin dans la chaîne"
  assert_eq "$(guard 'git switch -c feat/y && git add . || git commit -m x')" deny "|| plus loin dans la chaîne"
  assert_eq "$(guard 'git switch -c feat/y && git checkout README.md && git commit -m x')" allow "checkout d'un fichier après switch"
  assert_eq "$(guard 'git checkout -qb feat/y && git commit -m x')" allow "options courtes collées"
  mkdir "$GUARD_REPO/sub"
  assert_eq "$(guard 'git switch -c feat/y && cd sub && git commit -m x')" allow "sous-dossier du dépôt"
  git -C "$GUARD_REPO" switch -q feat/x
  assert_eq "$(guard 'git switch -c feat/y && git checkout - && git commit -m x')" allow "checkout - après switch : branche réelle"
  assert_eq "$(guard 'git checkout - && git commit -m x')" deny "checkout - : branche précédente main"
  assert_eq "$(guard 'git switch - && git commit -m x')" deny "switch - : branche précédente main"
  assert_eq "$(guard 'git checkout @{-1} && git commit -m x')" deny "checkout @{-1} : branche précédente main"
}

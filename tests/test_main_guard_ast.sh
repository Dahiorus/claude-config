# shellcheck shell=bash
# shellcheck disable=SC2154,SC2016 # commandes littérales : $ et backticks restent dans la chaîne
# Lecture de la commande sur l'arbre de shfmt ; make_repo et guard viennent de test_main_guard.sh.
# Depuis main (work) sauf mention ; wt est un worktree sur feat/x.

wt_repo() {
  make_repo
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
}

test_guard_ast_separators_keep_every_possible_state() {
  wt_repo
  assert_eq "$(guard 'true | cd ../wt && git push')" deny "cd dans un élément de pipeline"
  assert_eq "$(guard 'git switch -c y |& cat && git push')" deny "switch dans un pipeline |&"
  assert_eq "$(guard '{ cd ../wt; } && git push')" allow "{ } : même shell"
  assert_eq "$(guard '(cd ../wt && git push)')" allow "cd et push dans le même sous-shell"
  assert_eq "$(guard 'x=$(cd ../wt) && git push')" deny "cd dans \$( ) : sous-shell"
  assert_eq "$(guard 'cd ../wt & git push')" deny "cd en arrière-plan"
  assert_eq "$(guard '(cd ../wt) && git push')" deny "cd dans ( )"
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'cd ../work; git push')" deny "cd vers main puis ;"
  assert_eq "$(guard $'cd ../work\ngit push')" deny "cd vers main puis saut de ligne"
  assert_eq "$(guard 'git switch main; git push')" deny "switch puis ;"
  assert_eq "$(guard 'cd ../work & git push')" allow "cd en arrière-plan : le shell garde son dossier"
  assert_eq "$(guard 'cd ../work || true; git push origin feat/x')" allow "refspec explicite après ;"
}

test_guard_ast_judges_compound_commands() {
  make_repo
  assert_eq "$(guard 'case x in x) git push ;; esac')" deny "case"
  assert_eq "$(guard 'for b in 1; do git push; done')" deny "for"
  assert_eq "$(guard 'while false; do git push; done')" deny "while"
  assert_eq "$(guard 'until git push; do :; done')" deny "until (condition)"
  assert_eq "$(guard 'f() { git push; }')" deny "corps de fonction"
  assert_eq "$(guard 'cat <(git push)')" deny "<( )"
  assert_eq "$(guard '[[ -n $(git push) ]]')" deny "\$( ) dans [[ ]]"
  assert_eq "$(guard 'echo "$(git push)"')" deny "\$( ) entre guillemets doubles"
  assert_eq "$(guard 'echo "`git push`"')" deny "backticks entre guillemets doubles"
  assert_eq "$(guard 'echo "${x:-$(git push)}"')" deny "\$( ) dans \${ }"
  assert_eq "$(guard 'echo "git push"')" allow "texte entre guillemets"
}

test_guard_ast_reads_heredocs() {
  make_repo
  assert_eq "$(guard $'cat > f <<EOF\ngit push\nEOF')" allow "ligne de heredoc : texte"
  assert_eq "$(guard $'cat > f <<EOF\nl\'un\nEOF\ngit push\ncat > g <<EOF\nl\'autre\nEOF')" deny "apostrophes de heredoc"
  assert_eq "$(guard $'cat > f <<EOF\n$(git push)\nEOF')" deny "\$( ) dans un heredoc non cité"
  assert_eq "$(guard $'cat > f <<\'EOF\'\n$(git push)\nEOF')" allow "\$( ) dans un heredoc cité"
}

test_guard_ast_ignores_every_redirection() {
  make_repo
  git -C "$GUARD_REPO" switch -q feat/x
  assert_eq "$(guard 'git push origin >| x main')" deny ">|"
  assert_eq "$(guard 'git push origin <&0 main')" deny "<&"
  assert_eq "$(guard 'git push origin {fd}>x main')" deny "{fd}>"
  assert_eq "$(guard 'git push origin &>>log main')" deny "&>>"
  assert_eq "$(guard 'git push origin 3>&1- main')" deny "n>&m-"
  assert_eq "$(guard 'git push origin 2>main')" allow "main cible d'une redirection"
}

test_guard_ast_rebuilds_quoted_words() {
  make_repo
  git -C "$GUARD_REPO" switch -q feat/x
  assert_eq "$(guard "git push origin 'ma'\"in\"")" deny "mot en morceaux cités"
  assert_eq "$(guard "git push origin \$'main'")" deny "\$'…'"
  assert_eq "$(guard $'echo $\'it\\\'s\' ; git push origin main ; echo x\\\'')" deny "\\' dans \$'…'"
  assert_eq "$(guard 'git push origin ma\in')" deny "antislash hors guillemets"
  assert_eq "$(guard 'g\it push origin main')" deny "antislash dans git"
  assert_eq "$(guard "git push origin 'feat'\"/x\"")" allow "morceaux cités vers une branche"
  assert_eq "$(guard "git push origin \$'feat/x'")" allow "\$'…' vers une branche"
  assert_eq "$(guard "git push origin \$'ma\\x69n'")" deny "\$'…' avec antislash : inconnu"
}

test_guard_ast_unknown_words() {
  wt_repo
  assert_eq "$(guard 'cd "$W" && git push')" deny "cd calculé : dossier inconnu"
  assert_eq "$(guard 'cd "$W" && git push origin feat/x')" allow "cd calculé, refspec explicite"
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'git push origin "$B"')" deny "refspec calculée"
  assert_eq "$(guard 'git push $ARGS')" deny "expansion qui peut donner plusieurs mots"
  assert_eq "$(guard 'git push origin feat/*')" deny "glob"
  assert_eq "$(guard 'git push origin {feat/x,main}')" deny "accolades"
  assert_eq "$(guard '"$GIT" push origin main')" deny "commande calculée : jugée comme git"
  assert_eq "$(guard 'git push origin feat/[x]')" deny "glob entre crochets"
  GUARD_REPO="$SANDBOX/work"
  assert_eq "$(guard '[ -n "$t" ] && GH_TOKEN=$t git push origin --delete feat/x')" allow "[ seul : pas un glob"
  assert_eq "$(guard 'git push -u origin "$(git branch --show-current)"')" deny "branche du dossier, main"
}

test_guard_ast_skips_launch_prefixes() {
  wt_repo
  assert_eq "$(guard 'env -i A=1 git push')" deny "env"
  assert_eq "$(guard 'env -- git push')" deny "env --"
  assert_eq "$(guard 'sudo -u x git push')" deny "sudo -u"
  assert_eq "$(guard 'command git push')" deny "command"
  assert_eq "$(guard 'time git push')" deny "time"
  assert_eq "$(guard '/usr/bin/time -f %e git push')" deny "/usr/bin/time -f"
  assert_eq "$(guard 'nice -n 5 git push')" deny "nice -n"
  assert_eq "$(guard 'nohup git push')" deny "nohup"
  assert_eq "$(guard 'timeout -s KILL 30 git push')" deny "timeout"
  assert_eq "$(guard "bash -c 'git push'")" deny "bash -c"
  assert_eq "$(guard "sh -ec 'git push'")" deny "sh -ec"
  assert_eq "$(guard "bash -c 'cd ../wt && git push'")" allow "cd dans bash -c"
  assert_eq "$(guard "bash -c 'cd ../wt' && git push")" deny "cd de bash -c : sous-shell"
  assert_eq "$(guard 'env cd ../wt && git push')" deny "env cd : programme externe"
}

test_guard_ast_reads_git_global_options() {
  wt_repo
  assert_eq "$(guard 'git -C .. -C wt push')" allow "-C relatif au -C précédent"
  assert_eq "$(guard 'git -p --no-pager --bare push origin main')" deny "options sans valeur"
  assert_eq "$(guard 'git --exec-path push origin main')" deny "--exec-path sans valeur"
  assert_eq "$(guard 'git -c push.default=nothing push')" allow "-c push.default=nothing"
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'git -C "$X" switch main && git push')" deny "switch dans un dossier inconnu : tout dépôt"
  assert_eq "$(guard 'git --git-dir=../work/.git push')" deny "--git-dir="
  assert_eq "$(guard 'git --git-dir ../work/.git push')" deny "--git-dir et sa valeur, vers main"
  assert_eq "$(guard 'GIT_DIR=../work/.git git push')" deny "GIT_DIR en préfixe"
  assert_eq "$(guard 'env GIT_DIR=../work/.git git push')" deny "GIT_DIR par env"
}

test_guard_ast_reads_push_options_and_refspecs() {
  make_repo
  git -C "$GUARD_REPO" switch -q feat/x
  assert_eq "$(guard 'git push --repo x origin main')" deny "--repo et sa valeur"
  assert_eq "$(guard 'git push --repo x origin feat/x')" allow "--repo vers une branche"
  assert_eq "$(guard 'git push --repo x main')" allow "--repo : sa valeur n'est pas le dépôt positionnel"
  assert_eq "$(guard 'git push origin main:')" deny "main: pousse main"
  assert_eq "$(guard 'git push -- origin "$B"')" deny "refspec calculée après --"
  assert_eq "$(guard 'git push --receive-pack x origin feat/x')" allow "--receive-pack et sa valeur"
  assert_eq "$(guard 'git push --exec x origin feat/x')" allow "--exec et sa valeur"
  assert_eq "$(guard 'git push --push-option=ci.skip origin main')" deny "--opt=val"
  assert_eq "$(guard 'git push -- origin main')" deny "-- termine les options"
  assert_eq "$(guard 'git push -- origin --mirror')" allow "--mirror après -- : une refspec"
  assert_eq "$(guard 'git push origin :main')" deny ":main"
  assert_eq "$(guard 'git push origin :')" deny ": branches communes"
  assert_eq "$(guard "git push origin '*:*'")" deny "*:*"
  assert_eq "$(guard "git push origin 'refs/heads/*:refs/heads/*'")" deny "glob de refs"
  assert_eq "$(guard 'git push origin feat/x:heads/main')" deny "heads/main"
  assert_eq "$(guard 'git push origin @')" allow "@ depuis une branche"
  git -C "$GUARD_REPO" switch -q main
  assert_eq "$(guard 'git push origin @')" deny "@ depuis main"
  assert_eq "$(guard 'git push -fd origin HEAD')" deny "-d HEAD depuis main : supprime main"
  assert_eq "$(guard 'git push -oci.skip origin feat/x')" allow "-o collé"
}

test_guard_ast_reads_switch_and_checkout() {
  wt_repo
  assert_eq "$(guard 'git switch -cfeat/y && git push')" allow "-c collé"
  assert_eq "$(guard 'git switch --create=feat/y && git push')" allow "--create="
  assert_eq "$(guard 'git checkout -- README.md && git push')" deny "checkout -- depuis main : main"
}

# Un état ne retient la branche prise que d'un dépôt : un switch dans un second rend la branche inconnue.
test_guard_ast_switch_in_second_repo() {
  wt_repo
  git init -q -b main "$SANDBOX/B"
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'git switch main && git -C ../B switch -c y && git push')" deny "switch dans B après main dans wt"
  assert_eq "$(guard 'git switch -c a && git switch -c b && git push')" allow "deux switch dans le même dépôt"
  assert_eq "$(guard 'git -C ../B switch -c y && git -C ../B push')" allow "un seul dépôt basculé"
}

# Switch dans un dépôt inconnu : la branche créée ne vaut pas pour les autres dépôts.
test_guard_ast_switch_in_unknown_repo() {
  make_repo
  assert_eq "$(guard 'git -C "$X" switch -c b && git push origin HEAD')" deny "-C calculé"
  assert_eq "$(guard 'git -C "$X" switch -c b && git push')" deny "-C calculé, sans refspec"
  assert_eq "$(guard "cd \"\$X\" && git switch -c b && cd '$GUARD_REPO' && git push")" deny "cd calculé puis retour sur main"
}

test_guard_ast_reads_cd_forms() {
  wt_repo
  assert_eq "$(guard 'cd -P -- ../wt && git push')" allow "cd -P --"
  assert_eq "$(guard 'cd && git push')" allow "cd seul : \$HOME, hors dépôt"
  GUARD_REPO="$SANDBOX/wt"
  mkdir "$SANDBOX/wt/-"
  assert_eq "$(guard 'cd - && git push')" deny "cd - : inconnu"
  assert_eq "$(guard 'popd && git push')" deny "popd : inconnu"
  assert_eq "$(guard 'cd ../nope && git push')" deny "dossier absent : inconnu"
}

test_guard_ast_reads_push_default() {
  wt_repo
  GUARD_REPO="$SANDBOX/wt"
  git -C "$GUARD_REPO" config push.default matching
  assert_eq "$(guard 'git push')" deny "matching"
  git -C "$GUARD_REPO" config push.default nothing
  assert_eq "$(guard 'git push')" allow "nothing"
  git -C "$GUARD_REPO" config push.default upstream
  git -C "$GUARD_REPO" config branch.feat/x.merge refs/heads/feat/x
  assert_eq "$(guard 'git push')" allow "upstream d'une branche"
  assert_eq "$(guard 'git switch -c y origin/main && git push')" deny "upstream de la branche prise inconnu"
  git -C "$GUARD_REPO" config branch.feat/x.merge refs/heads/main
  assert_eq "$(guard 'git push')" deny "upstream main"
}

# Limites assumées, une par ligne « shortcut: » en tête du hook : ces appels sont mal jugés.
test_guard_ast_shows_shortcuts() {
  wt_repo
  git -C "$GUARD_REPO" config alias.p push
  assert_eq "$(guard 'git p origin main')" allow "alias git non lu"
  assert_eq "$(guard "eval 'git push'")" allow "eval non lu"
  assert_eq "$(guard 'exec git push')" allow "exec non lu"
  assert_eq "$(guard 'echo main | xargs git push origin')" allow "xargs non lu"
  assert_eq "$(guard $'bash <<\'EOF\'\ngit push\nEOF')" allow "heredoc donné à un shell non lu"
  assert_eq "$(guard "bash -o pipefail -c 'git push'")" allow "bash -o non lu"
  assert_eq "$(guard '! cd ../wt && git push')" allow "! cd lu comme cd"
  assert_eq "$(guard 'command -v git push')" deny "command -v lu comme command : refus de trop"
  assert_eq "$(guard "trap 'git push origin main' EXIT")" allow "trap non lu"
  assert_eq "$(guard 'watch git push origin main')" allow "watch non lu"
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'export GIT_DIR=../work/.git && git push')" allow "export GIT_DIR non suivi"
  assert_eq "$(guard 'git push --mir origin')" allow "option abrégée non lue"
  assert_eq "$(guard 'git --config-env a.b=X push origin main')" allow "option globale rare : sa valeur prise pour la sous-commande"
  assert_eq "$(guard 'env -C ../work git push')" allow "env -C non suivi"
  assert_eq "$(guard 'git branch -m main && git push')" allow "branch -m non suivi"
  assert_eq "$(guard 'for b in 1 2; do git push; cd ../work; done')" allow "boucle jugée en un tour"
  git -C "$GUARD_REPO" config remote.origin.push refs/heads/feat/x:refs/heads/main
  assert_eq "$(guard 'git push')" allow "remote.*.push ignoré"
  git -C "$GUARD_REPO" config --unset remote.origin.push
  # Refus de trop.
  assert_eq "$(guard 'git push -u origin "$(git branch --show-current)"')" deny "\$(git branch --show-current) : mot inconnu"
  assert_eq "$(guard 'git checkout -- README.md && git push')" deny "checkout -- <fichier> : branche inconnue"
  assert_eq "$(guard 'pushd -n ../work && git push')" deny "pushd -n lu comme pushd"
  git init -q -b main "$SANDBOX/B"
  assert_eq "$(guard 'git -C ../B switch -c y && git switch -c z && git push')" deny "switch dans un second dépôt : branche inconnue"
  assert_eq "$(guard 'git -C "" push')" deny "-C vide : dossier inconnu"
}

# Sans shfmt (ou commande illisible), refus de tout appel qui cite git et push.
test_guard_ast_fails_closed_without_shfmt() {
  make_repo
  local bin="$SANDBOX/bin" t out
  mkdir -p "$bin"
  for t in cat jq git; do ln -s "$(command -v "$t")" "$bin/$t"; done
  out="$(jq -nc --arg d "$GUARD_REPO" '{cwd:$d,tool_input:{command:"git push origin feat/x"}}' | PATH="$bin" "$BASH" "$REPO/global/main-guard-hook.sh")"
  assert_eq "$(jq -r .hookSpecificOutput.permissionDecision <<<"$out")" deny "push sans shfmt"
  assert_contains "$out" "claude-config install"
  out="$(jq -nc --arg d "$GUARD_REPO" '{cwd:$d,tool_input:{command:"git status"}}' | PATH="$bin" "$BASH" "$REPO/global/main-guard-hook.sh")"
  assert_eq "$out" "" "autre commande sans shfmt"
  assert_eq "$(guard 'git push origin feat/x (')" deny "commande illisible qui cite push"
  assert_eq "$(guard 'ls (')" allow "commande illisible sans push"
}

# Un plantage pendant le jugement (ici une pile vidée) refuse un push au lieu de sortir en code 1.
test_guard_ast_fails_closed_on_crash() {
  make_repo
  local bin="$SANDBOX/bin"
  mkdir -p "$bin"
  # Faux jq : pour le programme du hook (--arg home), un programme qui vide la pile.
  printf '#!/usr/bin/env bash\nfor a; do [[ "$a" == home ]] && { printf "drop2\\0drop2\\0\\0\\0"; exit 0; }; done\nexec %q "$@"\n' \
    "$(command -v jq)" > "$bin/jq"
  chmod +x "$bin/jq"
  assert_eq "$(PATH="$bin:$PATH" guard 'git push origin feat/x')" deny "plantage avec push"
  assert_eq "$(PATH="$bin:$PATH" guard 'ls')" "exit 1" "plantage sans push : code d'erreur gardé"
}

# shfmt < 3.14 écrit BinaryCmd.Op en entier : refus, sans lire && comme un pipe.
test_guard_ast_fails_closed_on_old_shfmt() {
  wt_repo
  local bin="$SANDBOX/bin"
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\n%q "$@" | jq -c %q\n' "$(command -v shfmt)" \
    'walk(if type == "object" and .Type == "BinaryCmd" then .Op = 10 else . end)' > "$bin/shfmt"
  chmod +x "$bin/shfmt"
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(PATH="$bin:$PATH" guard 'cd ../work && git push')" deny "Op entier : refus"
  assert_eq "$(PATH="$bin:$PATH" guard 'cd ../work && ls')" allow "Op entier sans push"
}

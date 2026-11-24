# shellcheck shell=bash
# shellcheck disable=SC2154

# Lignes de transcript JSONL.
t_prompt() { jq -nc --arg t "$1" '{type:"user",origin:{kind:"human"},message:{role:"user",content:$t}}'; }
t_humanizer() { jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"humanizer:humanizer"}}]}}'; }
t_tool_result() { jq -nc '{type:"user",message:{content:[{type:"tool_result",content:"ok"}]}}'; }
t_meta() { jq -nc '{type:"user",isMeta:true,message:{content:[{type:"text",text:"Base directory for this skill"}]}}'; }
t_notification() { jq -nc '{type:"user",origin:{kind:"task-notification"},message:{content:"<task-notification>"}}'; }
t_compact() { jq -nc '{type:"user",isCompactSummary:true,message:{content:"This session is being continued"}}'; }

# Écrit les lignes données (sorties de t_*) dans le transcript du bac à sable.
transcript() { printf '%s\n' "$@" >"$SANDBOX/t.jsonl"; }

# run_humanizer <commande> : sortie du hook, transcript du bac à sable.
run_humanizer() {
  local json
  json="$(jq -nc --arg c "$1" --arg t "$SANDBOX/t.jsonl" \
    '{tool_name:"Bash",transcript_path:$t,tool_input:{command:$c}}')"
  bash "$REPO/global/humanizer-hook.sh" <<<"$json"
}

# Silence = sortie vide : jq n'imprime rien sur une entrée vide, d'où le repli sur {}.
decision() {
  local out
  out="$(run_humanizer "$1")"
  jq -r '.hookSpecificOutput.permissionDecision // "silence"' <<<"${out:-{\}}"
}

test_humanizer_denies_pr_create_without_passage() {
  transcript "$(t_prompt '/pr push')"
  local out
  out="$(run_humanizer 'gh pr create --title "x" --body-file /tmp/b.md')"
  assert_eq "$(jq -r .hookSpecificOutput.permissionDecision <<<"$out")" "deny" "décision"
  local reason
  reason="$(jq -r .hookSpecificOutput.permissionDecisionReason <<<"$out")"
  assert_contains "$reason" "humanizer:humanizer"
  assert_contains "$reason" "# humanizer: sans objet"
  assert_contains "$reason" "# humanizer: déjà relu"
  assert_eq "$(jq -r '.hookSpecificOutput.updatedInput // "absent"' <<<"$out")" "absent" "pas de réécriture"
}

test_humanizer_allows_after_passage() {
  transcript "$(t_prompt '/pr push')" "$(t_humanizer)"
  assert_eq "$(decision 'gh pr create --body-file /tmp/b.md')" "silence" "create"
  assert_eq "$(decision 'git push --force-with-lease=b:abc origin b')" "silence" "squash"
}

test_humanizer_passage_before_last_prompt_denied() {
  transcript "$(t_prompt a)" "$(t_humanizer)" "$(t_prompt b)"
  assert_eq "$(decision 'gh pr create --body-file f')" "deny" "passage antérieur au message"
}

test_humanizer_non_prompt_entries_are_not_a_bound() {
  transcript "$(t_prompt a)" "$(t_tool_result)" "$(t_meta)" "$(t_humanizer)" "$(t_tool_result)" "$(t_meta)" \
    "$(t_notification)" "$(t_compact)"
  assert_eq "$(decision 'gh pr create --body-file f')" "silence" "seul un message tapé borne"
}

test_humanizer_sidechain_passage_ignored() {
  transcript "$(t_prompt a)" "$(t_humanizer | jq -c '.isSidechain = true')"
  assert_eq "$(decision 'gh pr create --body-file f')" "deny" "passage d'un sous-agent"
}

test_humanizer_pr_edit_body_or_title_only() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'rtk gh pr edit 12 --body-file f')" "deny" "--body-file"
  assert_eq "$(decision 'gh pr edit 12 --body "x"')" "deny" "--body"
  assert_eq "$(decision 'gh pr edit 12 -t "Titre"')" "deny" "-t"
  assert_eq "$(decision 'gh pr edit 12 --title "Titre"')" "deny" "--title"
  assert_eq "$(decision 'gh pr edit 12 --add-reviewer bob')" "silence" "--add-reviewer"
}

test_humanizer_denies_review_replies() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'gh pr comment 12 --body-file f')" "deny" "comment"
  assert_eq "$(decision 'gh api repos/o/r/pulls/12/comments/34/replies -F body=@f')" "deny" "replies"
  assert_eq "$(decision 'gh api repos/o/r/pulls/12/reviews --input f')" "deny" "reviews --input"
  assert_eq "$(decision 'gh api -X POST repos/o/r/pulls/12/reviews -f event=COMMENT')" "deny" "reviews -X POST"
  assert_eq "$(decision 'gh api -X POST repos/o/r/pulls/12/reviews')" "deny" "reviews -X POST sans champ"
}

test_humanizer_denies_pr_review_body() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'gh pr review 12 --comment -b "x"')" "deny" "-b"
  assert_eq "$(decision 'gh pr review 12 --approve --body-file f')" "deny" "--body-file"
  assert_eq "$(decision 'gh pr review 12 --approve')" "silence" "sans corps"
}

test_humanizer_denies_force_push_and_merge() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'git push --force-with-lease=b:abc origin b')" "deny" "push forcé"
  assert_eq "$(decision 'git -C ../wt push --force-with-lease=b:abc origin b')" "deny" "git -C"
  assert_eq "$(decision 'gh pr merge 12 --rebase')" "deny" "merge"
  assert_eq "$(decision 'gh api -X PUT repos/o/r/pulls/12/merge-async -f merge_method=rebase')" "deny" "merge-async"
  assert_eq "$(decision 'gh api -X PUT repos/o/r/pulls/12/merge')" "deny" "merge synchrone"
}

test_humanizer_silent_on_non_publication() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'git push origin feat/x')" "silence" "push simple"
  assert_eq "$(decision 'git commit -m wip')" "silence" "commit"
  assert_eq "$(decision 'gh pr view 12')" "silence" "view"
  assert_eq "$(decision 'gh api repos/o/r/pulls/12/comments')" "silence" "lecture comments"
  assert_eq "$(decision 'gh api repos/o/r/pulls/12/merge')" "silence" "lecture merge"
  assert_eq "$(decision 'gh api repos/o/r/pulls/12/reviews --paginate')" "silence" "lecture reviews"
  assert_eq "$(decision "gh api graphql -f query='{ reviewThreads }'")" "silence" "graphql"
  assert_eq "$(decision 'gh api repos/o/r/issues/12/comments --paginate')" "silence" "lecture issues/comments"
  assert_eq "$(decision 'gh pr close 12')" "silence" "close sans commentaire"
  assert_eq "$(decision 'gh pr close 12 -d')" "silence" "close -d"
  assert_eq "$(decision "gh api repos/o/r/pulls/12/comments --paginate --jq '.[].id' | cut -f1")" "silence" "lecture | cut -f"
  assert_eq "$(decision "gh api repos/o/r/issues/12/comments --paginate --jq '.[].body' | grep -F x")" "silence" "lecture | grep -F"
}

test_humanizer_denies_pr_close_comment() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'gh pr close 12 --comment "x"')" "deny" "--comment"
  assert_eq "$(decision 'gh pr close 12 -c "x"')" "deny" "-c"
}

test_humanizer_denies_issue_comment() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'gh issue comment 167 --body-file f')" "deny" "issue comment"
  assert_eq "$(decision 'rtk gh issue close 167 --comment "x"')" "deny" "issue close --comment"
  assert_eq "$(decision 'gh issue close 167 -c "x"')" "deny" "issue close -c"
  assert_eq "$(decision 'gh issue close 167 -r completed')" "silence" "issue close sans commentaire"
  assert_eq "$(decision 'gh issue view 167 --comments')" "silence" "issue view --comments"
}

test_humanizer_denies_issue_create_edit_with_body() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'gh issue create --title "x" --body-file f')" "deny" "create --body-file"
  assert_eq "$(decision 'rtk gh issue create -t x --body "y"')" "deny" "create --body"
  assert_eq "$(decision 'gh issue create -t x -F f')" "deny" "create -F"
  assert_eq "$(decision 'gh issue create -t x -b "y"')" "deny" "create -b"
  assert_eq "$(decision 'gh issue edit 172 --body-file f')" "deny" "edit --body-file"
  assert_eq "$(decision 'gh issue edit 172 -b "y"')" "deny" "edit -b"
  assert_eq "$(decision 'gh issue edit 172 --add-label bug')" "silence" "edit sans corps"
  assert_eq "$(decision 'gh issue create -t x -l bug')" "silence" "create sans corps"
  assert_eq "$(decision 'gh issue list --search "body"')" "silence" "list"
}

test_humanizer_denies_api_comments() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'gh api repos/o/r/pulls/12/comments -f body=x')" "deny" "pulls/N/comments"
  assert_eq "$(decision 'gh api repos/o/r/issues/12/comments -F body=@f')" "deny" "issues/N/comments"
  assert_eq "$(decision 'gh api -X PATCH repos/o/r/issues/comments/9 -F body=@f')" "deny" "PATCH issues/comments/id"
  # shellcheck disable=SC2016 # $ID est du texte de commande, pas à développer
  assert_eq "$(decision 'gh api -X PATCH "repos/o/r/issues/comments/$ID" -F body=@f')" "deny" "id en variable"
  assert_eq "$(decision 'gh api repos/o/r/pulls/12/comments?per_page=1 -f body=x')" "deny" "chaîne de requête"
}

test_humanizer_denies_glued_short_options() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'gh pr edit 12 -b"x"')" "deny" "edit -b collé"
  assert_eq "$(decision 'gh pr edit 12 -tTitre')" "deny" "edit -t collé"
  assert_eq "$(decision 'gh pr review 12 -cb "x"')" "deny" "review groupé"
  assert_eq "$(decision 'gh pr review 12 -Ff')" "deny" "review -F collé"
  assert_eq "$(decision 'gh pr close 12 -dc "x"')" "deny" "close groupé"
  assert_eq "$(decision 'gh api repos/o/r/pulls/12/comments -fbody=x')" "deny" "api -f collé"
  assert_eq "$(decision 'gh api -XPOST repos/o/r/pulls/12/reviews')" "deny" "api -X collé"
  assert_eq "$(decision 'gh pr review 12 -a')" "silence" "review -a sans corps"
}

test_humanizer_compound_call_denied() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'git add f && git commit -m x && git push --force-with-lease=b:s origin b')" "deny" "un point suffit"
}

test_humanizer_line_continuation_denied() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision $'gh pr edit 12 \\\n  --body-file f')" "deny" "option sur la ligne suivante"
}

test_humanizer_markers() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'gh pr create --body-file f # humanizer: sans objet')" "silence" "sans objet"
  assert_eq "$(decision 'git push --force-with-lease=b:s origin b # humanizer: sans objet')" "silence" "rebase"
  assert_eq "$(decision 'gh pr comment 12 --body-file f # humanizer: déjà relu')" "silence" "déjà relu"
  assert_eq "$(decision 'gh pr comment 12 --body-file f # humanizer: plus tard')" "deny" "marqueur inconnu"
}

test_humanizer_approved_text_needs_marker() {
  transcript "$(t_prompt a)" "$(t_humanizer)" "$(t_prompt ok)"
  assert_eq "$(decision 'gh pr comment 12 --body-file f # humanizer: déjà relu')" "silence" "approuvé, marqué"
  assert_eq "$(decision 'gh pr comment 12 --body-file f')" "deny" "approuvé, sans marqueur"
}

test_humanizer_marker_inside_script() {
  transcript "$(t_prompt a)"
  local script
  local head=$'bash ~/.claude/profile.sh require-token || exit 1\n'
  script=$'F=/tmp/pr-risk-3.md\nID=$(gh api "repos/o/r/issues/3/comments" --paginate \\\n  --jq ".[] | .id" | head -1)\nif [ -n "$ID" ]; then\n  gh api -X PATCH "repos/o/r/issues/comments/$ID" -F body=@"$F"\nelse\n  gh pr comment 3 -R o/r --body-file "$F"\nfi'
  assert_eq "$(decision "$head$script")" "deny" "script pr-risk sans marqueur"
  assert_eq "$(decision "$head"$'# humanizer: sans objet\n'"$script")" "silence" "marqueur en 2e ligne"
}

test_humanizer_fail_open() {
  local out code=0
  out="$(bash "$REPO/global/humanizer-hook.sh" <<<'pas du json')" || code=$?
  assert_eq "$out|$code" "|0" "entrée invalide"
  out="$(bash "$REPO/global/humanizer-hook.sh" <<<'{"tool_input":{"command":"gh pr create --body-file f"}}')" || code=$?
  assert_eq "$out|$code" "|0" "sans transcript_path"
  rm -f "$SANDBOX/t.jsonl"
  assert_eq "$(decision 'gh pr create --body-file f')" "silence" "transcript absent"
  transcript "$(t_prompt a)" 'ligne {cassée' "$(t_humanizer)"
  assert_eq "$(decision 'gh pr create --body-file f')" "silence" "ligne invalide sautée"
  transcript "$(t_prompt a)" '123' '"x"'
  assert_eq "$(decision 'gh pr create --body-file f')" "deny" "ligne non objet sautée, jugement tenu"
}

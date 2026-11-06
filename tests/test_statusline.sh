# shellcheck shell=bash
# shellcheck disable=SC2154,SC2153

# Faux gh : comptes connectés $GH_ACCOUNTS, compte actif $GH_ACTIVE, compte qui voit le dépôt $GH_SEES, comptes sans jeton $GH_MISSING.
make_gh_stub() {
  mkdir -p "$STUBS"
  cat > "$STUBS/gh" <<'STUB'
#!/usr/bin/env bash
printf 'GH_TOKEN=%s gh %s\n' "${GH_TOKEN:-}" "$*" >> "$CALLS_LOG"
case "$1 $2" in
  "auth status") for a in ${GH_ACCOUNTS:-}; do echo "  ✓ Logged in to github.com account $a (keyring)"; done ;;
  "auth token") [[ " ${GH_MISSING:-} " == *" $4 "* ]] && exit 1; echo "tok-$4" ;;
  "api graphql") printf '%s' "${GH_GRAPHQL:-}" ;;
  "api repos/"*) [[ "${GH_TOKEN:-tok-${GH_ACTIVE:-}}" == "tok-${GH_SEES:-}" ]] ;;  # sans jeton : compte actif
esac
STUB
  chmod +x "$STUBS/gh"
}

run_statusline() {  # <cwd> [propriétaire/dépôt]
  local repo=null
  [[ -n "${2:-}" ]] && repo=$(jq -nc --arg o "${2%/*}" --arg n "${2#*/}" '{owner: $o, name: $n}')
  make_gh_stub
  ln -sf "$REPO/global/statusline-command.sh" "$STUBS/statusline-command.sh"  # appelée comme ~/.claude : par un lien
  jq -nc --arg cwd "$1" --argjson repo "$repo" '{workspace: {current_dir: $cwd, repo: $repo}, pr: {number: 5}}' \
    | PATH="$STUBS:$PATH" XDG_CACHE_HOME="$SANDBOX/cache" GH_TOKEN="${INHERITED_GH_TOKEN:-}" bash "$STUBS/statusline-command.sh"
}

wait_for_call() {  # <motif> : vrai dès que le motif paraît dans $CALLS_LOG, 5 s au plus
  local _
  for _ in $(seq 50); do
    grep -q -- "$1" "$CALLS_LOG" 2>/dev/null && return 0
    sleep 0.1
  done
  return 1
}

pr_view_call() {  # appel d'arrière-plan qui porte le jeton retenu
  wait_for_call 'gh pr view 5' || fail "gh pr view jamais appelé"
  grep 'gh pr view 5' "$CALLS_LOG"
}

test_statusline_counts_threads_awaiting_account() {
  repo_with_origin "$SANDBOX/p" https://github.com/someone/x.git
  local f="$SANDBOX/cache/claude-statusline/threads-someone_x-5" _
  # attendus : alice en dernier (1), bob seul sur son fil (1), auteur supprimé (1) ; répondu par bob, résolu et bot : non
  GH_GRAPHQL='{"data":{"viewer":{"login":"bob"},"repository":{"pullRequest":{"reviewThreads":{"nodes":[
    {"isResolved":false,"all":{"totalCount":2},"last":{"nodes":[{"author":{"login":"alice"}}]}},
    {"isResolved":false,"all":{"totalCount":2},"last":{"nodes":[{"author":{"login":"bob"}}]}},
    {"isResolved":false,"all":{"totalCount":1},"last":{"nodes":[{"author":{"login":"bob"}}]}},
    {"isResolved":false,"all":{"totalCount":3},"last":{"nodes":[{"author":null}]}},
    {"isResolved":true,"all":{"totalCount":1},"last":{"nodes":[{"author":{"login":"alice"}}]}},
    {"isResolved":false,"all":{"totalCount":2},"first":{"nodes":[{"author":{"__typename":"Bot"}}]},"last":{"nodes":[{"author":{"login":"alice"}}]}}]}}}}}' \
    GH_ACCOUNTS=bob GH_SEES=bob run_statusline "$SANDBOX/p" someone/x >/dev/null
  for _ in $(seq 50); do [[ -s "$f" ]] && break; sleep 0.1; done
  assert_eq "$(cat "$f" 2>/dev/null)" "3" "fils en attente"
}

test_statusline_probe_picks_account_that_sees_repo() {
  repo_with_origin "$SANDBOX/p" https://github.com/someone/x.git
  GH_ACCOUNTS="alice bob" GH_SEES=bob run_statusline "$SANDBOX/p" someone/x >/dev/null
  assert_eq "$(cat "$SANDBOX/cache/claude-statusline/ghuser-someone_x")" "bob" "cache"
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-bob "
}

test_statusline_probe_skips_account_without_token() {
  repo_with_origin "$SANDBOX/p" https://github.com/someone/x.git
  GH_ACCOUNTS="alice bob" GH_MISSING=alice GH_ACTIVE=bob GH_SEES=bob run_statusline "$SANDBOX/p" someone/x >/dev/null
  assert_eq "$(cat "$SANDBOX/cache/claude-statusline/ghuser-someone_x")" "bob" "cache"
}

test_statusline_probe_skipped_with_fresh_cache() {
  repo_with_origin "$SANDBOX/p" https://github.com/someone/x.git
  mkdir -p "$SANDBOX/cache/claude-statusline"
  echo alice > "$SANDBOX/cache/claude-statusline/ghuser-someone_x"
  GH_ACCOUNTS="alice bob" GH_SEES=bob run_statusline "$SANDBOX/p" someone/x >/dev/null
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-alice "
  assert_not_contains "$(cat "$CALLS_LOG")" "gh api repos/"
}

test_statusline_missing_cwd_skips_background_calls() {
  local _
  run_statusline "$SANDBOX/supprime" >/dev/null
  for _ in $(seq 50); do  # le sous-processus de cached retire son verrou en sortant
    compgen -G "$SANDBOX/cache/claude-statusline/*.lock" >/dev/null || break
    sleep 0.1
  done
  assert_not_contains "$(cat "$CALLS_LOG" 2>/dev/null)" "gh pr view"
  if compgen -G "$SANDBOX/cache/claude-statusline/state-*" >/dev/null; then fail "cache écrit malgré le dossier absent"; fi
}

assert_no_probe() {
  local calls; calls=$(cat "$CALLS_LOG")
  assert_not_contains "$calls" "gh auth status"
  assert_not_contains "$calls" "gh api repos/"
}

test_statusline_uses_profile_account() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  GH_ACCOUNTS="alice Dahiorus" GH_SEES=alice run_statusline "$SANDBOX/p" Dahiorus/x >/dev/null
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-Dahiorus "
  assert_no_probe
  [[ ! -e "$SANDBOX/cache/claude-statusline/ghuser-Dahiorus_x" ]] || fail "cache ghuser écrit"

  : > "$CALLS_LOG"
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  GH_ACCOUNTS="alice brondon-ung" GH_SEES=alice run_statusline "$SANDBOX/v" softwarevidal/y >/dev/null
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-brondon-ung "
  assert_no_probe
  [[ ! -e "$SANDBOX/cache/claude-statusline/ghuser-softwarevidal_y" ]] || fail "cache ghuser écrit"
}

test_statusline_no_github_no_probe() {
  repo_with_origin "$SANDBOX/p" https://gitlab.com/Dahiorus/x.git
  GH_ACCOUNTS="alice" GH_SEES=alice run_statusline "$SANDBOX/p" >/dev/null
  assert_contains "$(pr_view_call)" "GH_TOKEN= "
  assert_no_probe
  assert_not_contains "$(cat "$CALLS_LOG")" "gh auth token"
}

test_statusline_inherited_token_still_probes() {
  repo_with_origin "$SANDBOX/p" https://github.com/someone/x.git
  INHERITED_GH_TOKEN=tok-alice GH_ACCOUNTS="alice bob" GH_SEES=bob run_statusline "$SANDBOX/p" someone/x >/dev/null
  assert_eq "$(cat "$SANDBOX/cache/claude-statusline/ghuser-someone_x")" "bob" "cache"
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-bob "
}

test_statusline_invalid_profile_account_falls_back() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  jq '.perso.account = "pas valide"' "$REPO/global/profiles.json" > "$SANDBOX/profiles.json"
  local out
  out=$(PROFILES_FILE="$SANDBOX/profiles.json" GH_ACCOUNTS="alice bob" GH_SEES=bob run_statusline "$SANDBOX/p" Dahiorus/x 2>&1)
  assert_not_contains "$out" "compte gh invalide"
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-bob "
}

test_statusline_profile_beats_fresh_cache() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  mkdir -p "$SANDBOX/cache/claude-statusline"
  echo alice > "$SANDBOX/cache/claude-statusline/ghuser-Dahiorus_x"
  GH_ACCOUNTS="alice Dahiorus" GH_SEES=alice run_statusline "$SANDBOX/p" Dahiorus/x >/dev/null
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-Dahiorus "
}

test_statusline_unlogged_profile_account_falls_back() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  GH_ACCOUNTS="alice bob" GH_SEES=bob GH_MISSING=Dahiorus run_statusline "$SANDBOX/p" Dahiorus/x >/dev/null
  assert_eq "$(cat "$SANDBOX/cache/claude-statusline/ghuser-Dahiorus_x")" "bob" "cache"
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-bob "
}

test_statusline_profile_without_workspace_repo() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  GH_ACCOUNTS="alice Dahiorus" run_statusline "$SANDBOX/p" >/dev/null
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-Dahiorus "
}

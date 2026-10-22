# shellcheck shell=bash
# shellcheck disable=SC2154

# Remplace le vrai script (gh, claude -p) par un stub qui journalise son appel et sort avec <code>.
stub_brief() {
  cat > "$REPO/scripts/morning_brief.py" <<STUB
#!/usr/bin/env bash
echo brief >> "\$CALLS_LOG"
echo "# Point du jour"
exit ${1:-0}
STUB
  make_stub notify-send
  touch "$CALLS_LOG"
}

# Lance le hook et attend la fin de la génération en arrière-plan. Le stub journalise son appel
# sous le verrou : dès que l'appel apparaît, flock attend vraiment la fin de la génération.
run_brief_hook() {
  local f before i
  f="$HOME/morning-brief/$(date +%F).md"
  before="$(grep -c '^brief$' "$CALLS_LOG" || true)"
  PATH="$STUBS:/usr/bin:/bin" bash "$REPO/global/morning-brief-hook.sh" </dev/null
  [[ -s "$f" && "$before" -gt 0 ]] && return 0
  for ((i = 0; i < 50; i++)); do
    (($(grep -c '^brief$' "$CALLS_LOG" || true) > before)) && break
    sleep 0.1
  done
  flock "$HOME/morning-brief/.lock" true
}

test_brief_hook_generates_today_once() {
  stub_brief
  run_brief_hook
  local f
  f="$HOME/morning-brief/$(date +%F).md"
  assert_eq "$(cat "$f")" "# Point du jour" "point du jour"
  assert_contains "$(cat "$CALLS_LOG")" "notify-send Point du matin prêt"
  run_brief_hook
  assert_eq "$(grep -c '^brief$' "$CALLS_LOG" || true)" 1 "une seule génération par jour"
}

test_brief_hook_retries_after_failure() {
  stub_brief 1
  run_brief_hook
  local f
  f="$HOME/morning-brief/$(date +%F).md"
  [[ ! -e "$f" && ! -e "$f.tmp" ]] || fail "aucun point ne doit rester après un échec"
  [[ -e "$f.log" ]] || fail "le journal d'erreur doit rester"
  assert_contains "$(cat "$CALLS_LOG")" "notify-send Point du matin en échec"
  stub_brief 0
  run_brief_hook
  assert_eq "$(cat "$f")" "# Point du jour" "nouvel essai"
}

test_brief_hook_prints_nothing() {
  stub_brief
  assert_eq "$(run_brief_hook)" "" "sortie du hook"
}

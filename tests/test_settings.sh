# shellcheck shell=bash
# shellcheck disable=SC2154

write_base() {
  printf '%s\n' "$1" > "$REPO/settings/base.json"
}

write_local() {
  printf '%s\n' "$1" > "$REPO/settings/local.json"
}

test_install_writes_base_settings() {
  write_base '{"model":"opus","env":{"A":"1"}}'
  local out
  out="$("$CLI" install --no-deps)"
  assert_has_line "$out" written settings.json
  assert_json_eq "$CLAUDE_HOME/settings.json" '{"model":"opus","env":{"A":"1"}}'
}

test_install_merges_local_settings() {
  write_base '{"model":"opus","env":{"A":"1"},"list":[1,2]}'
  write_local '{"model":"sonnet","env":{"B":"2"},"list":[3]}'
  "$CLI" install --no-deps >/dev/null
  assert_json_eq "$CLAUDE_HOME/settings.json" '{"model":"sonnet","env":{"A":"1","B":"2"},"list":[3]}'
}

test_install_settings_idempotent() {
  write_base '{"model":"opus"}'
  "$CLI" install --no-deps >/dev/null
  local out
  out="$("$CLI" install --no-deps)"
  assert_has_line "$out" ok settings.json
  assert_eq "$(count_backups "$CLAUDE_HOME")" 0 "nombre de sauvegardes"
}

test_install_backs_up_different_settings() {
  write_base '{"model":"opus"}'
  mkdir -p "$CLAUDE_HOME"
  printf '{"x":1}\n' > "$CLAUDE_HOME/settings.json"
  "$CLI" install --no-deps >/dev/null
  local bak
  bak="$(find "$CLAUDE_HOME" -maxdepth 1 -name 'settings.json.bak-*')"
  [[ -n "$bak" ]] || fail "sauvegarde de settings.json absente"
  assert_json_eq "$bak" '{"x":1}'
  assert_json_eq "$CLAUDE_HOME/settings.json" '{"model":"opus"}'
}

test_install_backs_up_invalid_settings() {
  write_base '{"model":"opus"}'
  mkdir -p "$CLAUDE_HOME"
  printf 'pas du json\n' > "$CLAUDE_HOME/settings.json"
  "$CLI" install --no-deps >/dev/null
  assert_eq "$(count_backups "$CLAUDE_HOME")" 1 "nombre de sauvegardes"
  assert_json_eq "$CLAUDE_HOME/settings.json" '{"model":"opus"}'
}

test_install_rejects_invalid_local() {
  write_base '{"model":"opus"}'
  write_local '{'
  local rc=0 out
  out="$("$CLI" install --no-deps 2>&1)" || rc=$?
  [[ "$rc" -ne 0 ]] || fail "install aurait dû échouer"
  assert_contains "$out" "local.json"
  [[ ! -e "$CLAUDE_HOME/settings.json" ]] || fail "settings.json ne doit pas être écrit"
  [[ ! -e "$CLAUDE_HOME/CLAUDE.md" ]] || fail "aucun symlink ne doit être créé"
}

test_status_ignores_key_order() {
  write_base '{"a":1,"b":{"c":2,"d":3}}'
  "$CLI" install --no-deps >/dev/null
  printf '{"b":{"d":3,"c":2},"a":1}\n' > "$CLAUDE_HOME/settings.json"
  "$CLI" status >/dev/null || fail "un simple réordonnancement ne doit pas être un écart"
}

test_status_detects_settings_drift() {
  write_base '{"model":"opus"}'
  "$CLI" install --no-deps >/dev/null
  printf '{"model":"haiku"}\n' > "$CLAUDE_HOME/settings.json"
  local rc=0 out
  out="$("$CLI" status)" || rc=$?
  assert_eq "$rc" 1 "code de sortie"
  assert_has_line "$out" drift settings.json
  assert_contains "$out" "haiku"
}

test_capture_without_local() {
  write_base '{"model":"opus"}'
  "$CLI" install --no-deps >/dev/null
  printf '{"model":"opus","theme":"light"}\n' > "$CLAUDE_HOME/settings.json"
  "$CLI" capture >/dev/null
  assert_json_eq "$REPO/settings/base.json" '{"model":"opus","theme":"light"}'
  "$CLI" status >/dev/null || fail "status devrait être propre après capture"
}

test_capture_keeps_local_overrides_out_of_base() {
  write_base '{"model":"opus","env":{"A":"1"}}'
  write_local '{"model":"sonnet","env":{"B":"2"},"onlyLocal":{"k":true}}'
  "$CLI" install --no-deps >/dev/null
  jq '.theme = "light"' "$CLAUDE_HOME/settings.json" > "$SANDBOX/s.json"
  mv "$SANDBOX/s.json" "$CLAUDE_HOME/settings.json"
  "$CLI" capture >/dev/null
  assert_json_eq "$REPO/settings/base.json" '{"model":"opus","env":{"A":"1"},"theme":"light"}'
}

test_capture_rejects_invalid_settings() {
  write_base '{"model":"opus"}'
  "$CLI" install --no-deps >/dev/null
  printf 'oops\n' > "$CLAUDE_HOME/settings.json"
  local rc=0
  "$CLI" capture >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] || fail "capture aurait dû échouer"
  assert_json_eq "$REPO/settings/base.json" '{"model":"opus"}'
}

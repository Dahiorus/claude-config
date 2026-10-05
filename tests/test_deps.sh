# shellcheck shell=bash
# shellcheck disable=SC2154

# Faux CLI claude : journalise ses appels et renvoie les listes JSON fournies.
stub_claude() {
  mkdir -p "$STUBS"
  printf '%s\n' "$1" > "$SANDBOX/marketplaces.json"
  printf '%s\n' "$2" > "$SANDBOX/plugins.json"
  cat > "$STUBS/claude" <<'STUB'
#!/usr/bin/env bash
printf 'claude %s\n' "$*" >> "$CALLS_LOG"
case "$*" in
  "plugin marketplace list --json") cat "$STUB_DIR/marketplaces.json" ;;
  "plugin list --json") cat "$STUB_DIR/plugins.json" ;;
esac
STUB
  chmod +x "$STUBS/claude"
  export STUB_DIR="$SANDBOX"
}

# PATH réduit : les stubs d'abord, puis seulement les outils système.
run_install() {
  PATH="$STUBS:/usr/bin:/bin" "$CLI" install "$@"
}

calls() {
  cat "$CALLS_LOG" 2>/dev/null || true
}

empty_settings() {
  printf '{}\n' > "$REPO/settings/base.json"
}

fake_angular_skill() {
  mkdir -p "$CLAUDE_HOME/skills/angular-developer"
}

test_deps_nothing_to_install() {
  empty_settings
  make_stub rtk
  make_stub plannotator
  fake_angular_skill
  stub_claude '[]' '[]'
  local out
  out="$(run_install)"
  assert_has_line "$out" ok rtk
  assert_has_line "$out" ok plannotator
  assert_has_line "$out" ok "skill angular-developer"
  assert_not_contains "$(calls)" "install"
  assert_not_contains "$(calls)" "add"
}

test_deps_rtk_via_brew() {
  empty_settings
  make_stub brew
  make_stub plannotator
  fake_angular_skill
  stub_claude '[]' '[]'
  local out
  out="$(run_install)"
  assert_contains "$(calls)" "brew install rtk"
  assert_has_line "$out" installed "rtk (brew)"
}

test_deps_rtk_via_script_without_brew() {
  empty_settings
  make_stub curl
  make_stub plannotator
  fake_angular_skill
  stub_claude '[]' '[]'
  local out
  out="$(run_install)"
  assert_contains "$(calls)" "curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh"
  assert_has_line "$out" installed "rtk (script officiel)"
}

test_deps_failure_is_only_a_warning() {
  empty_settings
  make_stub curl 22
  make_stub plannotator
  fake_angular_skill
  stub_claude '[]' '[]'
  local rc=0 out
  out="$(run_install 2>&1)" || rc=$?
  assert_eq "$rc" 0 "code de sortie"
  assert_contains "$out" "warn"
  assert_contains "$out" "rtk"
}

test_deps_plannotator_via_script() {
  empty_settings
  make_stub rtk
  make_stub curl
  fake_angular_skill
  stub_claude '[]' '[]'
  local out
  out="$(run_install)"
  assert_contains "$(calls)" "curl -fsSL https://plannotator.ai/install.sh"
  assert_has_line "$out" installed plannotator
}

test_deps_angular_developer_via_npx() {
  empty_settings
  make_stub rtk
  make_stub plannotator
  make_stub npx
  stub_claude '[]' '[]'
  local out
  out="$(run_install)"
  assert_contains "$(calls)" "npx -y skills add affaan-m/ecc --skill angular-developer -g -a claude-code -y"
  assert_has_line "$out" installed "skill angular-developer"
}

test_deps_installs_missing_plugins() {
  printf '%s\n' '{"extraKnownMarketplaces":{"plannotator":{"source":{"source":"github","repo":"backnotprop/plannotator"}}},"enabledPlugins":{"a@m":true,"b@m":false,"plannotator@plannotator":true}}' \
    > "$REPO/settings/base.json"
  make_stub rtk
  make_stub plannotator
  fake_angular_skill
  stub_claude '[{"name":"m"}]' '[{"id":"a@m"}]'
  local out c
  out="$(run_install)"
  c="$(calls)"
  assert_contains "$c" "claude plugin marketplace add backnotprop/plannotator"
  assert_contains "$c" "claude plugin install plannotator@plannotator --scope user"
  assert_not_contains "$c" "install a@m"
  assert_not_contains "$c" "install b@m"
  assert_has_line "$out" ok "plugin a@m"
  assert_has_line "$out" installed "plugin plannotator@plannotator"
}

test_deps_skipped_in_dry_run() {
  empty_settings
  make_stub curl
  stub_claude '[]' '[]'
  run_install --dry-run >/dev/null
  assert_eq "$(calls)" "" "appels externes"
}

test_deps_skipped_with_no_deps() {
  empty_settings
  make_stub curl
  stub_claude '[]' '[]'
  run_install --no-deps >/dev/null
  assert_eq "$(calls)" "" "appels externes"
}

# Un CLI qui lit stdin ne doit pas consommer la liste des plugins restants.
test_deps_plugins_survive_stdin_reading_cli() {
  printf '%s\n' '{"enabledPlugins":{"a@m":true,"b@m":true,"c@m":true}}' > "$REPO/settings/base.json"
  make_stub rtk
  make_stub plannotator
  fake_angular_skill
  stub_claude '[]' '[]'
  printf 'cat >/dev/null\n' >> "$STUBS/claude"
  run_install >/dev/null
  local c
  c="$(calls)"
  assert_contains "$c" "claude plugin install a@m"
  assert_contains "$c" "claude plugin install b@m"
  assert_contains "$c" "claude plugin install c@m"
}

test_deps_installer_timeout_is_only_a_warning() {
  empty_settings
  make_stub rtk
  make_stub plannotator
  mkdir -p "$STUBS"
  printf '#!/usr/bin/env bash\nsleep 30\n' > "$STUBS/npx"
  chmod +x "$STUBS/npx"
  stub_claude '[]' '[]'
  local out start
  start=$SECONDS
  out="$(DEPS_TIMEOUT=1 run_install)"
  [[ $((SECONDS - start)) -lt 10 ]] || fail "install aurait dû abandonner npx après 1 s"
  assert_contains "$out" "warn"
  assert_contains "$out" "angular-developer"
}

test_deps_curl_has_timeouts() {
  empty_settings
  make_stub curl
  fake_angular_skill
  stub_claude '[]' '[]'
  run_install >/dev/null
  assert_contains "$(calls)" "--max-time"
}

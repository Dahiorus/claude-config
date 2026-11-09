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

# Faux shfmt en $1 : son arbre de « a && b » porte l'Op $2, "&&" (shfmt 3.14 ou plus) par défaut, 10 pour un ancien.
write_shfmt() {
  mkdir -p "${1%/*}"
  printf '#!/usr/bin/env bash\ncat >/dev/null\necho %q\n' "{\"Stmts\":[{\"Cmd\":{\"Op\":${2:-\"&&\"}}}]}" > "$1"
  chmod +x "$1"
}

stub_shfmt() {
  write_shfmt "$STUBS/shfmt" "$@"
}

calls() {
  cat "$CALLS_LOG" 2>/dev/null || true
}

empty_settings() {
  printf '{}\n' > "$REPO/settings/base.json"
  printf '{}\n' > "$REPO/global/profiles.json"
}

fake_angular_skill() {
  mkdir -p "$CLAUDE_HOME/skills/angular-developer"
}

test_deps_nothing_to_install() {
  stub_shfmt
  empty_settings
  make_stub rtk
  make_stub build-brief
  make_stub plannotator
  fake_angular_skill
  stub_claude '[]' '[]'
  local out
  out="$(run_install)"
  assert_has_line "$out" ok shfmt
  assert_has_line "$out" ok rtk
  assert_has_line "$out" ok build-brief
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
  assert_contains "$out" "échec du téléchargement de shfmt"
}

test_deps_shfmt_partial_download_is_removed() {
  empty_settings
  make_stub rtk
  make_stub plannotator
  mkdir -p "$STUBS"
  # Faux curl : écrit le fichier demandé par -o puis échoue, comme un téléchargement coupé.
  # shellcheck disable=SC2016 # code du stub, développé à son exécution
  printf '%s\n' '#!/usr/bin/env bash' 'for a; do [[ "${o:-}" == 1 ]] && : > "$a"; o=; [[ "$a" == -o ]] && o=1; done' \
    'exit 22' > "$STUBS/curl"
  chmod +x "$STUBS/curl"
  fake_angular_skill
  stub_claude '[]' '[]'
  local out
  out="$(run_install 2>&1)"
  assert_contains "$out" "échec du téléchargement de shfmt"
  [[ ! -e "$HOME/.local/bin/shfmt" ]] || fail "shfmt à moitié téléchargé laissé dans ~/.local/bin"
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
  stub_shfmt
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
  stub_shfmt
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
  stub_shfmt
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
  stub_shfmt
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

test_deps_build_brief_via_brew() {
  empty_settings
  make_stub rtk
  make_stub brew
  make_stub plannotator
  fake_angular_skill
  stub_claude '[]' '[]'
  local out
  out="$(run_install)"
  assert_contains "$(calls)" "brew install static-var/tap/build-brief"
  assert_has_line "$out" installed "build-brief (brew)"
}

test_deps_build_brief_untrusted_tap_is_only_a_warning() {
  empty_settings
  make_stub rtk
  make_stub brew 1
  make_stub plannotator
  fake_angular_skill
  stub_claude '[]' '[]'
  local rc=0 out
  out="$(run_install 2>&1)" || rc=$?
  assert_eq "$rc" 0 "code de sortie"
  assert_contains "$out" "brew trust --formula static-var/tap/build-brief"
  assert_contains "$out" "échec de brew install shfmt"
}

test_deps_build_brief_without_brew() {
  stub_shfmt
  empty_settings
  make_stub rtk
  make_stub plannotator
  fake_angular_skill
  stub_claude '[]' '[]'
  local out
  out="$(run_install 2>&1)"
  assert_contains "$out" "brew absent : build-brief non installé"
  assert_not_contains "$(calls)" "build-brief"
}

test_deps_installs_profile_plugins() {
  stub_shfmt
  printf '%s\n' '{"enabledPlugins":{"a@m":true,"s@m":false}}' > "$REPO/settings/base.json"
  printf '%s\n' '{"vidal":{"owners":[],"account":"x","enabledPlugins":{"s@m":true,"a@m":true},"skillOverrides":{}}}' \
    > "$REPO/global/profiles.json"
  make_stub rtk; make_stub plannotator; fake_angular_skill
  stub_claude '[]' '[]'
  run_install >/dev/null
  local c; c="$(calls)"
  assert_contains "$c" "claude plugin install s@m --scope user"
  assert_eq "$(grep -c 'plugin install a@m' <<<"$c")" "1" "a@m une seule fois"
}

# Faux brew : journalise l'appel ; « brew install shfmt » pose un shfmt récent dans les stubs.
stub_brew_shfmt() {
  write_shfmt "$SANDBOX/shfmt-new"
  # shellcheck disable=SC2016 # code du stub, développé à son exécution
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "brew $*" >> "$CALLS_LOG"' \
    '[[ "$*" == "install shfmt" ]] || exit 0' \
    "cp $(printf %q "$SANDBOX/shfmt-new") $(printf %q "$STUBS/shfmt")" > "$STUBS/brew"
  chmod +x "$STUBS/brew"
}

test_deps_shfmt_via_brew() {
  empty_settings
  make_stub rtk
  stub_brew_shfmt
  make_stub plannotator
  fake_angular_skill
  stub_claude '[]' '[]'
  local out
  out="$(run_install)"
  assert_contains "$(calls)" "brew install shfmt"
  assert_has_line "$out" installed "shfmt (brew)"
}

# Un shfmt d'avant 3.14 (apt d'Ubuntu 24.04 : 3.8) écrit BinaryCmd.Op en entier : il est remplacé.
test_deps_shfmt_too_old_is_replaced() {
  empty_settings
  make_stub rtk
  stub_shfmt 10
  stub_brew_shfmt
  make_stub plannotator
  fake_angular_skill
  stub_claude '[]' '[]'
  local out
  out="$(run_install)"
  assert_contains "$(calls)" "brew install shfmt"
  assert_has_line "$out" installed "shfmt (brew)"
}

test_deps_shfmt_still_too_old_is_a_warning() {
  empty_settings
  make_stub rtk
  stub_shfmt 10
  # Faux brew : réussit tout, et donne son préfixe.
  # shellcheck disable=SC2016 # code du stub, développé à son exécution
  printf '#!/usr/bin/env bash\n[[ "$1" == --prefix ]] && echo /opt/brew\nexit 0\n' > "$STUBS/brew"
  chmod +x "$STUBS/brew"
  make_stub plannotator
  fake_angular_skill
  stub_claude '[]' '[]'
  local out
  out="$(run_install 2>&1)"
  assert_contains "$out" "le shfmt du PATH ($STUBS/shfmt) n'écrit pas l'arbre attendu"
  assert_contains "$out" "mettre /opt/brew/bin en tête du PATH"
}

test_deps_shfmt_release_without_brew() {
  empty_settings
  make_stub rtk
  make_stub plannotator
  mkdir -p "$STUBS"
  # Faux curl : journalise l'appel et copie un shfmt récent dans le fichier demandé par -o.
  write_shfmt "$SANDBOX/shfmt-new"
  # shellcheck disable=SC2016 # code du stub, développé à son exécution
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "curl $*" >> "$CALLS_LOG"' \
    "for a; do [[ \"\${o:-}\" == 1 ]] && cp $(printf %q "$SANDBOX/shfmt-new") \"\$a\"; o=; [[ \"\$a\" == -o ]] && o=1; done" \
    'exit 0' > "$STUBS/curl"
  chmod +x "$STUBS/curl"
  fake_angular_skill
  stub_claude '[]' '[]'
  local out
  out="$(PATH="$STUBS:$HOME/.local/bin:/usr/bin:/bin" "$CLI" install)"
  assert_contains "$(calls)" "curl -fsSL https://github.com/mvdan/sh/releases/download/v3.14.1/shfmt_v3.14.1_"
  assert_contains "$(calls)" "-o $HOME/.local/bin/shfmt"
  assert_has_line "$out" installed "shfmt ($HOME/.local/bin/shfmt)"
  # ~/.local/bin hors du PATH du hook : warn, pas « installed ».
  rm "$HOME/.local/bin/shfmt"
  out="$(run_install 2>&1)"
  assert_contains "$out" "mettre $HOME/.local/bin en tête du PATH"
  assert_not_contains "$out" "installed shfmt"
}

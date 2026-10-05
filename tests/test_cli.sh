# shellcheck shell=bash
# shellcheck disable=SC2154

test_cli_help() {
  local out
  out="$("$CLI" --help)"
  assert_contains "$out" "install"
  assert_contains "$out" "init-project"
}

test_cli_unknown_command() {
  local rc=0 out
  out="$("$CLI" frobnicate 2>&1)" || rc=$?
  assert_eq "$rc" 2 "code de sortie"
  assert_contains "$out" "commande inconnue : frobnicate"
}

test_cli_without_command() {
  local rc=0 out
  out="$("$CLI" 2>&1)" || rc=$?
  assert_eq "$rc" 2 "code de sortie"
  assert_contains "$out" "Usage"
}

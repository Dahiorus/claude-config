# shellcheck shell=bash
# shellcheck disable=SC2154

# Plusieurs filtres : chaque test dont le nom contient l'un d'eux tourne, shellcheck non.
test_runner_takes_several_filters() {
  local out
  out="$(bash "$TESTS_DIR/run.sh" test_plugins_without_bump test_md_long_lines_flags_prose_only </dev/null)"
  assert_eq "$(grep -c '^PASS' <<<"$out")" 2 "deux tests lancés : $out"
  [[ "$out" != *shellcheck* ]] || fail "shellcheck lancé malgré les filtres"
}

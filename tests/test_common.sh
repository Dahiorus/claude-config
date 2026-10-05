# shellcheck shell=bash
# shellcheck disable=SC2154

test_backup_path_avoids_collision() {
  # shellcheck source=lib/common.sh
  source "$REPO/lib/common.sh"
  DRY_RUN=0
  timestamp() { printf '20260101-000000'; }
  printf 'a' > "$SANDBOX/f"
  backup_path "$SANDBOX/f" >/dev/null
  printf 'b' > "$SANDBOX/f"
  backup_path "$SANDBOX/f" >/dev/null
  assert_eq "$(cat "$SANDBOX/f.bak-20260101-000000")" "a" "première sauvegarde"
  assert_eq "$(cat "$SANDBOX/f.bak-20260101-000000-1")" "b" "seconde sauvegarde"
  [[ ! -e "$SANDBOX/f" ]] || fail "le fichier d'origine aurait dû être déplacé"
}

test_backup_path_dry_run_moves_nothing() {
  # shellcheck source=lib/common.sh
  source "$REPO/lib/common.sh"
  DRY_RUN=1
  printf 'a' > "$SANDBOX/f"
  local out
  out="$(backup_path "$SANDBOX/f")"
  assert_contains "$out" "backup"
  [[ -e "$SANDBOX/f" ]] || fail "dry-run ne doit rien déplacer"
  assert_eq "$(count_backups "$SANDBOX")" 0 "nombre de sauvegardes"
}

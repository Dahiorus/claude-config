# shellcheck shell=bash
# settings.json : généré depuis settings/base.json (+ settings/local.json), copié et non symlinké.
# Sourcé par bin/claude-config, qui définit REPO_ROOT, CLAUDE_HOME et DRY_RUN.
# shellcheck disable=SC2154

# Écrit sur stdout les settings fusionnés ; sort en erreur si une source est invalide.
merged_settings() {
  local base="$REPO_ROOT/settings/base.json" loc="$REPO_ROOT/settings/local.json"
  [[ -f "$base" ]] || die "settings/base.json introuvable"
  jq -e 'type == "object"' "$base" >/dev/null 2>&1 || die "settings/base.json n'est pas un objet JSON valide"
  if [[ -f "$loc" ]]; then
    jq -e 'type == "object"' "$loc" >/dev/null 2>&1 || die "settings/local.json n'est pas un objet JSON valide"
    jq -s '.[0] * .[1]' "$base" "$loc"
  else
    jq . "$base"
  fi
}

install_settings() {
  local dest="$CLAUDE_HOME/settings.json" merged
  merged="$(merged_settings)"
  if [[ -e "$dest" || -L "$dest" ]]; then
    if jq -e . "$dest" >/dev/null 2>&1 && [[ "$(jq -S . "$dest")" == "$(jq -S . <<<"$merged")" ]]; then
      log ok settings.json
      return 0
    fi
    backup_path "$dest"
  fi
  if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$CLAUDE_HOME"
    printf '%s\n' "$merged" > "$dest.tmp"
    mv "$dest.tmp" "$dest"
  fi
  log written settings.json
}

status_settings() {
  local dest="$CLAUDE_HOME/settings.json" merged diff_out
  merged="$(merged_settings)"
  if [[ ! -e "$dest" ]]; then
    log missing settings.json
    return 1
  fi
  if ! jq -e . "$dest" >/dev/null 2>&1; then
    log drift "settings.json (JSON invalide)"
    return 1
  fi
  if diff_out="$(diff -u --label attendu --label actuel <(jq -S . <<<"$merged") <(jq -S . "$dest"))"; then
    log ok settings.json
    return 0
  fi
  log drift settings.json
  printf '%s\n' "$diff_out"
  return 1
}

capture_settings() {
  local src="$CLAUDE_HOME/settings.json" base="$REPO_ROOT/settings/base.json"
  local loc="$REPO_ROOT/settings/local.json" result
  [[ -f "$src" ]] || die "$src introuvable"
  jq -e 'type == "object"' "$src" >/dev/null 2>&1 || die "$src n'est pas un objet JSON valide"
  jq -e 'type == "object"' "$base" >/dev/null 2>&1 || die "settings/base.json n'est pas un objet JSON valide"
  if [[ -f "$loc" ]]; then
    jq -e 'type == "object"' "$loc" >/dev/null 2>&1 || die "settings/local.json n'est pas un objet JSON valide"
    result="$(jq -n --slurpfile cur "$src" --slurpfile base "$base" --slurpfile loc "$loc" \
      -f "$REPO_ROOT/lib/capture.jq")"
  else
    result="$(jq . "$src")"
  fi
  printf '%s\n' "$result" > "$base.tmp"
  mv "$base.tmp" "$base"
  log written settings/base.json
  git -C "$REPO_ROOT" diff --stat -- settings/base.json 2>/dev/null || true
}

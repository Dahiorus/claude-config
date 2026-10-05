#!/usr/bin/env bash
# Hook PreToolUse (Bash) : build-brief réécrit les commandes Gradle, puis rtk réécrit le reste.
# rtk ne touche pas aux segments « build-brief … » : une sortie Gradle n'est jamais filtrée deux fois.
# Si l'un des deux outils est absent ou échoue, l'autre s'applique seul ; sans réécriture, rien n'est émis.
set -uo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)"
[[ -n "$cmd" ]] || exit 0

rewritten="$cmd"
if command -v build-brief >/dev/null 2>&1; then
  rewritten="$(build-brief rewrite "$cmd" 2>/dev/null)" || rewritten="$cmd"
  [[ -n "$rewritten" ]] || rewritten="$cmd"
fi

rtk_out=""
if command -v rtk >/dev/null 2>&1; then
  rtk_out="$(jq -c --arg c "$rewritten" '.tool_input.command = $c' <<<"$input" | rtk hook claude 2>/dev/null)" || rtk_out=""
fi

if [[ -n "$rtk_out" ]]; then
  printf '%s\n' "$rtk_out"
elif [[ "$rewritten" != "$cmd" ]]; then
  jq -c --arg c "$rewritten" '{hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecisionReason: "build-brief auto-rewrite",
      updatedInput: (.tool_input + {command: $c})
    }}' <<<"$input"
fi

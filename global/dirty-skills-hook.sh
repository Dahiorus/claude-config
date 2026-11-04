#!/usr/bin/env bash
# SessionStart : signale les fichiers de global/ modifiés et non commités dans claude-config.
# Les skills sont reliés à ~/.claude, une autre session a pu les toucher.
set -euo pipefail
repo="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd -P)"
changes="$(git -C "$repo" status --porcelain -- global 2>/dev/null)" || exit 0
[[ -n "$changes" ]] || exit 0
msg="claude-config ($repo) : fichiers de global/ modifiés et non commités, peut-être par une autre session. Ne pas les embarquer dans un commit sans vérifier :
$changes"
jq -n --arg m "$msg" '{systemMessage: $m, hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $m}}'

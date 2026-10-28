#!/usr/bin/env bash
# Hook PreToolUse (Bash) : refuse un commit sur main et un push qui met à jour main, pour passer par /pr push.
# Restent permis depuis main : push d'un tag, d'une autre branche, et --delete (release, nettoyage après merge).
# shortcut: un « cd <dir> && git … » est jugé sur la branche du cwd de la session ; suivre les cd si ça gêne.
set -uo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)"
[[ -n "$cmd" ]] || exit 0
cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)"
cwd="${cwd:-$PWD}"

branch_of() { git -C "$1" branch --show-current 2>/dev/null; }

# Vrai si le segment (mots d'une commande simple) commite sur main ou pousse vers main.
violates() {
  local -a w=("$@")
  local i=0 n=${#w[@]} dir="$cwd"
  # Seuls les préfixes de lancement précèdent git : « echo git push » n'est pas un push.
  while ((i < n)) && [[ "${w[i]}" =~ ^(rtk|sudo|env|command|[A-Za-z_][A-Za-z0-9_]*=.*)$ ]]; do ((i++)); done
  [[ "${w[i]:-}" == git || "${w[i]:-}" == */git ]] || return 1
  ((i++))
  while ((i < n)) && [[ "${w[i]}" == -* ]]; do
    case "${w[i]}" in
      -C) [[ "${w[i+1]:-}" == /* ]] && dir="${w[i+1]}" || dir="$cwd/${w[i+1]:-}"; ((i += 2)) ;;
      -c) ((i += 2)) ;;
      *) ((i++)) ;;
    esac
  done
  local sub="${w[i]:-}" current
  current="$(branch_of "$dir")"
  ((i++))
  case "$sub" in
    commit) [[ "$current" == main ]] ;;
    push)
      local -a pos=()
      for a in "${w[@]:i}"; do
        case "$a" in
          --delete | -d | --tags) return 1 ;;
          -*) ;;
          *) pos+=("$a") ;;
        esac
      done
      # Sans refspec, git pousse la branche courante.
      ((${#pos[@]} > 1)) || { [[ "$current" == main ]]; return; }
      for ref in "${pos[@]:1}"; do
        ref="${ref#+}"
        [[ "${ref##*:}" == main || "${ref##*:}" == refs/heads/main ]] && return 0
        [[ "$ref" == HEAD && "$current" == main ]] && return 0
      done
      return 1
      ;;
    *) return 1 ;;
  esac
}

while IFS= read -r segment; do
  read -ra words <<<"$segment"
  if violates "${words[@]}"; then
    jq -nc '{hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "Pas de commit ni de push sur main : passe par /pr push, qui crée la branche et ouvre la PR."
      }}'
    exit 0
  fi
done < <(sed -E 's/(&&|\|\||;|\|)/\n/g' <<<"$cmd")

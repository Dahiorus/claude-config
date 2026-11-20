#!/usr/bin/env bash
# PreToolUse Bash : refuse un appel qui publie du texte vers GitHub (PR, issue, commentaire de PR ou d'issue, relecture,
# push forcé, merge)
# si le skill humanizer:humanizer n'est pas passé depuis le dernier message tapé par l'utilisateur.
# shortcut: lecture par motif du texte de l'appel ; une commande cachée (variable, alias, eval) n'est pas vue,
#   un corps de texte qui cite un point de publication fait un faux refus. Passer à l'arbre shfmt de main-guard si
#   un cas réel le demande.
#   Un | ; & entre guillemets coupe la commande (option d'écriture après un --jq '…|…' non vue).
# shortcut: /humanizer:humanizer tapé par l'utilisateur ne compte pas, seul l'outil Skill est lu.
set -uo pipefail

W='(^|[^[:alnum:]_-])'    # début de mot, tirets compris
SP='[[:space:]]'
END='(=|[[:space:]]|$)'   # fin d'une option entière
SHORT="${SP}-[[:alpha:]]*"  # option courte, seule, groupée (-cb) ou collée à sa valeur (-b"x") : suivie de sa lettre
BODY_OPTS="${SP}(--body|--body-file)${END}|${SHORT}[bF]"
EDIT_OPTS="${SP}(--body|--body-file|--title)${END}|${SHORT}[bFt]"
CLOSE_OPTS="${SP}--comment${END}|${SHORT}c"
API_PATH='/(reviews|replies|comments)(/[^/[:space:]"'"'"'?]+)?([?[:space:]"'"'"']|$)'
API_WRITE="${SP}(--field|--raw-field|--input)${END}|${SHORT}[fF]|${SP}(-X|--method)(${SP}+|=)?POST"

# line_is_publication <ligne> : la ligne (continuations déjà jointes) est un point de publication.
line_is_publication() {
  local l="$1"
  [[ "$l" =~ ${W}gh${SP}+pr${SP}+(create|comment|merge)${END} ]] && return 0
  [[ "$l" =~ ${W}gh${SP}+issue${SP}+comment${END} ]] && return 0
  [[ "$l" =~ ${W}gh${SP}+pr${SP}+edit${END} && "$l" =~ $EDIT_OPTS ]] && return 0
  [[ "$l" =~ ${W}gh${SP}+pr${SP}+review${END} && "$l" =~ $BODY_OPTS ]] && return 0
  [[ "$l" =~ ${W}gh${SP}+issue${SP}+(create|edit)${END} && "$l" =~ $BODY_OPTS ]] && return 0
  [[ "$l" =~ ${W}gh${SP}+(pr|issue)${SP}+close${END} && "$l" =~ $CLOSE_OPTS ]] && return 0
  [[ "$l" =~ ${W}gh${SP}+api${END} && "$l" =~ $API_PATH && "$l" =~ $API_WRITE ]] && return 0
  [[ "$l" =~ ${W}git${SP}+(.*${SP})?push${SP}.*--force-with-lease ]] && return 0
  return 1
}

is_publication() {
  local joined="${1//$'\\\n'/ }" line
  while IFS= read -r line; do
    line_is_publication "$line" && return 0
  done <<<"${joined//[|;&]/$'\n'}"  # une commande par ligne : cut -f ou grep -F d'un pipeline ne comptent pas
  return 1
}

has_marker() {
  [[ "$1" =~ '#'${SP}*humanizer:${SP}*(sans\ objet|déjà\ relu) ]]
}

# recent_passage <transcript> : 0 si la dernière entrée retenue est un passage, 1 sinon, 2 si jq échoue.
recent_passage() {
  local last
  last="$(jq -Rr 'fromjson? | select(type == "object" and .isSidechain != true)
    | if .type == "assistant"
         and any(.message.content[]?; .type == "tool_use" and .name == "Skill"
                 and .input.skill == "humanizer:humanizer")
      then "S"
      elif .type == "user" and (.isMeta != true)
         and ((.origin.kind // "human") == "human") and (.isCompactSummary != true)
         and (.message.content | type == "string" or all(.[]; .type != "tool_result"))
      then "H"
      else empty end' "$1")" || return 2
  [[ "${last##*$'\n'}" == "S" ]]
}

deny() {
  local reason="Texte publié vers GitHub sans passage par humanizer depuis le dernier message de l'utilisateur (consigne « Humanizer » du CLAUDE.md global). Passe le texte par le skill humanizer:humanizer, reprends le texte réécrit, puis relance l'appel. Marqueurs, en commentaire dans l'appel : « # humanizer: sans objet » si l'appel n'envoie pas de prose (titre fait d'un identifiant, push forcé d'un rebase) ; « # humanizer: déjà relu » si le texte, déjà passé par humanizer, a été approuvé tel quel par l'utilisateur."
  jq -n --arg r "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
}

command -v jq >/dev/null 2>&1 || exit 0
input="$(cat)"
command_text="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)" || exit 0
[[ -n "$command_text" ]] || exit 0
is_publication "$command_text" || exit 0
has_marker "$command_text" && exit 0
transcript="$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null)" || exit 0
[[ -n "$transcript" && -r "$transcript" ]] || exit 0
recent_passage "$transcript"
case $? in
  1) deny ;;
esac
exit 0

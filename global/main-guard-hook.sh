#!/usr/bin/env bash
# Hook PreToolUse (Bash) : refuse commit sur main et push vers main (passer par /pr push) ; tag, autre branche et --delete passent.
# Segments lus dans l'ordre : cd/pushd <dir> et git switch -c <b> reliés par && changent dossier et branche jugés ensuite.
# shortcut: cd non résolu ($VAR, $(…), cd -) jugé sur le dossier de départ ; résoudre les variables si ça gêne.
# shortcut: après ; || | ou saut de ligne, retour au départ (depuis un worktree, « git switch main; git commit » passe) ; garder un retour vers main si ça gêne.
# shortcut: contenu de $( ) et de ` non jugé ; vrai parseur shell si ça gêne.
# shortcut: « motif) » de case dans $( ) ferme le $( ) trop tôt ; vrai parseur shell si ça gêne.
# shortcut: << arithmétique ($((1<<2))) pris pour un heredoc ; vrai parseur shell si ça gêne.
# shortcut: lignes d'un heredoc hors $( ) jugées comme des commandes ; vrai parseur shell si ça gêne.
# shortcut: guillemets déséquilibrés ou contexte resté ouvert : repli, chaque saut de ligne coupe, guillemets ignorés ; vrai parseur shell si ça gêne.
set -uo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")" || { echo "main-guard : entrée illisible, appel refusé" >&2; exit 2; }
[[ -n "$cmd" ]] || exit 0
cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)"
cwd="${cwd:-$PWD}"
LC_ALL=C # lecture octet par octet

here="$cwd"                    # dossier jugé
switched_dir="" switched_to="" # branche prise par un git switch plus tôt
forks=0                        # plafond de processus (cd, pushd, git lus)
verb="" dir="" sub="" args=()  # segment lu par parse

branch_of() {
  if [[ -n "$switched_to" && "$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" == "$switched_dir" ]]; then echo "$switched_to"; else git -C "$1" branch --show-current 2>/dev/null; fi
}

# Chemin absolu d'un argument de cd ou -C (guillemets, ~) ; vide s'il est calculé.
resolve() {
  local p="${1//[\"\']/}"
  [[ -z "$p" ]] && p="$HOME"
  [[ "$p" == *'$'* ]] && return
  [[ "${p:0:1}" == '~' && ( ${#p} == 1 || "${p:1:1}" == / ) ]] && p="$HOME${p:1}"
  [[ "$p" == /* ]] || p="$here/$p"
  (cd "$p" 2>/dev/null && pwd)
}

# Lit un segment : verb (cd, git ou vide), dir (-C, sinon dossier jugé), sub, args.
parse() {
  local -a w=("$@")
  local i=0 n=${#w[@]}
  verb="" dir="$here" sub="" args=()
  # Seuls les préfixes de lancement précèdent git : « echo git push » n'est pas un push.
  while ((i < n)) && [[ "${w[i]}" =~ ^(rtk|sudo|env|command|time|\{|!|if|then|elif|else|while|until|do|[A-Za-z_][A-Za-z0-9_]*=.*)$ ]]; do ((i++)); done
  case "${w[i]:-}" in
    cd | pushd) verb=cd args=("${w[@]:i+1}") ;;
    git | */git) verb=git ;;
  esac
  [[ "$verb" == git ]] || return 0
  ((i++))
  while ((i < n)) && [[ "${w[i]}" == -* ]]; do git_option "${w[i]}" "${w[i+1]:-}"; ((i += $?)); done
  sub="${w[i]:-}" args=("${w[@]:i+1}")
}

git_option() { # option git avant la sous-commande : code retour = mots lus (-C, -c prennent une valeur) ; -C fixe dir
  case "$1" in
    -C) dir="$(resolve "$2")"; dir="${dir:-$here}"; return 2 ;;
    -c) return 2 ;;
  esac
  return 1
}

# Suivi : cd change le dossier jugé, switch la branche prise.
track() {
  [[ "$verb" == cd ]] && track_cd
  [[ "$sub" == switch || "$sub" == checkout ]] && track_switch
}

track_cd() {
  local i=0 to
  while [[ "${args[i]:-}" =~ ^-[LPe@]+$ ]]; do ((i++)); done
  [[ "${args[i]:-}" == -- ]] && ((i++))
  to="$(resolve "${args[*]:i}")" # tout le reste : chemin à espaces entre guillemets
  here="${to:-$cwd}"             # non résolu (cd -, $VAR) : dossier de départ
}

track_switch() {
  local a create="" to pos=()
  for a in "${args[@]}"; do switch_arg "$a"; done
  to="${pos[0]:-}" # 1er argument non optionnel : branche visée
  [[ "$sub" == switch || -n "$create" || "$to" == main || "$to" == - || "$to" == @\{-1\} ]] || return # checkout de fichier
  local top; top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)"
  top="${top:-$dir}"
  [[ "$to" == - || "$to" == @\{-1\} ]] && to="$(previous_branch "$top")"
  switched_dir="$top" switched_to="$to"
}

# Range un argument de switch ou checkout dans create ou pos, locaux de track_switch.
switch_arg() {
  case "$1" in
    -[bBcC] | -[!-]*[bBcC]*) create=1 ;; # -b, -c et options courtes collées (-qb)
    -) pos+=("$1") ;; # branche précédente
    -*) ;;
    *) pos+=("$1") ;;
  esac
}

# « - » : vide juste après un switch dans ce dépôt (relire la branche réelle), sinon @{-1}.
previous_branch() {
  [[ -n "$switched_to" && "$switched_dir" == "$1" ]] && return
  git -C "$dir" rev-parse --abbrev-ref '@{-1}' 2>/dev/null
}

# Vrai si le segment commite sur main ou pousse vers main.
violates() {
  case "$sub" in
    commit) [[ "$(branch_of "$dir")" == main ]] ;;
    push) pushes_main ;;
    *) return 1 ;;
  esac
}

pushes_main() {
  local a current pos=() refs dests
  [[ " ${args[*]} " =~ \ (--delete|-d|--tags)\  ]] && return 1
  for a in "${args[@]}"; do positional "$a"; done
  current="$(branch_of "$dir")"
  ((${#pos[@]} > 1)) || { [[ "$current" == main ]]; return; } # sans refspec : branche courante
  refs=("${pos[@]:1}") && refs=("${refs[@]#+}") && dests=("${refs[@]##*:}") # mots sans blanc : read -ra les a coupés
  [[ " ${dests[*]} " =~ \ (main|refs/heads/main)\  || ( " ${refs[*]} " == *" HEAD "* && "$current" == main ) ]]
}
positional() { [[ "$1" == -* ]] || pos+=("$1"); } # ajoute à pos (local de l'appelant) un mot qui n'est pas une option

deny() {
  jq -nc --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

# flatten écrit dans flat une ligne où seuls && || ; | séparent les commandes (sed découpe ensuite). stack : un contexte
# par niveau, " ' $ ($'…) ( ($( )) { (${…}) ` ; vide : niveau commande, où \⏎ recolle, # commente, ⏎ vaut « ; » sauf
# après && || |, ( ) & seul et lignes de heredoc valent « ; ». Dans un contexte, ⏎ ; & | deviennent des blancs.
ch=()
while IFS= read -r -d '' -n1 c; do ch+=("$c"); done < <(printf '%s' "$cmd") # tableau lu une fois : ${cmd:k:1} serait quadratique
n=${#ch[@]}
stop=$'[ \t\n;&|<>()]' # fin d'un délimiteur de heredoc (blancs de bash : pas \r \v \f)

# last : deux derniers caractères non blancs écrits ; prev : dernier caractère écrit ; ws : le prochain caractère commence un mot.
emit() {
  flat+="$1" prev="${1: -1}"
  [[ "$1" == [$' \t\n'] ]] || last="${last: -1}$1"
  if [[ "$1" == [$' \t\n'\;\&\|\(] ]]; then ws=1; else ws=""; fi
}

# Au niveau commande : & seul sépare (pas &&, &>, >&) ; |& vaut | (le & redirige stderr).
amp_pipe() {
  local nxt="${ch[k + 1]:-}"
  if [[ "$c$nxt" == '&&' ]]; then
    emit '&' && ((++k))
  elif [[ "$c" == '&' && "$nxt" != '>' && "$prev" != '>' ]]; then
    c=";"
  elif [[ "$c$nxt" == '|&' ]]; then
    ((++k))
  fi
}

eol() { if [[ "$last" == '&&' || "$last" == *'|' ]]; then c=" "; else c=";"; fi; } # ⏎ au niveau commande : continue après && || |

escape() {
  local e="${ch[k + 1]:-}"
  ((k++))
  [[ "$e" == $'\n' ]] && return   # « \⏎ » recolle
  [[ "$e" == [\;\&\|] ]] && e=" " # « \; » est un caractère, pas un séparateur
  flat+="\\$e" last="\\$e" prev="\\" ws="" # prev n'est jamais « > » : « \>& » n'est pas une redirection
}

in_string() {
  if [[ "$c" == "${ctx/\$/\'}" ]]; then
    stack="${stack%?}" # ' ferme aussi $'
  elif [[ "$ctx$c" == '"`' ]]; then
    stack+='`'
  elif [[ "$ctx$c" == "\"\$" && "${ch[k + 1]:-}" == [\(\{] ]]; then
    stack+="${ch[k + 1]}" && emit '$' && ((++k)) && c="${ch[k]}"
  fi
  [[ "$c" == [$'\n'\;\&\|] ]] && c=" "
  emit "$c"
}

# << : délimiteur tel que bash le voit sans guillemets ('E"' attend E"), corps au prochain ⏎ ; guillemet non fermé : repli.
heredoc_op() {
  if [[ "${ch[k + 2]:-}" == '<' ]]; then emit '<<<' && ((k += 2)); return; fi
  local mode=+ word="" q
  emit '<<' && ((++k))
  [[ "${ch[k + 1]:-}" == - ]] && mode=- && ((++k))
  while [[ "${ch[k + 1]:-}" == [[:blank:]] ]]; do ((k++)); done
  # shellcheck disable=SC2053 # $stop est un motif
  while ((k + 1 < n)) && [[ "${ch[k + 1]}" != $stop ]]; do
    q="${ch[++k]}"
    if [[ "$q" == '$' && "${ch[k + 1]:-}" == [\"\'] ]]; then
      : # <<$'E' : bash retire le $, le guillemet suivant se lit au tour d'après
    elif [[ "$q" == [\"\'] ]]; then
      while ((++k < n)) && [[ "${ch[k]}" != "$q" ]]; do
        [[ "$q${ch[k]}" == "\"\\" ]] && ((++k))
        word+="${ch[k]:-}"
      done
      ((k < n)) || stack+="$q"
    elif [[ "$q" == \\ ]]; then
      word+="${ch[++k]:-}"
    else
      word+="$q"
    fi
  done
  emit " ${word//[;&|$'\n']/ } "
  docs+=("$mode$word")
}

# Corps des heredocs, k du ⏎ d'avant à juste avant le ⏎ du dernier délimiteur : commandes au niveau commande, données dans $( ).
heredoc_bodies() {
  local d line s e
  for d in "${docs[@]}"; do
    while ((k + 1 < n)); do
      s=$((k + 1)) line=""
      while ((++k < n)) && [[ "${ch[k]}" != $'\n' ]]; do line+="${ch[k]}"; done
      e=$k
      [[ "${d:0:1}" == - ]] && while [[ "$line" == $'\t'* ]]; do line="${line:1}"; done
      [[ "$line" == "${d:1}" ]] && break
      if [[ -n "$stack" ]]; then
        flat+="${line//[;&|]/ } "
      else
        for ((k = s; k < e; k++)); do c="${ch[k]}" && plain_char; done
        emit ";"
      fi
    done
  done
  docs=() last=""
  ((k--))
}

in_code() {
  local nxt="${ch[k + 1]:-}"
  [[ -n "$ctx" && "$c" == [\;\&\|] ]] && { emit " "; return; }
  case "$c" in
    \" | \' | \`) if [[ "$c$ctx" == '``' ]]; then stack="${stack%?}"; else stack+="$c"; fi ;;
    \$) [[ "$nxt" == [\'\(\{] ]] && stack+="${nxt/\'/\$}" && emit '$' && ((++k)) && c="$nxt" ;;
    # ( ) : sous-shell au niveau commande, niveau de $( ) dedans, simple caractère dans ${…} et `.
    \() case "$ctx" in '') c=";" ;; '(') stack+='(' ;; esac ;;
    \)) case "$ctx" in '') c=";" ;; '(') stack="${stack%?}" ;; esac ;;
    \}) [[ "$ctx" == '{' ]] && stack="${stack%?}" ;;
    # Pas de commentaire entre backticks ni dans ${…} : bash ferme au premier ` ou }, même après un #.
    \#) [[ -n "$ws" && "$ctx" != [\`\{] ]] && { while ((k + 1 < n)) && [[ "${ch[k + 1]}" != $'\n' ]]; do ((k++)); done; return; } ;;
    \<) [[ "$nxt" == '<' ]] && { heredoc_op; return; } ;;
    \& | \|) amp_pipe ;;
    $'\n')
      eol
      [[ -n "$ctx" ]] && c=" "
      emit "$c"
      ((${#docs[@]})) && heredoc_bodies
      return
      ;;
  esac
  emit "$c"
}

flatten() { # 1 si un contexte reste ouvert (guillemets déséquilibrés, construction non suivie)
  flat="" last="" prev="" ws=1 stack="" docs=()
  for ((k = 0; k < n; k++)); do
    c="${ch[k]}" ctx="${stack: -1}"
    if [[ "$c" == \\ && "$ctx" != "'" ]]; then escape
    elif [[ "$ctx" == [\"\'\$] ]]; then in_string
    else in_code
    fi
  done
  [[ -z "$stack" ]]
}

# Un caractère lu sans guillemets (repli, ligne de heredoc) : saut de ligne, ( ) & seul et |& comme au niveau commande.
plain_char() {
  case "$c" in
    $'\n') eol ;;
    \( | \)) c=";" ;;
    \& | \|) amp_pipe ;;
  esac
  emit "$c"
}

flatten_plain() { # repli : guillemets ignorés, chaque ⏎ coupe
  flat="" last="" prev=""
  for ((k = 0; k < n; k++)); do
    c="${ch[k]}"
    if [[ "$c" == \\ ]]; then escape; else plain_char; fi
  done
}

flatten || flatten_plain

while IFS= read -r segment; do
  read -ra words <<<"$segment"
  sep=""
  [[ "${words[0]:-}" =~ ^(\&\&|\|\||;|\|)$ ]] && { sep="${words[0]}"; words=("${words[@]:1}"); }
  [[ -n "$sep" && "$sep" != "&&" ]] && here="$cwd" switched_dir="" switched_to="" # cd ou switch a pu échouer
  parse "${words[@]}"
  # 2 à 3 ms par processus : au-delà de 2000, le délai de 60 s du hook laisserait tout passer.
  [[ -n "$verb" ]] && ((++forks > 2000)) && deny "Plus de 2000 cd ou git dans la commande, trop long pour que main-guard la juge : découpe-la."
  track
  violates && deny "Pas de commit ni de push sur main : passe par /pr push, qui crée la branche et ouvre la PR."
done < <(sed -E 's/(&&|\|\||;|\|)/\n\1 /g' <<<"$flat")

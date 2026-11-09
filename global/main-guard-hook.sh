#!/usr/bin/env bash
# Hook PreToolUse (Bash) : refuse un commit sur main et un push qui met à jour main, pour passer par /pr push.
# Restent permis depuis main : push d'un tag, d'une autre branche, et --delete (release, nettoyage après merge).
# Les segments se lisent dans l'ordre : « cd/pushd <dir> » et « git switch -c <b> » reliés par && changent le dossier et la branche jugés ensuite.
# shortcut: un cd non résolu (chemin calculé $VAR, $(…), cd -) est jugé sur le dossier de départ ; résoudre les variables si ça gêne.
# shortcut: après ; || | ou un saut de ligne, retour au départ : depuis un worktree, « git switch main; git commit » passe ; garder un retour vers main si ça gêne.
# shortcut: le contenu de $( ) et de ` n'est pas jugé ; un « motif) » de case dans $( ) le ferme trop tôt ; un << arithmétique ($((1<<2))) est pris pour un heredoc ; les lignes d'un heredoc hors $( ) sont jugées comme des commandes ; avec des guillemets déséquilibrés (ou un contexte resté ouvert), repli où chaque saut de ligne coupe, guillemets ignorés ; un vrai parseur shell si ça gêne.
set -uo pipefail

input="$(cat)"
# jq en échec (JSON invalide, jq absent) : refuser plutôt que laisser passer sans jugement.
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")" || { echo "main-guard : entrée illisible, appel refusé" >&2; exit 2; }
[[ -n "$cmd" ]] || exit 0
cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)"
cwd="${cwd:-$PWD}"

here="$cwd"                  # dossier courant après les « cd » déjà lus
switched_dir="" switched_to="" # branche prise par un « git switch » plus tôt dans la commande

branch_of() {
  if [[ -n "$switched_to" && "$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" == "$switched_dir" ]]; then echo "$switched_to"; else git -C "$1" branch --show-current 2>/dev/null; fi
}

# Chemin absolu d'un argument de cd ou de -C, guillemets et ~ compris ; vide s'il est calculé.
resolve() {
  local p="${1//[\"\']/}"
  [[ -z "$p" ]] && p="$HOME"
  [[ "$p" == *'$'* ]] && return
  [[ "${p:0:1}" == '~' && ( ${#p} == 1 || "${p:1:1}" == / ) ]] && p="$HOME${p:1}"
  [[ "$p" == /* ]] || p="$here/$p"
  (cd "$p" 2>/dev/null && pwd)
}

# Vrai si le segment (mots d'une commande simple) commite sur main ou pousse vers main.
violates() {
  local -a w=("$@")
  local i=0 n=${#w[@]} dir="$here"
  # Seuls les préfixes de lancement précèdent git : « echo git push » n'est pas un push.
  while ((i < n)) && [[ "${w[i]}" =~ ^(rtk|sudo|env|command|time|\{|!|if|then|elif|else|while|until|do|[A-Za-z_][A-Za-z0-9_]*=.*)$ ]]; do ((i++)); done
  # Chaque cd, pushd ou git coûte un processus (2 à 3 ms) : au-delà de 2000, le délai de 60 s du hook laisserait tout passer.
  case "${w[i]:-}" in
    cd | pushd | git | */git) ((++forks > 2000)) && deny "Plus de 2000 cd ou git dans la commande, trop long pour que main-guard la juge : découpe-la." ;;
  esac
  if [[ "${w[i]:-}" == cd || "${w[i]:-}" == pushd ]]; then
    ((i++))
    while [[ "${w[i]:-}" =~ ^-[LPe@]+$ ]]; do ((i++)); done
    [[ "${w[i]:-}" == -- ]] && ((i++))
    local to; to="$(resolve "${w[*]:i}")" # tout le reste : un chemin entre guillemets peut contenir des espaces
    # Chemin non résolu (cd -, $VAR) : dossier de départ, où « cd - » ramène le plus souvent.
    pending_here="${to:-$cwd}"
    return 1
  fi
  [[ "${w[i]:-}" == git || "${w[i]:-}" == */git ]] || return 1
  ((i++))
  while ((i < n)) && [[ "${w[i]}" == -* ]]; do
    case "${w[i]}" in
      -C) dir="$(resolve "${w[i+1]:-}")"; dir="${dir:-$here}"; ((i += 2)) ;;
      -c) ((i += 2)) ;;
      *) ((i++)) ;;
    esac
  done
  local sub="${w[i]:-}" current
  current="$(branch_of "$dir")"
  ((i++))
  case "$sub" in
    commit) [[ "$current" == main ]] ;;
    switch | checkout)
      # Premier argument non optionnel = branche visée (le second est le point de départ).
      local -a pos=() create=""
      for a in "${w[@]:i}"; do
        case "$a" in
          -[bBcC] | -[!-]*[bBcC]*) create=1 ;; # -b, -c et options courtes collées (-qb)
          -) pos+=("$a") ;; # branche précédente
          -*) ;;
          *) pos+=("$a") ;;
        esac
      done
      local to="${pos[0]:-}"
      # checkout sans -b vise une branche ou un fichier : seuls « main », « - » et « @{-1} » changent le jugement.
      [[ "$sub" == switch || -n "$create" || "$to" == main || "$to" == - || "$to" == @\{-1\} ]] || return 1
      pending_dir="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)"
      pending_dir="${pending_dir:-$dir}"
      # « - » : branche précédente, la réelle juste après un switch dans ce dépôt ; vide (pas de cible) : on relit la branche réelle du dossier.
      if [[ "$to" == - || "$to" == @\{-1\} ]]; then
        if [[ -n "$switched_to" && "$switched_dir" == "$pending_dir" ]]; then to=""; else to="$(git -C "$dir" rev-parse --abbrev-ref '@{-1}' 2>/dev/null)"; fi
      fi
      pending=1 pending_to="$to"
      return 1
      ;;
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

# flatten écrit dans flat une ligne où seuls && || ; | séparent les commandes, que sed découpe ensuite.
# Pile de contextes (stack, un caractère par niveau) : " ' $ (pour $'…), ( (pour $( )), { (pour ${…}) et `. Vide : niveau commande.
# Au niveau commande : « \⏎ » recolle, un commentaire tombe, un saut de ligne vaut « ; » sauf après && || |,
# ( ) & seul et les lignes d'un heredoc valent « ; ». Dans un contexte, saut de ligne et ; & | deviennent des blancs.
LC_ALL=C # un octet par caractère
# ${cmd:k:1} relit la chaîne depuis le début (parcours quadratique) : on lit les caractères une fois, dans un tableau parcouru dans l'ordre.
ch=()
while IFS= read -r -d '' -n1 c; do ch+=("$c"); done < <(printf '%s' "$cmd")
n=${#ch[@]}
# Blancs de bash : espace, tabulation, saut de ligne ([[:space:]] compterait aussi \r \v \f).
stop=$'[ \t\n;&|<>()]' # fin d'un délimiteur de heredoc

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

# Saut de ligne au niveau commande : la commande continue après && || |, sinon « ; ».
eol() { if [[ "$last" == '&&' || "$last" == *'|' ]]; then c=" "; else c=";"; fi; }

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

# << : lit le délimiteur comme bash le voit après retrait des guillemets ('E"' attend E"), le corps viendra après le
# prochain saut de ligne. Guillemet non fermé : contexte laissé ouvert, donc repli.
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

# Corps des heredocs en attente, k sur le saut de ligne qui les précède. Au niveau commande chaque ligne est une commande ;
# dans $( ) c'est une donnée, comme entre guillemets. k finit juste avant le saut de ligne qui suit le dernier délimiteur.
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

# Renvoie 1 si un contexte reste ouvert (guillemets déséquilibrés, construction non suivie).
flatten() {
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

# Repli : guillemets ignorés, chaque saut de ligne coupe.
flatten_plain() {
  flat="" last="" prev="" ctx=""
  for ((k = 0; k < n; k++)); do
    c="${ch[k]}"
    if [[ "$c" == \\ ]]; then escape; else plain_char; fi
  done
}

flatten || flatten_plain

deny() {
  jq -nc --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

pending="" pending_dir="" pending_to="" pending_here="" forks=0
while IFS= read -r segment; do
  read -ra words <<<"$segment"
  sep=""
  [[ "${words[0]:-}" =~ ^(\&\&|\|\||;|\|)$ ]] && { sep="${words[0]}"; words=("${words[@]:1}"); }
  # Un cd ou un switch ne compte que suivi de && : après ; || |, ou un saut de ligne, il a pu échouer ou tourner dans un sous-shell.
  if [[ "$sep" == "&&" ]]; then
    [[ -n "$pending_here" ]] && here="$pending_here"
    [[ -n "$pending" ]] && switched_dir="$pending_dir" switched_to="$pending_to"
  elif [[ -n "$sep" ]]; then
    here="$cwd" switched_dir="" switched_to=""
  fi
  pending="" pending_here=""
  violates "${words[@]}" && deny "Pas de commit ni de push sur main : passe par /pr push, qui crée la branche et ouvre la PR."
done < <(sed -E 's/(&&|\|\||;|\|)/\n\1 /g' <<<"$flat")

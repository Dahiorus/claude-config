#!/usr/bin/env bash
# Hook PreToolUse (Bash) : refuse un push vers main (passer par /pr push) ; commit, tag, autre branche et --delete d'une autre branche passent.
# shfmt --to-json (mvdan/sh) lit la commande ; jq traduit l'arbre en programme pour une pile d'ensembles d'états
# (dossier jugé, dépôt basculé, branche prise) ; le push est refusé si un seul état possible vise main.
# shortcut: alias et fonctions shell, eval, bash -c d'une variable ou avec -o, script lu dans un fichier, un pipe ou un heredoc, xargs, find -exec, exec, trap, watch : la commande lancée n'est pas jugée ; les lire si Claude s'en sert pour pousser.
# shortcut: alias git (« !… » compris), options abrégées (--mir, --cr), options globales de git autres que -C, -c, --git-dir, --work-tree et --namespace, env -C/-u/-S, sudo -D, GIT_DIR posé par export ou declare (seul GIT_DIR=… devant l'appel est lu) : non reconnus, le push peut passer ; les lire si Claude s'en sert.
# shortcut: remote.*.push ignoré, branch -m non suivi, boucle jugée en un seul tour, « ! cd … && » lu comme cd : un push vers main peut passer ; les lire si un cas réel le demande.
# shortcut: "$X" lu comme un mot inconnu, donc jugé comme main (refspec ou dépôt calculé, $(git branch --show-current)), checkout -- <fichier>, switch dans un second dépôt ou dans un dépôt inconnu (git -C "$X"), pushd -n, git -C "", command -v : refus de trop ; les lire si ces refus gênent.
set -uo pipefail
set -f # aucun glob : les états et les mots sont découpés à la main
SECONDS=0 # bash reprend SECONDS de l'environnement : le budget part de zéro
budget="${MAIN_GUARD_BUDGET:-40}" # les tests le raccourcissent ; jamais plus de 40 s
[[ "$budget" =~ ^[0-9]+$ ]] && ((budget <= 40)) || budget=40

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")" || { echo "main-guard : entrée illisible, appel refusé" >&2; exit 2; }
[[ -n "$cmd" ]] || exit 0
cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)"
cwd="${cwd:-$PWD}"

MAIN_MSG="Pas de push vers main : passe par /pr push, qui crée la branche et ouvre la PR."
RS=$'\x1e' US=$'\x1f' # ensemble : états finis par RS ; état : dossier jugé US dépôt basculé US branche prise
forks=0

deny() { jq -nc --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'; exit 0; }

# 2 à 3 ms par processus : au-delà de 2000, le délai de 60 s du hook laisserait tout passer.
fork() { ((++forks > 2000)) && deny "Plus de 2000 processus pour juger la commande, trop long pour main-guard : découpe-la."; }

# Arbre de shfmt → jetons séparés par NUL. Mot : L<valeur> littéral, U inconnu ; affectation : A<nom>=<mot>.
# Programme : call <n> <mots…>, et dup swap nip drop2 and or acc sur la pile d'ensembles d'états.
# shellcheck disable=SC2016 # programme jq
JQ='
def unq: gsub("\\\\\n"; "") | gsub("\\\\(?<c>.)"; .c; "s");
def dq: gsub("\\\\\n"; "") | gsub("\\\\(?<c>[$`\"\\\\])"; .c);
def part($c):
  if .Type == "Lit" then
    if $c == "u" and (.Value | test("(^|[^\\\\])([*?]|\\[.*\\]|\\{[^}]*(,|\\.\\.))")) then null
    elif $c == "u" then .Value | unq else .Value | dq end
  elif .Type == "SglQuoted" then if .Dollar and (.Value | test("\\\\")) then null else .Value end # ANSI-C avec antislash : inconnu
  elif .Type == "DblQuoted" then [.Parts[]? | part("d")] | if any(.[]; . == null) then null else join("") end
  else null end;
def word: [.Parts[] | part("u")] as $p
  | if any($p[]; . == null) then "U"
    elif .Parts[0].Type == "Lit" and (.Parts[0].Value | startswith("~")) then
      if .Parts[0].Value | test("^~(/|$)") then "L" + $home + ($p | join(""))[1:] else "U" end
    else "L" + ($p | join("")) end;
def substs: if type == "object" then (if .Type == "CmdSubst" or .Type == "ProcSubst" then . else .[] | substs end)
  elif type == "array" then .[] | substs else empty end;
def stmtq: type == "object" and has("Position") and (has("Type") | not);
def stmtlists: if type == "array" then (if length > 0 and (.[0] | stmtq) then . else .[] | stmtlists end)
  elif type == "object" then (if stmtq then [.] else .[] | stmtlists end) else empty end;
def gen:
  def sub: ["dup"] + (.Stmts // [] | gen) + ["drop2"];
  if type == "array" then
    if length == 0 then ["dup"] else (.[0] | gen) + ([.[1:][] | ["nip"] + gen] | add // []) end
  elif stmtq then
    ([.Redirs | substs | sub] | add // []) as $r
    | (if .Cmd == null then ["dup"]
       elif .Cmd.Type == "CallExpr" then .Cmd
         | ([(.Assigns, .Args) | substs | sub] | add // [])
           + if (.Args // []) == [] then ["dup"]
             else ([.Assigns[]? | "A" + .Name.Value + "=" + (if .Value then .Value | word else "L" end)]
               + [.Args[] | word]) as $w | ["call", ($w | length | tostring)] + $w end
       else .Cmd | gen end) as $c
    | if .Background then ["dup"] + $r + $c + ["drop2", "dup"] else $r + $c end
  elif .Type == "BinaryCmd" then
    if (.Op | type) != "string" then error("BinaryCmd.Op non textuel : shfmt < 3.14")
    elif .Op == "&&" then (.X | gen) + ["swap"] + (.Y | gen) + ["and"]
    elif .Op == "||" then (.X | gen) + ["dup"] + (.Y | gen) + ["or"]
    else ["dup"] + (.X | gen) + ["drop2", "dup"] + (.Y | gen) + ["drop2", "dup"] end
  elif .Type == "Subshell" then ["dup"] + (.Stmts | gen) + ["drop2", "dup"]
  elif .Type == "Block" then .Stmts | gen
  else ([stmtlists | ["dup"] + gen + ["acc"]] | add // []) + ["dup"] end;
.Stmts // [] | gen | join("\u0000")'

unread() { [[ "$1" == *git* && "$1" == *push* ]] && deny "main-guard : $2"; return 1; }

compile() { # script $1 → jetons dans TOKS ; 1 s'il est illisible, refus s'il cite git et push
  local json
  TOKS=()
  command -v shfmt >/dev/null 2>&1 ||
    unread "$1" "shfmt absent, push refusé faute de pouvoir lire la commande. Installe-le avec « claude-config install »." || return
  fork; fork
  json="$(shfmt -ln bash --to-json <<<"$1" 2>/dev/null)" ||
    unread "$1" "shfmt ne lit pas cette commande, push refusé. Réécris-la en bash standard (shfmt s'installe avec « claude-config install »)." || return
  while IFS= read -r -d '' t; do TOKS+=("$t"); done < <(jq -j --arg home "$HOME" "$JQ" <<<"$json" 2>/dev/null && printf '\0\0')
  # Fin marquée par un jeton vide : sans lui, jq a échoué.
  [[ ${#TOKS[@]} -gt 0 && -z "${TOKS[${#TOKS[@]} - 1]}" ]] ||
    unread "$1" "jq ne lit pas l'arbre de shfmt, push refusé (shfmt 3.14 ou plus requis : « claude-config install »)." || return
  unset "TOKS[${#TOKS[@]}-1]"
}

# Pile d'ensembles d'états (bash 3.2 : pas d'indice négatif).
st=() sp=0
push_set() { st[sp++]="$1"; }
pop_set() { REPLY="${st[--sp]}"; unset "st[$sp]"; }

uniq_set() { # ensemble $1 sans doublon → REPLY ; au-delà de 64 états, le temps (quadratique) dépasserait le délai du hook
  local IFS="$RS" s out="$RS" c=0
  # Appelée à chaque commande : budget de 40 s, sous le délai de 60 s qui laisserait tout passer.
  ((SECONDS >= budget)) && { unread "$cmd" "Plus de 40 s pour juger la commande, trop long pour main-guard : découpe-la."; exit 0; }
  for s in $1; do
    [[ "$out" == *"$RS$s$RS"* ]] && continue
    out+="$s$RS"
    ((++c > 64)) && { unread "$cmd" "Plus de 64 états possibles (cd ou switch répétés), trop long pour main-guard : découpe la commande."; exit 0; }
  done
  REPLY="${out#"$RS"}"
}

run() { # exécute les jetons "$@"
  local -a t=("$@") words
  local i=0 n=$# k m in ok a b c s
  while ((i < n)); do
    case "${t[i]}" in
      dup) push_set "${st[sp - 1]}" ;;
      swap) a="${st[sp - 1]}"; st[sp - 1]="${st[sp - 2]}"; st[sp - 2]="$a" ;;
      nip) pop_set; st[sp - 1]="$REPLY" ;;
      drop2) pop_set; pop_set ;;
      and) pop_set; c="$REPLY"; pop_set; b="$REPLY"; pop_set; uniq_set "$REPLY$c"; push_set "$b"; push_set "$REPLY" ;; # OUTa OKb OUTb
      or) pop_set; c="$REPLY"; pop_set; b="$REPLY"; pop_set; pop_set; uniq_set "$REPLY$b"; push_set "$REPLY"; push_set "$c" ;; # OKa OUTa OKb OUTb ⊇ OUTa
      acc) pop_set; c="$REPLY"; pop_set; pop_set; uniq_set "$REPLY$c"; push_set "$REPLY" ;; # ACC OK OUT
      call)
        k="${t[i + 1]}" words=()
        for ((m = 0; m < k; m++)); do words[m]="${t[i + 2 + m]}"; done # pas de tranche ${t[@]:i} : quadratique
        ((i += k + 1))
        pop_set; in="$REPLY" a="$REPLY" ok=""
        while [[ -n "$in" ]]; do
          s="${in%%"$RS"*}" in="${in#*"$RS"}"
          call_one "$s" "${words[@]}"
          ok+="$NEXT"
        done
        uniq_set "$ok"; ok="$REPLY"; push_set "$ok"; uniq_set "$a$ok"; push_set "$REPLY" ;; # OK, OUT = IN + OK
    esac
    ((i++))
  done
}

path_of() { # jeton $1, dossier de base $2 → REPLY chemin absolu, « ? » si calculé ou absent
  local p="${1:1}"
  [[ "$1" == L?* && "$p" != - && ( "$p" == /* || "$2" != "?" ) ]] || { REPLY="?"; return; }
  [[ "$p" == /* ]] || p="$2/$p"
  cd -- "$p" 2>/dev/null && REPLY="$PWD" || REPLY="?" # cd du hook lui-même : chemin logique, sans processus
}

gitc() { git -C "$1" ${2:+"--git-dir=$2"} "${@:3}" 2>/dev/null; } # git dans le dossier $1, git-dir $2

repo_key() { # KEY : git-dir absolu du dépôt de $1 ($2 : git-dir) ; « * » si inconnu, vide hors dépôt
  [[ "$1" == "?" || "$2" == "?" ]] && { KEY="*"; return; }
  fork; KEY="$(gitc "$1" "$2" rev-parse --absolute-git-dir)"
}

branch_of() { # branche du dossier $1 (git-dir $2) dans l'état courant → REPLY (main si inconnue, vide hors dépôt) ; SWITCHED si prise
  local out key
  SWITCHED=""
  [[ "$1" == "?" || "$2" == "?" ]] && { REPLY=main; return; }
  fork; out="$(gitc "$1" "$2" rev-parse --absolute-git-dir --symbolic-full-name HEAD)"
  key="${out%%$'\n'*}"
  if [[ -n "$sto" && -n "$key" && ( "$sdir" == "*" || "$sdir" == "$key" ) ]]; then REPLY="$sto" SWITCHED=1
  elif [[ "$out" == *$'\n'refs/heads/* ]]; then REPLY="${out#*$'\n'refs/heads/}"
  elif [[ -n "$key" ]]; then REPLY=main # HEAD sans commit ou détachée
  else REPLY=""; fi
}

# Juge un appel dans l'état $1, mots $2… → NEXT : états après succès.
call_one() {
  local state="$1"
  shift
  local -a w=("$@")
  local n=$# i=0 j x v o here sdir sto gitdir="" ext=""
  here="${state%%"$US"*}" sto="${state##*"$US"}" sdir="${state#*"$US"}" sdir="${sdir%"$US"*}"
  NEXT="$state$RS"
  while ((i < n)); do # préfixes de lancement
    x="${w[i]}" v="${w[i]:1}"
    case "$x" in
      AGIT_DIR=*) path_of "${v#*=}" "$here"; gitdir="$REPLY"; ((i++)); continue ;;
      A*) ((i++)); continue ;;
      L*) ;;
      *) break ;;
    esac
    case "${v##*/}" in
      command | builtin) opts ''; continue ;; # builtin du shell courant : son cd compte
      env | nohup | rtk) opts '' ;;
      sudo) opts '[ugpCrtThUD]|-user|-group|-prompt|-close-from|-role|-type|-host|-other-user|-command-timeout|-chdir' ;;
      nice) opts 'n|-adjustment' ;;
      time) opts '[fo]|-format|-output' ;;
      timeout) opts '[sk]|-signal|-kill-after'; ((i++)) ;; # durée
      *) break ;;
    esac
    ext=1 # env cd : programme externe, le shell garde son dossier
  done
  ((i < n)) || return 0
  x="${w[i]}" v="${w[i]:1}" j=$((i + 1))
  [[ "$x" == L* ]] && v="${v##*/}" || v=""
  case "$v" in
    cd | pushd) [[ -n "$ext" ]] || cd_state ;;
    popd) [[ -n "$ext" ]] || NEXT="?$US$sdir$US$sto$RS" ;;
    bash | sh | zsh | dash | ksh) shell_call ;;
    git | "") git_call ;; # commande calculée : jugée comme git
  esac
}

opts() { # passe le préfixe w[i], ses options et ses NAME=valeur ; $1 : options à valeur (regex sans le tiret de tête)
  for ((i++; i < n; i++)); do
    o="${w[i]:1}"
    case "${w[i]}" in
      L--) ((i++)); return 0 ;;
      L-?*) [[ -n "$1" && "$o" =~ ^-($1)$ ]] && ((i++)) ;;
      L[A-Za-z_]*=*) [[ "$o" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || return 0
        [[ "$o" == GIT_DIR=* ]] && { path_of "L${o#*=}" "$here"; gitdir="$REPLY"; } ;;
      *) return 0 ;;
    esac
  done
}

cd_state() { # cd/pushd [-LPe@] [--] [dossier] ; cd seul : $HOME
  local to
  while [[ "${w[j]:-}" =~ ^L-[LPe@]+$ ]]; do ((j++)); done
  [[ "${w[j]:-}" == L-- ]] && ((j++))
  if ((j >= n)); then [[ "$v" == cd ]] && to="$HOME" || to="?"
  else path_of "${w[j]}" "$here"; to="$REPLY"; fi
  NEXT="$to$US$sdir$US$sto$RS"
}

shell_call() { # bash -c '<script>' : jugé dans un sous-shell
  local c=""
  while [[ "${w[j]:-}" == L[-+]?* ]]; do [[ "${w[j]}" =~ ^L-[a-zA-Z]*c ]] && c=1; ((j++)); done
  if [[ -n "$c" && "${w[j]:-}" == L* ]] && compile "${w[j]:1}"; then
    push_set "$here$US$sdir$US$sto$RS"; run ${TOKS[@]+"${TOKS[@]}"}; pop_set; pop_set
  fi
  NEXT="$state$RS" # sous-shell
}

git_call() {
  local dir="$here" gd="$gitdir"
  local -a cfg=()
  while ((j < n)) && [[ "${w[j]}" == L-* ]]; do # options globales
    o="${w[j]:1}" j=$((j + 1)) # pas ${w[j++]:1} : bash 3.2 (macOS) y incrémente j deux fois
    case "$o" in
      -C) path_of "${w[j++]:-U}" "$dir"; dir="$REPLY" ;;
      -c) [[ "${w[j]:-}" == L* ]] && cfg+=(-c "${w[j]:1}"); ((j++)) ;;
      --git-dir) path_of "${w[j++]:-U}" "$dir"; gd="$REPLY" ;;
      --git-dir=*) path_of "L${o#*=}" "$dir"; gd="$REPLY" ;;
      --work-tree | --namespace) ((j++)) ;;
    esac
  done
  case "${w[j++]:-}" in
    Lpush | U*) push_main && deny "$MAIN_MSG" ;;
    Lswitch | Lcheckout) switch_state ;;
  esac
}

switch_state() { # branche créée par -c/-b/-C/-B/--create/--force-create/--orphan, sinon inconnue (main)
  local new=""
  while ((j < n)); do
    o="${w[j++]}"
    case "$o" in
      L--create=* | L--force-create=* | L--orphan=*) new="L${o#*=}" ;;
      L--create | L--force-create | L--orphan) new="${w[j++]:-U}" ;;
      L-[!-]*) [[ "$o" =~ ^L-[ad-zAD-Z]*[bBcC](.*)$ ]] || continue
        [[ -n "${BASH_REMATCH[1]}" ]] && new="L${BASH_REMATCH[1]}" || new="${w[j++]:-U}" ;;
    esac
  done
  [[ "$new" == L?* ]] && new="${new:1}" || new=main
  repo_key "$dir" "$gd"
  [[ -n "$KEY" ]] || return 0
  # Un état ne retient qu'un dépôt : switch dans un dépôt inconnu ou dans un second, la branche devient inconnue partout.
  [[ "$KEY" == "*" || ( -n "$sto" && "$sdir" != "$KEY" ) ]] && KEY="*" new=main
  NEXT="$here$US$KEY$US$new$RS"
}

push_main() { # 0 si le push w[j…] peut viser main
  local pos=() tags="" x
  while ((j < n)); do
    x="${w[j++]}"
    case "$x" in
      U*) return 0 ;;
      L--) pos+=("${w[@]:j}"); break ;;
      L--all | L--branches | L--mirror) return 0 ;;
      L--tags) tags=1 ;;
      L--repo | L--push-option) ((j++)) ;;
      L-[!-]*) [[ "$x" =~ ^L-[^o]*o$ ]] && ((j++)) ;; # -o prend le mot suivant, sauf valeur collée
      L-*) ;;
      *) pos+=("$x") ;;
    esac
  done
  if ((${#pos[@]} < 2)); then
    [[ -z "$tags" ]] && default_main
    return
  fi
  for x in "${pos[@]:1}"; do ref_main "$x" && return 0; done
  return 1
}

ref_main() { # 0 si la refspec $1 peut viser main
  local v="${1:1}"
  [[ "$1" == U* || "$v" == : ]] && return 0 # « : » : branches communes
  v="${v#+}" v="${v%:}" # « main: » pousse main vers main
  [[ "$v" == HEAD || "$v" == @ ]] && { branch_of "$dir" "$gd"; v="$REPLY"; }
  [[ "${v#*:}" =~ ^(refs/heads/|heads/)?(main|HEAD|@)$ || "$v" == *\** ]]
}

default_main() { # push sans refspec : 0 si sa destination peut être main
  local cur mode merge
  branch_of "$dir" "$gd"; cur="$REPLY"
  [[ -n "$cur" ]] || return 1
  fork; fork
  mode="$(gitc "$dir" "$gd" ${cfg[@]+"${cfg[@]}"} config push.default)"
  merge="$(gitc "$dir" "$gd" ${cfg[@]+"${cfg[@]}"} config "branch.$cur.merge")"
  case "${mode:-simple}" in
    nothing) return 1 ;;
    matching) return 0 ;;
    upstream | tracking) [[ -n "$SWITCHED" || "${merge:-refs/heads/$cur}" == refs/heads/main ]] ;; # upstream de la branche prise inconnu
    *) [[ "$cur" == main ]] ;;
  esac
}

# shellcheck disable=SC2329 # appelée par trap
on_exit() { local rc=$?; ((rc)) && unread "$cmd" "plantage du hook (code $rc), push refusé."; }
trap on_exit EXIT # Claude Code laisse passer un code 1
compile "$cmd" || exit 0
push_set "$cwd$US$US$RS"
run ${TOKS[@]+"${TOKS[@]}"}
exit 0

# main-guard : ne juger que le push vers main — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `global/main-guard-hook.sh` ne refuse plus que le push vers main, avec un suivi des `switch` réduit, une
lecture qui ne suit que les guillemets et quatre trous de push fermés, en moins de 200 lignes.

**Architecture:** un seul script bash réécrit. `parse`, `resolve`, `track_cd`, `git_option` et la boucle finale
restent ; `violates` disparaît au profit de `pushes_main` (avec `push_arg`) ; `track_switch` ne retient que la
branche créée ; le parseur à pile (`flatten`, `in_code`, `in_string`, heredocs, repli) laisse place à une lecture
des seuls guillemets (`flatten`, `in_quote`, `in_code`, `amp`, `skip_comment`), relancée sans guillemets s'ils
restent ouverts.

**Tech Stack:** bash, jq, git, `tests/run.sh` (runner maison + shellcheck).

**Spec:** `docs/superpowers/specs/2026-11-09-main-guard-push-only-design.md`

## Amendements de la spec

Le plan a été validé sur un brouillon complet du hook et des tests (tous verts, jugements comparés). La spec, dans
le même commit que ce plan, en reprend les mesures : moins de 200 lignes (190 mesurées) au lieu de 120, lecture
d'environ 50 lignes au lieu de 20, et une limite de plus en `shortcut:` (R4) : des apostrophes dans un `$( )` entre
guillemets doubles peuvent cacher une commande.

## Découpage en PR

Une seule PR, une seule story (P1). Fichiers touchés hors tests, spec et plan : `global/main-guard-hook.sh`,
`CLAUDE.md`, `docs/domaine.md` (3 < 15).

## Global Constraints

- Messages exacts : refus « Pas de push vers main : passe par /pr push, qui crée la branche et ouvre la PR. » ;
  plafond « Plus de 2000 cd ou git dans la commande, trop long pour que main-guard la juge : découpe-la. » ; entrée
  illisible « main-guard : entrée illisible, appel refusé » sur stderr, exit 2.
- `global/main-guard-hook.sh` sous 200 lignes (`wc -l`).
- Chaque `shortcut:` de l'en-tête a un cas dans `test_guard_shortcuts_show_their_limit` qui montre la limite.
- `settings/base.json` inchangé (chemin `bash ~/.claude/main-guard-hook.sh`).
- Tâche 1 : vert sur le hook actuel, avant toute modification du hook.
- Tests lancés avec `bash tests/run.sh guard` (filtre, sans shellcheck) pendant les tâches, `bash tests/run.sh`
  complet (`timeout: 580000`) en fin de tâche 2 et 3.

## Review Focus

1. Un `$( )` entre guillemets doubles qui contient des guillemets décale la lecture : deux apostrophes cachent la
   commande encadrée (limite acceptée, test `test_guard_shortcuts_show_their_limit`).
2. Heredoc dont le corps équilibre deux apostrophes sur des lignes distinctes : une ligne `git push` entre les deux
   passe (même test).
3. `cd "<chemin à espaces>" && git push` : le chemin garde ses guillemets dans le mot, `resolve` les retire (test
   `test_guard_follows_cd`, « cd vers un worktree de branche »).
4. Redirections `2>&1`, `&>`, `>&2`, `\>&` : `&` ne coupe qu'en séparateur (test
   `test_guard_splits_on_background_and_groups`).
5. Faux refus nouveaux de R2 : `git switch feat/x && git push`, `git checkout <fichier> && git push` (test
   `test_guard_follows_switch_in_same_command`).

## Traçabilité

| Exigence (spec) | Tâche | Test qui la prouve |
|---|---|---|
| §5 — cas de push gardés figés avant la modification | 1 | `test_guard_keeps_push_through_cd`, `test_guard_keeps_push_through_switch`, `test_guard_keeps_push_prefixes` |
| R1 — plus de jugement du commit | 2 | `test_guard_allows_commit_on_main` |
| R1 — message de refus | 2 | Global Constraints, `grep -c` de l'étape 6 |
| R2 — branche créée retenue | 2 | `test_guard_follows_switch_in_same_command` (« switch -c », « checkout -b », « options courtes collées ») |
| R2 — autre switch : branche inconnue, jugée comme main | 2 | idem (« checkout main », « switch - », « checkout d'un fichier », « switch vers une branche existante », « switch main depuis le worktree ») |
| R2 — sous-dossier du dépôt du switch | 1 | `test_guard_keeps_push_through_switch` (« sous-dossier du dépôt ») |
| R3 — formes rares gardées | 2 | `test_guard_denies_push_of_main` |
| R3 — `--tags` avec refspec, `--delete main`, `-d main`, `"main"` | 2 | `test_guard_closes_push_holes` |
| R3 — `--all`, `--mirror` | 2 | `test_guard_closes_push_holes`, `test_guard_on_feature_branch` |
| R3 — `-o`/`--push-option` lus avec leur valeur | 2 | `test_guard_closes_push_holes`, `test_guard_allows_branch_tag_and_delete_from_main` |
| R3 — `shortcut:` upstream main | 2 | `test_guard_shortcuts_show_their_limit` (« upstream main non vu ») |
| R4 — guillemets suivis, séparateurs dedans neutres | 1, 2 | `test_guard_keeps_push_through_cd` (« ; entre guillemets », « saut de ligne entre guillemets ») |
| R4 — `(` `)` `` ` `` `&` `|&` coupent, `{` ne coupe pas | 1, 2 | `test_guard_splits_on_background_and_groups`, `test_guard_keeps_push_through_cd` (« { } après cd ») |
| R4 — `\⏎` recolle, ⏎ après `&&` continue | 1, 2 | `test_guard_reads_lines_and_comments`, `test_guard_keeps_push_through_cd` |
| R4 — `#` en début de mot commente | 2 | `test_guard_reads_lines_and_comments` (« commentaire avec apostrophe », « # dans un mot ») |
| R4 — repli sur guillemets déséquilibrés | 2 | `test_guard_reads_lines_and_comments` (« apostrophe seule dans un heredoc »), `test_guard_splits_on_background_and_groups` (« & en repli ») |
| R4 — une ligne `shortcut:` par limite | 2 | `test_guard_shortcuts_show_their_limit` |
| R5 — `cd`, `-C`, préfixes, plafond, entrée illisible | 1, 2 | tests de la tâche 1, `test_guard_follows_cd`, `test_guard_uses_dash_c_directory`, `test_guard_caps_forks_not_lines`, `test_guard_refuses_unreadable_input`, `tests/test_main_guard_track.sh` |
| R6 — `CLAUDE.md`, `docs/domaine.md` | 3 | grep des termes retirés (tâche 3, étape 3) |
| §4 — liste des jugements comparés | 2 | script de l'étape 7, sortie dans `jugements.md` du dossier de suivi |
| §7 — dette (`pushes_main`, `branch_of`, parseur, `track_switch`) | 2 | `wc -l`, `awk 'length > 200'` (étape 6) |
| — mise à jour de la doc | 3 | grep des termes retirés |

Usages vérifiés à l'étape 1b (`git grep` des symboles hors du hook, plans et specs passés) :

| Fichier | Usage | Devient |
|---|---|---|
| `settings/base.json:30` | lance `bash ~/.claude/main-guard-hook.sh` | inchangé |
| `tests/test_main_guard.sh` | appelle le script par son chemin | réécrit (tâche 2) |
| `tests/test_main_guard_track.sh` | réutilise `make_repo`, `guard` | caractérisation ajoutée (tâche 1), trois tests au push (tâche 2) |
| `CLAUDE.md:10` | décrit le comportement | réécrit (tâche 3) |
| `CLAUDE.md:11` | règle des hooks qui lisent le shell | inchangé |
| `docs/domaine.md` « Garde de main » | glossaire (`violates`, `switched_to`, `flatten_plain`, `stack`, `ctx`) | mis à jour (tâche 3) |
| `global/skills/pr/push.md:6-9` | rattrape un commit sur main | inchangé |

---

### Task 1 : Caractérisation des cas de push gardés

**Spec :** §5, §4 (cas combinés Suivi × séparateur, Préfixe × push, Lecture × suivi).

**Files:**
- Modify: `tests/test_main_guard_track.sh` (ajout en fin de fichier)

**Interfaces:**
- Consumes : `make_repo`, `guard`, `GUARD_REPO` de `tests/test_main_guard.sh` ; `assert_eq`, `SANDBOX`, `HOME` de
  `tests/helpers.sh`.
- Produces : trois fonctions de test que la tâche 2 ne touche pas.

- [ ] **Step 1 : Ajouter les tests en fin de `tests/test_main_guard_track.sh`**

```bash
# Caractérisation des cas de push gardés (issue #111), verts avant et après la réduction du hook.
test_guard_keeps_push_through_cd() {
  make_repo
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  assert_eq "$(guard 'cd ../wt && git push')" allow "cd && push"
  assert_eq "$(guard $'cd ../wt &&\ngit push')" allow "&& en fin de ligne"
  assert_eq "$(guard 'cd ../wt; git push')" deny "cd ; push"
  assert_eq "$(guard 'cd ../wt || git push')" deny "cd || push"
  assert_eq "$(guard 'cd ../wt && { git push; }')" allow "{ } après cd"
  assert_eq "$(guard 'cd ../wt && git commit -m "a; b" && git push')" allow "; entre guillemets"
  assert_eq "$(guard $'cd ../wt && git commit -m "titre\n\ncorps" && git push')" allow "saut de ligne entre guillemets"
  assert_eq "$(guard 'git -C ../wt push')" allow "-C vers le worktree"
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'git -C ../work push')" deny "-C vers main"
  assert_eq "$(guard 'cd ../work && git push')" deny "cd vers main"
}

test_guard_keeps_push_through_switch() {
  make_repo
  mkdir "$GUARD_REPO/sub"
  assert_eq "$(guard 'git switch -c z && git push -u origin HEAD')" allow "switch -c && push HEAD"
  assert_eq "$(guard 'git switch -c z && cd sub && git push')" allow "sous-dossier du dépôt"
  assert_eq "$(guard 'git switch -c z && git switch main && git push')" deny "retour sur main"
  assert_eq "$(guard 'git switch -c z; git push')" deny "switch ; push"
}

test_guard_keeps_push_prefixes() {
  make_repo
  assert_eq "$(guard 'rtk git push')" deny "rtk"
  assert_eq "$(guard 'sudo git push')" deny "sudo"
  assert_eq "$(guard 'X=1 git push')" deny "variable"
  assert_eq "$(guard '/usr/bin/git push')" deny "chemin"
  assert_eq "$(guard 'echo git push')" allow "echo"
}
```

- [ ] **Step 2 : Les lancer sur le hook actuel**

```bash
bash tests/run.sh keeps_push
```

Expected : `3 réussi(s), 0 échec(s)`. Caractérisation : pas de rouge attendu, le hook n'est pas modifié. Un échec
signifie que le hook actuel ne fait pas ce que la spec dit garder : s'arrêter et le rapporter (NEEDS_CONTEXT).

- [ ] **Step 3 : Commit**

```bash
git add tests/test_main_guard_track.sh
git commit -m "✅ hooks: Pin the main-guard push cases kept by #111

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 2 : Ne juger que le push, suivi et lecture réduits

**Spec :** R1, R2, R3, R4, R5, §4, §7.

**Files:**
- Modify: `global/main-guard-hook.sh` (réécrit en entier)
- Modify: `tests/test_main_guard.sh` (réécrit en entier)
- Modify: `tests/test_main_guard_track.sh:10-11,17,29` (trois tests passent du commit au push)

**Interfaces:**
- Consumes : tests de la tâche 1 (inchangés, doivent rester verts).
- Produces : fonctions `branch_of`, `resolve`, `parse`, `git_option`, `track`, `track_cd`, `track_switch`,
  `switch_arg`, `pushes_main`, `push_arg`, `deny`, `flatten`, `emit`, `in_quote`, `in_code`, `amp`, `skip_comment` ;
  variables `here`, `switched_dir`, `switched_to`, `forks`, `quotes`, `quote`, `flat`. La tâche 3 cite `pushes_main`,
  `switched_to`, `switched_dir`, `quote`, `flatten`.

Tests existants que la tâche rend faux, réécrits ou retirés par la réécriture de `tests/test_main_guard.sh` :
`test_guard_denies_commit_on_main` (devient `test_guard_allows_commit_on_main`), `test_guard_treats_newline_as_semicolon`
(devient `test_guard_reads_lines_and_comments`), `test_guard_tracks_nested_quotes` et
`test_guard_tracks_backticks_params_and_delimiters` (retirés : `$'…'`, `${…}`, délimiteurs de heredoc et `\r` ne sont
plus lus, R4), et tous les cas `git commit` des autres tests (passés au push, même décision sauf ceux de R2). Dans
`tests/test_main_guard_track.sh` : `test_guard_track_reads_dash_c_of_switch`, `test_guard_track_skips_prefix_of_cd`,
`test_guard_forgets_previous_segment`.

- [ ] **Step 1 : Réécrire `tests/test_main_guard.sh`**

```bash
# shellcheck shell=bash
# shellcheck disable=SC2154

# Dépôt jetable sur main, avec une branche feat/x.
make_repo() {
  GUARD_REPO="$SANDBOX/work"
  git init -q -b main "$GUARD_REPO"
  git -C "$GUARD_REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  git -C "$GUARD_REPO" branch feat/x
}

# Sans sortie, le hook laisse passer.
guard() {
  local out
  out="$(guard_raw "$1")"
  echo "${out:-allow}"
}

guard_raw() {
  jq -nc --arg c "$1" --arg d "$GUARD_REPO" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' \
    | bash "$REPO/global/main-guard-hook.sh" | jq -r '.hookSpecificOutput.permissionDecision'
}

test_guard_allows_commit_on_main() {
  make_repo
  assert_eq "$(guard 'git add -A && rtk git commit -m "x y"')" allow "commit"
  assert_eq "$(guard $'cat > f <<\'EOF\'\ngit commit -m x\nEOF')" allow "git commit dans un heredoc"
}

test_guard_denies_push_of_main() {
  make_repo
  assert_eq "$(guard 'git push')" deny "push"
  assert_eq "$(guard 'git push origin HEAD')" deny "push HEAD"
  assert_eq "$(guard 'git push origin +HEAD')" deny "push +HEAD"
  assert_eq "$(guard 'git -c a=b push origin main')" deny "push main"
  assert_eq "$(guard 'git push -f origin main')" deny "-f"
  assert_eq "$(guard 'git push origin +main')" deny "+main"
  assert_eq "$(guard 'git push origin feat/x:main')" deny "src:main"
  assert_eq "$(guard 'git push origin x:refs/heads/main')" deny "refs/heads/main"
  assert_eq "$(guard 'git push origin a b main')" deny "plusieurs refspecs"
  assert_eq "$(guard 'git push origin - main')" deny "- main"
}

test_guard_closes_push_holes() {
  make_repo
  assert_eq "$(guard 'git push origin "main"')" deny "main entre guillemets"
  assert_eq "$(guard 'git push --tags origin main')" deny "--tags avec refspec"
  assert_eq "$(guard 'git push origin --delete main')" deny "--delete main"
  assert_eq "$(guard 'git push -d origin main')" deny "-d main"
  assert_eq "$(guard 'git push -o ci.skip origin')" deny "-o et sa valeur"
  assert_eq "$(guard 'git push --push-option ci.skip origin')" deny "--push-option et sa valeur"
  assert_eq "$(guard 'git push --all origin')" deny "--all"
  assert_eq "$(guard 'git push --mirror origin')" deny "--mirror"
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'git push --mirror origin')" deny "--mirror depuis le worktree"
}

test_guard_allows_branch_tag_and_delete_from_main() {
  make_repo
  assert_eq "$(guard 'git push -u origin feat/x')" allow "branche"
  assert_eq "$(guard 'git push origin v1.2.0')" allow "tag"
  assert_eq "$(guard 'git push --tags')" allow "--tags sans refspec"
  assert_eq "$(guard 'git push origin --delete feat/x')" allow "delete"
  assert_eq "$(guard 'git push -o ci.skip origin feat/x')" allow "-o vers une branche"
  assert_eq "$(guard 'git status')" allow "status"
}

test_guard_on_feature_branch() {
  make_repo
  git -C "$GUARD_REPO" switch -q feat/x
  assert_eq "$(guard 'git commit -m x && git push')" allow "commit et push"
  assert_eq "$(guard 'git push origin HEAD:main')" deny "push vers main"
  assert_eq "$(guard 'git push --all origin')" deny "--all depuis une branche"
}

test_guard_uses_dash_c_directory() {
  make_repo
  git -C "$GUARD_REPO" switch -q feat/x
  git init -q -b main "$SANDBOX/other"
  assert_eq "$(guard 'git -C ../other push')" deny "-C"
}

test_guard_judges_only_git_commands() {
  make_repo
  assert_eq "$(guard 'grep -rn git push .')" allow "grep"
  assert_eq "$(guard 'GIT_TRACE=1 git push')" deny "variable"
}

test_guard_follows_cd() {
  make_repo
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  assert_eq "$(guard "cd \"$SANDBOX/wt\" && git add -A && git push")" allow "cd vers un worktree de branche"
  assert_eq "$(guard 'cd ../wt | cat; git push')" deny "cd dans un pipeline"
  assert_eq "$(guard 'false && cd ../wt; git push')" deny "cd sauté"
  assert_eq "$(guard "cd $SANDBOX/wt && cd $GUARD_REPO && git push")" deny "retour sur main"
  ln -s "$SANDBOX/wt" "$HOME/wt"
  assert_eq "$(guard 'cd ~/wt && git push')" allow "cd ~"
  assert_eq "$(guard 'cd -P ../wt && git push')" allow "option de cd"
  assert_eq "$(guard 'pushd ../wt && git push')" allow "pushd"
  assert_eq "$(guard "cd ../wt && cd -- $GUARD_REPO && git push")" deny "cd -- vers main"
}

test_guard_reads_lines_and_comments() {
  make_repo
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  assert_eq "$(guard $'cd ../wt\ngit push')" deny "cd puis saut de ligne"
  assert_eq "$(guard $'cd ../wt && \\\ngit add . && \\\ngit push')" allow "suite de ligne par \\"
  assert_eq "$(guard $'git \\\n  push')" deny "commande coupée par \\"
  assert_eq "$(guard $'cd ../wt && # va dans l\'arbre\ngit push')" allow "commentaire avec apostrophe"
  assert_eq "$(guard 'echo a#b; git push')" deny "# dans un mot : pas un commentaire"
  assert_eq "$(guard $'git switch -c feat/y && git commit -m "$(cat <<\'EOF\'\ntitre\n\nl\'appel; a | b\nEOF\n)" && git push -u origin HEAD')" allow "message par \$(cat <<'EOF')"
  assert_eq "$(guard $'cat > f <<\'EOF\'\nl\'erreur\nEOF\ngit push')" deny "apostrophe seule dans un heredoc : repli"
  assert_eq "$(guard 'echo "a; git push')" deny "guillemet seul : repli"
}

test_guard_splits_on_background_and_groups() {
  make_repo
  assert_eq "$(guard 'true & git push')" deny "& seul"
  assert_eq "$(guard 'git log |& git push')" deny "|&"
  assert_eq "$(guard '(git push)')" deny "( )"
  # shellcheck disable=SC2016 # commande littérale
  assert_eq "$(guard 'x=$(git push)')" deny "\$( ) hors guillemets"
  # shellcheck disable=SC2016 # commande littérale
  assert_eq "$(guard 'echo `git push`')" deny "backticks hors guillemets"
  assert_eq "$(guard '{ git push; }')" deny "{ }"
  assert_eq "$(guard 'if true; then git push; fi')" deny "if/then"
  assert_eq "$(guard '(cd ../wt) && git push')" deny "cd dans un sous-shell"
  assert_eq "$(guard 'git log 2>&1 | head && git status &>/dev/null')" allow "redirections avec &"
  assert_eq "$(guard $'echo "\ntrue & git push')" deny "& en repli"
  assert_eq "$(guard 'echo a\>& git push')" deny "\\> n'est pas une redirection : & sépare"
}

test_guard_shortcuts_show_their_limit() {
  make_repo
  # shellcheck disable=SC2016 # $W reste littéral : chemin calculé
  assert_eq "$(guard 'cd "$W" && git push')" deny "cd non résolu : dossier de départ"
  # shellcheck disable=SC2016 # commande littérale
  assert_eq "$(guard 'echo "$(git push)"')" allow "\$( ) entre guillemets doubles non jugé"
  # shellcheck disable=SC2016 # commande littérale
  assert_eq "$(guard 'echo "$(printf "%s" "l'\''a")" && git push && echo "$(printf "%s" "c'\''est")"')" allow "apostrophes dans \$( ) entre guillemets : commande cachée"
  assert_eq "$(guard $'cat > f <<EOF\ngit push\nEOF')" deny "ligne de heredoc jugée"
  assert_eq "$(guard $'cat > f <<EOF\nl\'un\nEOF\ngit push\ncat > g <<EOF\nl\'autre\nEOF')" allow "deux apostrophes de heredoc cachent une ligne"
  git -C "$GUARD_REPO" switch -q feat/x
  assert_eq "$(guard 'git switch main; git push')" allow "après ; branche réelle"
  git -C "$GUARD_REPO" config branch.feat/x.remote origin
  git -C "$GUARD_REPO" config branch.feat/x.merge refs/heads/main
  git -C "$GUARD_REPO" config push.default upstream
  assert_eq "$(guard 'git push')" allow "upstream main non vu"
}

test_guard_caps_forks_not_lines() {
  make_repo
  local c
  c="$(printf 'git status; %.0s' {1..2001})git status"
  assert_eq "$(guard "$c")" deny "plus de 2000 git"
  c="cat > f <<'EOF'"$'\n'"$(printf 'l\n%.0s' {1..2500})"$'\nEOF'
  assert_eq "$(guard "$c")" allow "2500 lignes de heredoc sans git"
}

test_guard_refuses_unreadable_input() {
  make_repo
  local code=0
  echo 'pas du json' | bash "$REPO/global/main-guard-hook.sh" 2>/dev/null || code=$?
  assert_eq "$code" 2 "JSON invalide : refus (exit 2)"
}

test_guard_follows_switch_in_same_command() {
  make_repo
  assert_eq "$(guard 'git switch -q -c feat/y origin/main && git add . && git push')" allow "switch -c"
  assert_eq "$(guard 'git checkout -b feat/y && git push -u origin HEAD')" allow "checkout -b"
  assert_eq "$(guard 'git checkout -qb feat/y && git push')" allow "options courtes collées"
  assert_eq "$(guard 'git switch -c feat/y || git push')" deny "switch suivi de ||"
  assert_eq "$(guard 'git switch -c feat/y && git checkout main && git push')" deny "checkout main"
  assert_eq "$(guard 'git switch -c feat/y && git switch - && git push')" deny "switch - : inconnue"
  assert_eq "$(guard 'git switch -c feat/y && git checkout README.md && git push')" deny "checkout d'un fichier : inconnue"
  assert_eq "$(guard 'git switch feat/x && git push')" deny "switch vers une branche existante : inconnue"
  assert_eq "$(guard 'git switch -c feat/y && git add . ; git push')" deny "; plus loin dans la chaîne"
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'git switch main && git push')" deny "switch main depuis le worktree"
  assert_eq "$(guard 'git checkout README.md && git push')" deny "checkout d'un fichier depuis le worktree : inconnue"
}
```

- [ ] **Step 2 : Passer au push les trois tests de `tests/test_main_guard_track.sh`**

Lignes 10-11 :

```bash
  assert_eq "$(guard 'git -C ../work push')" deny "push -C sur main"
  assert_eq "$(guard 'git -C ../work switch -c y && git -C ../work push')" allow "switch -C"
```

Ligne 17 :

```bash
  assert_eq "$(guard 'env cd ../wt && git push')" allow "env cd"
```

Ligne 29 :

```bash
  assert_eq "$(guard 'git switch -c y && git push; echo ok')" allow "segment non git après un push permis"
```

- [ ] **Step 3 : Voir le rouge**

```bash
bash tests/run.sh guard
```

Expected : six échecs, chacun sur sa première assertion fausse (relevé sur le hook actuel) :
- `test_guard_allows_commit_on_main` : « commit : attendu [allow], obtenu [deny] » ;
- `test_guard_closes_push_holes` : « main entre guillemets : attendu [deny], obtenu [allow] » ;
- `test_guard_follows_switch_in_same_command` : « checkout d'un fichier : inconnue : attendu [deny], obtenu [allow] » ;
- `test_guard_on_feature_branch` : « --all depuis une branche : attendu [deny], obtenu [allow] » ;
- `test_guard_shortcuts_show_their_limit` : « apostrophes dans $( ) entre guillemets : commande cachée : attendu
  [allow], obtenu [deny] » ;
- `test_guard_splits_on_background_and_groups` : « $( ) hors guillemets : attendu [deny], obtenu [allow] ».
Les trois tests de la tâche 1 restent verts. Noter ces échecs dans le rapport.

- [ ] **Step 4 : Réécrire `global/main-guard-hook.sh`**

Le fichier entier. La lecture (`flatten` et ses aides) n'est déterminée par aucun test pris seul : la recopier telle
quelle.

```bash
#!/usr/bin/env bash
# Hook PreToolUse (Bash) : refuse un push vers main (passer par /pr push) ; commit, tag, autre branche et --delete d'une autre branche passent.
# Segments lus dans l'ordre : cd/pushd <dir> et git switch/checkout reliés par && changent le dossier jugé et la branche prise des segments suivants.
# shortcut: cd non résolu ($VAR, $(…), cd -) jugé sur le dossier de départ ; résoudre les variables si ça gêne.
# shortcut: après ; || | ou saut de ligne, retour à la branche réelle (« git switch main; git push » passe) ; garder la branche prise si ça gêne.
# shortcut: $( ) et ` entre guillemets doubles non jugés, et leurs guillemets décalent la lecture (deux apostrophes y cachent une commande) ; suivre $( ) dans les guillemets si ça gêne.
# shortcut: lignes d'un heredoc jugées comme des commandes, et deux apostrophes du corps peuvent cacher une ligne ; suivre les heredocs si ça gêne.
# shortcut: guillemets déséquilibrés : repli, chaque séparateur coupe, guillemets ignorés ; vrai parseur shell si ça gêne.
# shortcut: push sans refspec vers un upstream main (push.default=upstream) non vu ; lire l'upstream si ça gêne.
set -uo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")" || { echo "main-guard : entrée illisible, appel refusé" >&2; exit 2; }
[[ -n "$cmd" ]] || exit 0
cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)"
cwd="${cwd:-$PWD}"
LC_ALL=C # lecture octet par octet

here="$cwd"                    # dossier jugé
switched_dir="" switched_to="" # branche prise par un git switch plus tôt (main si inconnue)
forks=0                        # plafond de processus (cd, pushd, git lus)
verb="" dir="" sub="" args=()  # segment lu par parse

branch_of() {
  [[ -n "$switched_to" && "$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" == "$switched_dir" ]] && { echo "$switched_to"; return; }
  git -C "$1" branch --show-current 2>/dev/null
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

# Branche créée par -c/-b, sinon inconnue, jugée comme main ; vaut pour tout le dépôt du switch.
track_switch() {
  local a create="" pos=()
  for a in "${args[@]}"; do switch_arg "$a"; done
  switched_dir="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)"
  switched_dir="${switched_dir:-$dir}" switched_to=main
  [[ -n "$create" ]] && switched_to="${pos[0]:-main}"
}

# Range un argument de switch ou checkout dans create ou pos, locaux de track_switch.
switch_arg() {
  case "$1" in
    -[bBcC] | -[!-]*[bBcC]*) create=1 ;; # -b, -c et options courtes collées (-qb)
    -*) ;;
    *) pos+=("$1") ;;
  esac
}

# Vrai si le segment pousse vers main.
pushes_main() {
  local i=0 pos=() flags=" " refs dests
  [[ "$sub" == push ]] || return 1
  while ((i < ${#args[@]})); do push_arg "${args[i]}"; ((i += $?)); done
  [[ "$flags" =~ \ (--all|--mirror)\  ]] && return 0
  ((${#pos[@]} > 1)) || { [[ "$flags" != *" --tags "* && "$(branch_of "$dir")" == main ]]; return; } # sans refspec : branche du dossier (prise ou réelle)
  refs=("${pos[@]:1}") && refs=("${refs[@]#+}") && dests=("${refs[@]##*:}")
  [[ " ${dests[*]} " =~ \ (main|refs/heads/main)\  ]] && return 0
  [[ " ${refs[*]} " == *" HEAD "* && "$(branch_of "$dir")" == main ]]
}

# Range un argument de push dans flags ou pos, locaux de pushes_main : code retour = mots lus (-o prend une valeur).
push_arg() {
  local a="${1//[\"\']/}"
  case "$a" in
    -o | --push-option) return 2 ;;
    -*) flags+="$a " ;;
    *) pos+=("$a") ;;
  esac
  return 1
}

deny() {
  jq -nc --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

# flatten écrit dans flat une ligne où seuls && || ; | séparent les segments (sed découpe ensuite). Entre guillemets,
# ⏎ ; & | deviennent des blancs. Hors guillemets : \⏎ recolle, # en début de mot commente, ⏎ vaut « ; » sauf après
# && || |, ( ) ` et & seul valent « ; », |& vaut |. quotes vide : repli, guillemets ignorés.
ch=()
while IFS= read -r -d '' -n1 c; do ch+=("$c"); done < <(printf '%s' "$cmd") # tableau lu une fois : ${cmd:k:1} serait quadratique
n=${#ch[@]}

flatten() { # 1 si un guillemet reste ouvert
  flat="" quote="" last="" word=1
  for ((k = 0; k < n; k++)); do
    if [[ -n "$quote" ]]; then in_quote "${ch[k]}"; else in_code "${ch[k]}"; fi
  done
  [[ -z "$quote" ]]
}

# last : deux derniers caractères non blancs écrits ; word : le prochain caractère commence un mot.
emit() {
  flat+="$1"
  [[ "$1" == [$' \t'] ]] || last="${last}$1" last="${last: -2}"
  if [[ "$1" == [$' \t;&|'] ]]; then word=1; else word=""; fi
}

in_quote() {
  local c="$1"
  if [[ "$c" == "$quote" ]]; then quote=""
  elif [[ "$quote$c" == "\"\\" ]]; then c="\\${ch[++k]:-}" # \" ne ferme pas
  fi
  emit "${c//[;&|$'\n']/ }"
}

in_code() {
  local c="$1" nxt="${ch[k + 1]:-}"
  case "$c" in
    \\) ((++k)); [[ "$nxt" == $'\n' ]] || emit "\\${nxt//[;&|>]/ }"; return ;; # \> n'est pas une redirection
    \" | \') quote="${quotes:+$c}" ;;
    \#) [[ -n "$word" ]] && { skip_comment; return; } ;;
    $'\n') if [[ "$last" == '&&' || "$last" == *'|' ]]; then c=" "; else c=";"; fi ;;
    \( | \) | \`) c=";" ;;
    \&) amp "$nxt"; return ;;
    \|) [[ "$nxt" == '&' ]] && ((++k)) ;; # |& vaut |
  esac
  emit "$c"
}

amp() { # & seul sépare (pas &&, &>, >&)
  if [[ "$1" == '&' ]]; then ((++k)) && emit '&&'
  elif [[ "$1" == '>' || "${flat: -1}" == '>' ]]; then emit '&'
  else emit ';'
  fi
}

skip_comment() { while ((k + 1 < n)) && [[ "${ch[k + 1]}" != $'\n' ]]; do ((k++)); done; }

quotes=1
flatten || { quotes=""; flatten; }

while IFS= read -r segment; do
  read -ra words <<<"$segment"
  sep=""
  [[ "${words[0]:-}" =~ ^(\&\&|\|\||;|\|)$ ]] && { sep="${words[0]}"; words=("${words[@]:1}"); }
  [[ -n "$sep" && "$sep" != "&&" ]] && here="$cwd" switched_dir="" switched_to="" # cd ou switch a pu échouer
  parse "${words[@]}"
  # 2 à 3 ms par processus : au-delà de 2000, le délai de 60 s du hook laisserait tout passer.
  [[ -n "$verb" ]] && ((++forks > 2000)) && deny "Plus de 2000 cd ou git dans la commande, trop long pour que main-guard la juge : découpe-la."
  track
  pushes_main && deny "Pas de push vers main : passe par /pr push, qui crée la branche et ouvre la PR."
done < <(sed -E 's/(&&|\|\||;|\|)/\n\1 /g' <<<"$flat")
```

- [ ] **Step 5 : Tests au vert**

```bash
bash tests/run.sh guard
```

Expected : `21 réussi(s), 0 échec(s)`.

- [ ] **Step 6 : Mesures**

```bash
wc -l < global/main-guard-hook.sh
awk 'length > 200' global/main-guard-hook.sh
grep -cF -e 'Pas de push vers main : passe par /pr push, qui crée la branche et ouvre la PR.' -e 'Plus de 2000 cd ou git dans la commande, trop long pour que main-guard la juge : découpe-la.' -e 'main-guard : entrée illisible, appel refusé' global/main-guard-hook.sh
grep -c '^# shortcut:' global/main-guard-hook.sh
```

Expected, dans l'ordre : au plus 200 (190 attendu) ; aucune ligne ; `3` ; `6`, chacun couvert par un cas de
`test_guard_shortcuts_show_their_limit` (cd non résolu ; après `;` branche réelle ; `$( )` entre guillemets, deux
cas ; heredoc, deux cas ; repli : « & en repli » et « apostrophe seule dans un heredoc » ailleurs ; upstream).

- [ ] **Step 7 : Liste des jugements**

Décision (relecture du plan) : la liste garde ces 8 commandes de push ; les autres cas combinés de push
(`cd ../wt || git push`, `git switch -c z; git push`, préfixes) sont figés par la tâche 1. La spec (§4, Mesures)
est reformulée dans le même commit.

Comparer le hook de `main` et celui de la branche sur les 50 commandes de la PR #110 et 8 commandes de push
(R2, R3, suivi), depuis le dépôt sur main et depuis un worktree sur `feat/x` (116 jugements). Script à écrire dans le
dossier de suivi `.superpowers/sdd/main-guard-push-only/jugements.sh` (ignoré par git), lancé contre une copie du
hook de `main` (le script le relit à chaque commande : pas de `<( )`) :

```bash
git show main:global/main-guard-hook.sh > .superpowers/sdd/main-guard-push-only/old-hook.sh
bash .superpowers/sdd/main-guard-push-only/jugements.sh .superpowers/sdd/main-guard-push-only/old-hook.sh global/main-guard-hook.sh
```

Contenu du script :

```bash
#!/usr/bin/env bash
# Compare les décisions de deux versions du hook : diff-guard.sh <ancien> <nouveau>
set -u; r=(); n=0 deny=0 bad=0
old="$1" new="$2"
d="$(mktemp -d)"
git init -q -b main "$d/work"
t=$(git -C "$d/work" commit-tree "$(git -C "$d/work" write-tree)" -m init)
git -C "$d/work" update-ref refs/heads/main "$t"
git -C "$d/work" branch feat/x
git -C "$d/work" branch y
git -C "$d/work" worktree add -q "$d/wt" feat/x
cmds=(
  'git push' 'git push origin main' 'git push origin HEAD' 'git push -u origin feat/x' 'git push origin v1'
  'git push origin --delete main' 'git push -d origin main' 'git push --tags origin main' 'git push origin +main'
  'git push origin feat/x:main' 'git push origin x:refs/heads/main' 'git push origin +HEAD' 'git push origin a b main'
  'git push origin x:HEAD' 'git push -f origin main' 'git push origin - main' 'git commit -m x' 'git -C ../wt commit -m x'
  'git -C ../work commit -m x' 'git -c a=b commit' 'git --no-pager commit' 'git -C commit'
  'git switch -c z && git commit' 'git switch -qc z && git commit' 'git switch -bq z && git commit' 'git checkout -b z && git commit'
  'git checkout main && git commit' 'git checkout file.txt && git commit' 'git checkout y && git commit'
  'git switch y && git switch - && git commit' 'git switch - && git commit' 'git checkout @{-1} && git commit'
  'git switch main && git commit' 'git switch -f main && git commit' 'git switch -c z; git commit' 'git switch -c z || git commit'
  'git -C ../wt switch main && git -C ../wt commit' 'git -C ../wt switch -c q && git commit'
  'cd ../wt && git commit' 'cd ../wt && git push origin HEAD' 'cd ../wt; git commit' 'env cd ../wt && git commit'
  'git switch -c z && git push origin HEAD' 'git switch -c z && git push' 'git switch y && git push origin HEAD:main'
  'rtk git commit' 'echo git commit' 'sudo git push' 'X=1 git commit' 'git status; git commit'
  'git switch main && git push' 'git switch feat/x && git push' 'git checkout - && git push' 'git push origin "main"'
  'git push -o ci.skip origin' 'git push --all origin' 'cd ../wt; git push' 'cd ../work && git push'
)
for c in "${cmds[@]}"; do
  for cwd in "$d/work" "$d/wt"; do
    j=$(jq -nc --arg c "$c" --arg d "$cwd" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}')
    a=$(bash "$old" <<<"$j" | jq -r '.hookSpecificOutput.permissionDecision // empty'); a=${a:-allow}
    b=$(bash "$new" <<<"$j" | jq -r '.hookSpecificOutput.permissionDecision // empty'); b=${b:-allow}
    [[ "$a" != "$b" ]] && { bad=$((bad + 1)); a="$a→$b"; }

    n=$((n + 1)); [[ "$a" == deny ]] && deny=$((deny + 1))
    r+=("$a"); [[ ${#r[@]} == 2 ]] && { printf "%s\t%s\t%s\n" "$c" "${r[0]}" "${r[1]}"; r=(); }
  done
done
echo "$n jugements, ${deny:-0} refus, ${bad:-0} écart(s)"
rm -rf "$d"
```

Expected : dernière ligne `116 jugements, 26 refus, 37 écart(s)`. Chaque écart est l'un de ceux-ci, et rien
d'autre :
- `→allow` sur une commande `git commit` (R1) ;
- `allow→deny` sur `--delete main`, `-d … main`, `--tags origin main`, `"main"` (R3), `--all` depuis le worktree
  (R3), `git switch feat/x && git push` et `git checkout - && git push` (R2, branche inconnue), `-o ci.skip origin`
  depuis main (R3).
Sortie écrite dans `.superpowers/sdd/main-guard-push-only/jugements.md` (tableau commande | depuis main | depuis le
worktree), reprise dans la description de la PR.

- [ ] **Step 8 : Suite complète**

```bash
bash tests/run.sh # timeout: 580000
```

Expected : `0 échec(s)`, `PASS  shellcheck`.

- [ ] **Step 9 : Commit**

```bash
git add global/main-guard-hook.sh tests/test_main_guard.sh tests/test_main_guard_track.sh
git commit -m "♻️ hooks: Judge only pushes to main in main-guard

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 3 : Documentation

**Spec :** — (R6).

**Files:**
- Modify: `CLAUDE.md:10`
- Modify: `docs/domaine.md` (contexte « Garde de main », lignes 88-107)

**Interfaces:**
- Consumes : noms de la tâche 2 (`pushes_main`, `switched_to`, `switched_dir`, `quote`, `flatten`, `quotes`).

- [ ] **Step 1 : Remplacer la ligne 10 de `CLAUDE.md`** (Edit, pas `sed`)

```markdown
- Le hook « main-guard » refuse un push vers main tapé dans un appel Bash : refspec de destination `main` (y compris `--delete`, `--tags` avec refspec, `"main"`), `--all`/`--mirror`, ou push sans refspec ou vers `HEAD` depuis main. Un commit sur main passe : `/pr push` le rattrape. Il suit les `cd <dossier>` (options et `pushd` compris) et les `git switch -c` reliés par `&&` à la suite de l'appel (après `;`, `||`, `|` ou un saut de ligne hors guillemets, il revient au dossier et à la branche de départ) ; un autre `switch`/`checkout` rend la branche inconnue, jugée comme main. Un `cd` qu'il ne résout pas (`cd $W`, `cd -`) est jugé sur le dossier de départ. Il ne suit que les guillemets simples et doubles : une ligne de heredoc, ou de texte aux guillemets déséquilibrés, qui commence par `git push` vers main peut être refusée, l'écrire dans un fichier avec Write. Depuis le dépôt principal sur main, pousser un worktree passe par `git -C <worktree> push`, jamais par `cd <worktree> && …` : un `;` plus loin dans l'appel ramène au dossier de départ.
```

- [ ] **Step 2 : Mettre à jour `docs/domaine.md`, contexte « Garde de main »** (Edit)

Ligne « Responsabilité » : remplacer « un appel Bash qui commite sur main ou pousse vers main » par « un appel Bash
qui pousse vers main ».

Lignes du tableau à remplacer (les autres restent) :

```markdown
| Segment | Commande simple de l'appel, entre deux séparateurs `&&` `\|\|` `;` `\|` ; hors guillemets, un saut de ligne, `(` `)`, un backtick et `&` seul valent `;` | `segment`, `words` | ligne, instruction |
| Jugement | Réponse oui ou non : le segment pousse vers main | `pushes_main` | vérification, contrôle |
| Branche prise | Branche qu'un `git switch` ou `checkout` relié par `&&` a donnée à un dépôt, à la place de sa branche réelle : celle qu'il crée (`-c`, `-b`), sinon une branche inconnue, jugée comme main | `switched_to`, `switched_dir` | branche courante |
| Contexte de lecture | Guillemet simple ou double ouvert à l'endroit lu ; `$( )`, `${…}`, backticks et heredocs ne sont pas suivis | `quote` | contexte (seul) |
| Repli | Lecture de secours quand un guillemet reste ouvert : guillemets ignorés, chaque séparateur coupe | `flatten` avec `quotes` vide | mode dégradé |
| Push vers main | `git push` qui met à jour la branche main du dépôt distant : refspec de destination `main` (`--delete` de main compris), `--all`/`--mirror` depuis n'importe quelle branche, ou sans refspec ou `HEAD` depuis la branche main. Seul risque que rien ne rattrape, faute de protection de branche côté GitHub | `pushes_main` | push sur main (ambigu avec un push lancé depuis main) |
| Faux refus | Refus d'un appel qui ne pousse pas vers main (`cd <worktree> && git push`, `git switch -c x && git push -u origin HEAD`) | — | contournement |
```

Invariants, remplacer la ligne par :

```markdown
Invariants : un `cd` ou un switch ne compte que suivi de `&&` ; un chemin non résolu vaut le dossier de départ ; un switch qui ne crée pas de branche la rend inconnue, jugée comme main ; entrée illisible ou plafond dépassé = refus, jamais passage sans jugement ; un commit, le push d'un tag, d'une autre branche et `--delete` d'une autre branche restent permis depuis main.
```

- [ ] **Step 3 : Grep des termes retirés**

```bash
git grep -n -E 'violates|flatten_plain|previous_branch|heredoc_bodies|in_string|commit-tree|plomberie|commite sur main' -- ':!docs/superpowers/plans' ':!docs/superpowers/specs'
git grep -n -E '`(stack|ctx)`' docs/domaine.md
```

Expected : aucune ligne pour l'une comme pour l'autre.

- [ ] **Step 4 : Suite complète**

```bash
bash tests/run.sh # timeout: 580000
```

Expected : `0 échec(s)`, `PASS  shellcheck`.

- [ ] **Step 5 : Commit**

```bash
git add CLAUDE.md docs/domaine.md
git commit -m "📝 hooks: Describe main-guard as a push-only guard

Co-Authored-By: <modèle de l'implémenteur>"
```

## Convergence 1

### Task 4 : Cas du repli dans `test_guard_shortcuts_show_their_limit`

**Spec :** §4 Mesures (chaque `shortcut:` restant a un test qui montre la limite), R4 ; Global Constraints.

**Files:**
- Modify: `tests/test_main_guard.sh` (fonction `test_guard_shortcuts_show_their_limit`)

Le shortcut « guillemets déséquilibrés : repli » n'a de cas que dans d'autres tests. Le cas ajouté montre le faux
refus : sans l'apostrophe finale, la commande passe (« ; entre guillemets », tâche 1) ; avec elle, la lecture se
replie, le `;` entre guillemets coupe et le `cd` est oublié. Le worktree porte une branche neuve `feat/w` : la suite
du test extrait `feat/x` dans le dépôt principal.

- [ ] **Step 1 : Ajouter le cas, juste après `make_repo` dans `test_guard_shortcuts_show_their_limit`**

```bash
  git -C "$GUARD_REPO" worktree add -q -b feat/w "$SANDBOX/wt"
  assert_eq "$(guard $'cd ../wt && git commit -m "a; b" && git push && echo l\'x')" deny "guillemet seul : repli, ; entre guillemets coupe"
```

- [ ] **Step 2 : Tests**

```bash
bash tests/run.sh guard
```

Expected : `21 réussi(s), 0 échec(s)`. Pas de rouge : le cas fige une limite du hook livré à la tâche 2. Preuve que
le cas montre la limite : la même commande sans ` && echo l'x` passe (`allow`), à relever dans le rapport.

- [ ] **Step 3 : Commit**

```bash
git add tests/test_main_guard.sh
git commit -m "✅ hooks: Show the main-guard fallback limit in its shortcut test

Co-Authored-By: <modèle de l'implémenteur>"
```

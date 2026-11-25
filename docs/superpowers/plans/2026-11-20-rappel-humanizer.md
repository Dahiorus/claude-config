# Rappel humanizer : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** un hook PreToolUse `Bash` refuse un point de publication (texte envoyé vers GitHub) tant que
`humanizer:humanizer` n'a pas été appelé depuis le dernier message tapé par l'utilisateur, sans réécrire l'appel.

**Architecture :** script autonome `global/humanizer-hook.sh` (relié à `~/.claude` par `install_links`), déclaré dans
`settings/base.json` après main-guard. Lecture par motif du texte de l'appel, lecture du transcript JSONL par jq.
Les skills qui publient un texte sans prose ou déjà approuvé reçoivent un marqueur.

**Tech Stack :** bash, jq, runner `tests/run.sh` (une fonction `test_*` par cas, bac à sable `$SANDBOX`), shellcheck.

**Spec :** `docs/superpowers/specs/2026-11-20-rappel-humanizer-design.md`

## Découpage en PR

Fichiers touchés hors tests, spec et plan : `global/humanizer-hook.sh`, `settings/base.json`,
`global/skills/pr/rebase.md`, `global/skills/pr/comments.md`, `global/skills/pr-risk/SKILL.md`, `docs/domaine.md`,
`docs/reste-a-faire.md` : 7, sous le seuil de ~15. **Une seule PR**, une seule story (P1).

## Table de traçabilité

| Exigence (§ spec) | Tâche | Test qui la prouve |
|---|---|---|
| §1 décision : refus avant l'envoi, raison qui cite la consigne et les marqueurs | 1 | `test_humanizer_denies_pr_create_without_passage` |
| §2 R1 passage récent : Skill `humanizer:humanizer` après le dernier message tapé | 1 | `test_humanizer_allows_after_passage`, `test_humanizer_passage_before_last_prompt_denied` |
| §2 R1 bornes exclues : `tool_result`, méta, notification | 1 | `test_humanizer_non_prompt_entries_are_not_a_bound` |
| §2 R1 sous-agent ne compte pas | 1 | `test_humanizer_sidechain_passage_ignored` |
| §2 points : `gh pr create` | 1 | `test_humanizer_denies_pr_create_without_passage` |
| §2 points : `gh pr edit` corps/titre, pas `--add-reviewer` | 1 | `test_humanizer_pr_edit_body_or_title_only` |
| §2 points : `gh pr comment`, `gh pr review -b/-F`, `gh api` qui écrit vers reviews/replies | 1 | `test_humanizer_denies_review_replies`, `test_humanizer_denies_pr_review_body` |
| §2 points : push forcé, `gh pr merge` | 1 | `test_humanizer_denies_force_push_and_merge` |
| §2 non-points (push simple, commit, lectures `gh api`) | 1 | `test_humanizer_silent_on_non_publication` |
| §2 un seul point dans un appel composé suffit ; continuation `\` | 1 | `test_humanizer_compound_call_denied`, `test_humanizer_line_continuation_denied` |
| §2 marqueurs `sans objet` / `déjà relu`, n'importe où ; marqueur inconnu refusé | 1 | `test_humanizer_markers`, `test_humanizer_marker_inside_script` |
| §4 texte approuvé après passage : marqueur `déjà relu` passe, sans marqueur refus | 1 | `test_humanizer_approved_text_needs_marker` |
| §2 fail-open (entrée invalide, transcript absent ou illisible) | 1 | `test_humanizer_fail_open` |
| §2 points ajoutés (#167) : `gh pr close --comment`, `gh api` qui écrit vers `…/comments`, option courte collée ou groupée | 4 | `test_humanizer_denies_pr_close_comment`, `test_humanizer_denies_api_comments`, `test_humanizer_denies_glued_short_options`, `test_humanizer_silent_on_non_publication` |
| §2 hook déclaré dans `base.json` après main-guard | 2 | `test_base_settings_humanizer_hook` |
| §2 `rebase.md` : marqueur `sans objet` au push forcé | 2 | grep (étape 2.4) |
| §2 `comments.md` : réponse proposée passée par humanizer avant d'être montrée, marqueur `déjà relu` à la publication après accord | 2 | grep (étape 2.4) |
| §2 `pr-risk` : marqueur `sans objet` au script | 2 | `test_humanizer_marker_inside_script` (forme du script) + grep (étape 2.4) |
| §2 `docs/domaine.md` aligné | 3 (—) | grep des termes retirés (étape 3.1) |
| §2 `docs/reste-a-faire.md` point 5 rayé | étape 5 du cycle | — |

Usages vérifiés (étape 1b) et ce qu'ils deviennent :

| Fichier | Usage | Devient | Test qui le fige |
|---|---|---|---|
| `global/skills/pr/squash.md:19` | `git push --force-with-lease` après un message passé par humanizer | inchangé, passe (passage récent) | `test_humanizer_allows_after_passage` |
| `global/skills/pr/rebase.md:11` | même push, sans texte | + marqueur `sans objet` | `test_humanizer_markers` |
| `global/skills/pr/merge.md:35` | `gh pr merge --rebase` | inchangé, humanizer déjà prescrit à l'étape 3 | `test_humanizer_denies_force_push_and_merge` |
| `global/skills/pr/push.md:12` (draft) | `gh pr create --draft`, puis `gh pr edit` de la section « État » | inchangé | `test_humanizer_denies_pr_create_without_passage`, `test_humanizer_pr_edit_body_or_title_only` |
| `global/skills/pr/push.md:49` | `gh pr create --body-file` | inchangé | `test_humanizer_denies_pr_create_without_passage` |
| `global/skills/pr/SKILL.md:123` | `gh pr edit --body-file` | inchangé | `test_humanizer_pr_edit_body_or_title_only` |
| `global/skills/pr/comments.md:35,38,44` | `…/replies -F body=@`, `gh pr comment`, `gh pr edit --add-reviewer` | marqueur `déjà relu` pour les réponses publiées après accord ; `--add-reviewer` passe | `test_humanizer_denies_review_replies`, `test_humanizer_pr_edit_body_or_title_only` |
| `global/skills/pr/review.md:13,79` | `gh api …/reviews --paginate` (lecture), `--input` (écriture) | inchangé : lecture passe, écriture précédée de humanizer | `test_humanizer_silent_on_non_publication`, `test_humanizer_denies_review_replies` |
| `global/skills/pr-risk/SKILL.md:230-236` | script `gh api …` puis `gh pr comment` | + ligne `# humanizer: sans objet` | `test_humanizer_marker_inside_script` |
| `settings/base.json` PreToolUse | bash-rewrite, main-guard, sonar Read | + entrée humanizer, les autres inchangées | `test_base_settings_humanizer_hook`, `test_base_settings_profile_hook` (existant) |

## Global Constraints

- Le hook ne réécrit jamais l'appel : jamais de `updatedInput` dans sa sortie (spec §2, invariant du glossaire).
- Refus = `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":…}}`.
- Silence = aucune sortie, code 0. Le hook sort toujours en code 0.
- Fail-open : jq absent, entrée invalide, `transcript_path` absent ou illisible → silence (spec §2).
- Marqueurs exacts : `# humanizer: sans objet` et `# humanizer: déjà relu`, n'importe où dans l'appel.
- Message tapé par l'utilisateur = entrée `type: "user"`, pas `isMeta`, sans bloc `tool_result`, et `origin.kind`
  absent ou égal à `"human"` (une notification a `origin.kind: "task-notification"`), et pas `isCompactSummary`
  (résumé écrit après une compaction). Entrées `isSidechain: true` ignorées.
- Passage = entrée `type: "assistant"` dont un bloc `tool_use` a `name: "Skill"` et `input.skill: "humanizer:humanizer"`.
- Tests shell : here-string (`<<<"$json"`) pour alimenter le hook, jamais `jq … | hook`
  (`test_tests_feed_scripts_by_here_string`, `tests/test_rules.sh`).
- `shellcheck` sur chaque script et test modifié avant de commiter.
- Texte des skills : lignes de 120 colonnes au plus, édition par Edit, jamais `sed -i`.
- Commits : gitmoji, sujet en français comme l'historique récent, fin par
  `Co-Authored-By: <modèle de l'implémenteur>`.

## Review Focus

1. Transcript de plusieurs Mo : jq le lit en flux (`-R 'fromjson?'`), une ligne JSON invalide ne fait pas échouer
   la lecture → couvert par `test_humanizer_fail_open` (ligne invalide au milieu, passage après elle compté).
2. Corps de texte qui **contient** les mots d'un point (`--body "lancer gh pr merge ensuite"` dans un `git commit -m`)
   → faux refus accepté par la spec (coût : un appel au skill) ; pas de test, limite en `shortcut:`.
3. `gh api` vers `…/reviews` avec `-F` pour une lecture paginée filtrée : refusé (faux refus) ; la seule lecture des
   skills est `--paginate` sans champ → couverte par `test_humanizer_silent_on_non_publication`.
4. Préfixe `rtk` (réécrit par bash-rewrite) et `git -C <dossier> push --force-with-lease` → couverts par
   `test_humanizer_pr_edit_body_or_title_only` et `test_humanizer_denies_force_push_and_merge`.
5. `/humanizer:humanizer` tapé par l'utilisateur (pas un appel de l'outil `Skill`) : non compté, refus ; limite en
   `shortcut:`, pas de test.

---

### Task 1 : hook `humanizer-hook.sh`

§ spec : §1 (décision), §2 R1 (points, passage récent, refus, marqueurs, fail-open), §4 (tous les critères).

**Files :**
- Create : `global/humanizer-hook.sh`
- Test : `tests/test_humanizer_hook.sh` (nouveau)

**Interfaces :**
- Produit : `bash ~/.claude/humanizer-hook.sh`, entrée JSON PreToolUse sur stdin (`tool_input.command`,
  `transcript_path`), sortie vide ou refus (Global Constraints).

- [ ] **Step 1 : écrire les tests** (rouge attendu : le script n'existe pas, chaque test échoue sur `bash: … No such
  file`)

`tests/test_humanizer_hook.sh`

```bash
# shellcheck shell=bash
# shellcheck disable=SC2154

# Lignes de transcript JSONL.
t_prompt() { jq -nc --arg t "$1" '{type:"user",origin:{kind:"human"},message:{role:"user",content:$t}}'; }
t_humanizer() { jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"humanizer:humanizer"}}]}}'; }
t_tool_result() { jq -nc '{type:"user",message:{content:[{type:"tool_result",content:"ok"}]}}'; }
t_meta() { jq -nc '{type:"user",isMeta:true,message:{content:[{type:"text",text:"Base directory for this skill"}]}}'; }
t_notification() { jq -nc '{type:"user",origin:{kind:"task-notification"},message:{content:"<task-notification>"}}'; }
t_compact() { jq -nc '{type:"user",isCompactSummary:true,message:{content:"This session is being continued"}}'; }

# Écrit les lignes données (sorties de t_*) dans le transcript du bac à sable.
transcript() { printf '%s\n' "$@" >"$SANDBOX/t.jsonl"; }

# run_humanizer <commande> : sortie du hook, transcript du bac à sable.
run_humanizer() {
  local json
  json="$(jq -nc --arg c "$1" --arg t "$SANDBOX/t.jsonl" \
    '{tool_name:"Bash",transcript_path:$t,tool_input:{command:$c}}')"
  bash "$REPO/global/humanizer-hook.sh" <<<"$json"
}

decision() { run_humanizer "$1" | jq -r '.hookSpecificOutput.permissionDecision // "silence"'; }

test_humanizer_denies_pr_create_without_passage() {
  transcript "$(t_prompt '/pr push')"
  local out
  out="$(run_humanizer 'gh pr create --title "x" --body-file /tmp/b.md')"
  assert_eq "$(jq -r .hookSpecificOutput.permissionDecision <<<"$out")" "deny" "décision"
  local reason
  reason="$(jq -r .hookSpecificOutput.permissionDecisionReason <<<"$out")"
  assert_contains "$reason" "humanizer:humanizer"
  assert_contains "$reason" "# humanizer: sans objet"
  assert_contains "$reason" "# humanizer: déjà relu"
  assert_eq "$(jq -r '.hookSpecificOutput.updatedInput // "absent"' <<<"$out")" "absent" "pas de réécriture"
}

test_humanizer_allows_after_passage() {
  transcript "$(t_prompt '/pr push')" "$(t_humanizer)"
  assert_eq "$(decision 'gh pr create --body-file /tmp/b.md')" "silence" "create"
  assert_eq "$(decision 'git push --force-with-lease=b:abc origin b')" "silence" "squash"
}

test_humanizer_passage_before_last_prompt_denied() {
  transcript "$(t_prompt a)" "$(t_humanizer)" "$(t_prompt b)"
  assert_eq "$(decision 'gh pr create --body-file f')" "deny" "passage antérieur au message"
}

test_humanizer_non_prompt_entries_are_not_a_bound() {
  transcript "$(t_prompt a)" "$(t_tool_result)" "$(t_meta)" "$(t_humanizer)" "$(t_tool_result)" "$(t_meta)" \
    "$(t_notification)" "$(t_compact)"
  assert_eq "$(decision 'gh pr create --body-file f')" "silence" "seul un message tapé borne"
}

test_humanizer_sidechain_passage_ignored() {
  transcript "$(t_prompt a)" "$(t_humanizer | jq -c '.isSidechain = true')"
  assert_eq "$(decision 'gh pr create --body-file f')" "deny" "passage d'un sous-agent"
}

test_humanizer_pr_edit_body_or_title_only() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'rtk gh pr edit 12 --body-file f')" "deny" "--body-file"
  assert_eq "$(decision 'gh pr edit 12 --body "x"')" "deny" "--body"
  assert_eq "$(decision 'gh pr edit 12 -t "Titre"')" "deny" "-t"
  assert_eq "$(decision 'gh pr edit 12 --title "Titre"')" "deny" "--title"
  assert_eq "$(decision 'gh pr edit 12 --add-reviewer bob')" "silence" "--add-reviewer"
}

test_humanizer_denies_review_replies() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'gh pr comment 12 --body-file f')" "deny" "comment"
  assert_eq "$(decision 'gh api repos/o/r/pulls/12/comments/34/replies -F body=@f')" "deny" "replies"
  assert_eq "$(decision 'gh api repos/o/r/pulls/12/reviews --input f')" "deny" "reviews --input"
  assert_eq "$(decision 'gh api -X POST repos/o/r/pulls/12/reviews -f event=COMMENT')" "deny" "reviews -X POST"
}

test_humanizer_denies_pr_review_body() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'gh pr review 12 --comment -b "x"')" "deny" "-b"
  assert_eq "$(decision 'gh pr review 12 --approve --body-file f')" "deny" "--body-file"
  assert_eq "$(decision 'gh pr review 12 --approve')" "silence" "sans corps"
}

test_humanizer_denies_force_push_and_merge() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'git push --force-with-lease=b:abc origin b')" "deny" "push forcé"
  assert_eq "$(decision 'git -C ../wt push --force-with-lease=b:abc origin b')" "deny" "git -C"
  assert_eq "$(decision 'gh pr merge 12 --rebase')" "deny" "merge"
}

test_humanizer_silent_on_non_publication() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'git push origin feat/x')" "silence" "push simple"
  assert_eq "$(decision 'git commit -m wip')" "silence" "commit"
  assert_eq "$(decision 'gh pr view 12')" "silence" "view"
  assert_eq "$(decision 'gh api repos/o/r/pulls/12/comments')" "silence" "lecture comments"
  assert_eq "$(decision 'gh api repos/o/r/pulls/12/reviews --paginate')" "silence" "lecture reviews"
}

test_humanizer_compound_call_denied() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'git add f && git commit -m x && git push --force-with-lease=b:s origin b')" "deny" "un point suffit"
}

test_humanizer_line_continuation_denied() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision $'gh pr edit 12 \\\n  --body-file f')" "deny" "option sur la ligne suivante"
}

test_humanizer_markers() {
  transcript "$(t_prompt a)"
  assert_eq "$(decision 'gh pr create --body-file f # humanizer: sans objet')" "silence" "sans objet"
  assert_eq "$(decision 'git push --force-with-lease=b:s origin b # humanizer: sans objet')" "silence" "rebase"
  assert_eq "$(decision 'gh pr comment 12 --body-file f # humanizer: déjà relu')" "silence" "déjà relu"
  assert_eq "$(decision 'gh pr comment 12 --body-file f # humanizer: plus tard')" "deny" "marqueur inconnu"
}

test_humanizer_approved_text_needs_marker() {
  transcript "$(t_prompt a)" "$(t_humanizer)" "$(t_prompt ok)"
  assert_eq "$(decision 'gh pr comment 12 --body-file f # humanizer: déjà relu')" "silence" "approuvé, marqué"
  assert_eq "$(decision 'gh pr comment 12 --body-file f')" "deny" "approuvé, sans marqueur"
}

test_humanizer_marker_inside_script() {
  transcript "$(t_prompt a)"
  local script
  local head=$'bash ~/.claude/profile.sh require-token || exit 1\n'
  script=$'F=/tmp/pr-risk-3.md\nID=$(gh api "repos/o/r/issues/3/comments" --paginate \\\n  --jq ".[] | .id" | head -1)\nif [ -n "$ID" ]; then\n  gh api -X PATCH "repos/o/r/issues/comments/$ID" -F body=@"$F"\nelse\n  gh pr comment 3 -R o/r --body-file "$F"\nfi'
  assert_eq "$(decision "$head$script")" "deny" "script pr-risk sans marqueur"
  assert_eq "$(decision "$head"$'# humanizer: sans objet\n'"$script")" "silence" "marqueur en 2e ligne"
}

test_humanizer_fail_open() {
  local out code=0
  out="$(bash "$REPO/global/humanizer-hook.sh" <<<'pas du json')" || code=$?
  assert_eq "$out|$code" "|0" "entrée invalide"
  out="$(bash "$REPO/global/humanizer-hook.sh" <<<'{"tool_input":{"command":"gh pr create --body-file f"}}')" || code=$?
  assert_eq "$out|$code" "|0" "sans transcript_path"
  rm -f "$SANDBOX/t.jsonl"
  assert_eq "$(decision 'gh pr create --body-file f')" "silence" "transcript absent"
  transcript "$(t_prompt a)" 'ligne {cassée' "$(t_humanizer)"
  assert_eq "$(decision 'gh pr create --body-file f')" "silence" "ligne invalide sautée"
}
```

- [ ] **Step 2 : lancer les tests, constater le rouge**

```bash
bash tests/run.sh test_humanizer
```

Attendu : chaque `test_humanizer_*` en `ÉCHEC` (script absent).

- [ ] **Step 3 : écrire `global/humanizer-hook.sh`**

En-tête : rôle en deux lignes de commentaire, puis les limites assumées :

```bash
# shortcut: lecture par motif du texte de l'appel ; une commande cachée (variable, alias, eval) n'est pas vue,
#   un corps de texte qui cite un point de publication fait un faux refus. Passer à l'arbre shfmt de main-guard si
#   un cas réel le demande.
# shortcut: /humanizer:humanizer tapé par l'utilisateur ne compte pas, seul l'outil Skill est lu.
```

`set -uo pipefail` (pas `-e` : tout échec de lecture = silence). Fonctions, dans cet ordre :

- `is_publication <commande>` : code 0 si une ligne de la commande, continuations `\`+saut de ligne jointes
  d'abord, est un point de publication (liste fermée de la spec §2, R1). Motifs, un mot `gh`/`git` borné par
  `(^|[^[:alnum:]_-])` :
  - `gh pr create` ;
  - `gh pr edit` et, sur la même ligne, `--body`, `--body-file`, `--title`, `-b`, `-F` ou `-t` (option entière :
    suivie d'une espace, de `=` ou de la fin) ;
  - `gh pr comment` ;
  - `gh pr review` et `-b`, `--body`, `-F` ou `--body-file` ;
  - `gh api` et un chemin en `/reviews` ou `/replies` (suivi d'une espace, d'un guillemet ou de la fin) et une
    option d'écriture `-f`, `-F`, `--field`, `--raw-field`, `--input`, `-X POST`, `--method POST` ;
  - `git` … `push` … `--force-with-lease` sur la même ligne ;
  - `gh pr merge`.
- `has_marker <commande>` : code 0 si elle contient `# humanizer: sans objet` ou `# humanizer: déjà relu` (espaces
  multiples tolérées après `#` et après `:`).
- `recent_passage <transcript>` : code 0 si la dernière entrée retenue est un passage, 1 sinon, 2 si jq échoue.
  Une seule passe jq en flux :

```bash
jq -Rr 'fromjson? | select(.isSidechain != true)
  | if .type == "assistant"
       and any(.message.content[]?; .type == "tool_use" and .name == "Skill"
               and .input.skill == "humanizer:humanizer")
    then "S"
    elif .type == "user" and (.isMeta != true)
       and ((.origin.kind // "human") == "human") and (.isCompactSummary != true)
       and (.message.content | type == "string" or all(.[]; .type != "tool_result"))
    then "H"
    else empty end' "$1"
```

  puis comparer la dernière ligne à `S`.
- `deny` : imprime le refus (Global Constraints) avec cette raison, mot pour mot :

```text
Texte publié vers GitHub sans passage par humanizer depuis le dernier message de l'utilisateur (consigne « Humanizer » du CLAUDE.md global). Passe le texte par le skill humanizer:humanizer, reprends le texte réécrit, puis relance l'appel. Marqueurs, en commentaire dans l'appel : « # humanizer: sans objet » si l'appel n'envoie pas de prose (titre fait d'un identifiant, push forcé d'un rebase) ; « # humanizer: déjà relu » si le texte, déjà passé par humanizer, a été approuvé tel quel par l'utilisateur.
```

Corps principal : `command -v jq` sinon `exit 0` ; commande lue de `.tool_input.command` (vide ou entrée invalide →
`exit 0`) ; `is_publication` faux → `exit 0` ; `has_marker` → `exit 0` ; `transcript_path` vide ou fichier
illisible → `exit 0` ; `recent_passage` : 0 → `exit 0`, 2 → `exit 0`, 1 → `deny`.

- [ ] **Step 4 : vert, shellcheck, mutation**

```bash
bash tests/run.sh test_humanizer
shellcheck global/humanizer-hook.sh tests/test_humanizer_hook.sh
```

Attendu : tous `PASS`, shellcheck muet. Mutation : retirer le motif `gh pr merge` → `test_humanizer_denies_force_push_and_merge`
échoue ; retirer `select(.isSidechain != true)` → `test_humanizer_sidechain_passage_ignored` échoue ; retirer le test
`origin.kind` → `test_humanizer_non_prompt_entries_are_not_a_bound` échoue. Remettre le code, noter les trois
résultats dans le rapport.

- [ ] **Step 5 : commit**

```bash
git add global/humanizer-hook.sh tests/test_humanizer_hook.sh
git commit -m "✨ humanizer: Refuser un texte publié sans passage par humanizer

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 2 : déclaration du hook et marqueurs des skills

§ spec : §2 (tableau des endroits : `settings/base.json`, `rebase.md`, `comments.md`, `pr-risk`).

**Files :**
- Modify : `settings/base.json` (`hooks.PreToolUse`, après l'entrée main-guard)
- Modify : `tests/test_settings.sh` (nouveau test)
- Modify : `global/skills/pr/rebase.md:11`
- Modify : `global/skills/pr/comments.md` (étape 4, après « ils restent en attente. »)
- Modify : `global/skills/pr-risk/SKILL.md:227-237` (bloc bash)

**Interfaces :**
- Consomme : `~/.claude/humanizer-hook.sh` (Task 1), marqueurs exacts (Global Constraints).

- [ ] **Step 1 : test** (rouge attendu : `humanizer-hook.sh` absent de `base.json`)

`tests/test_settings.sh`

```bash
test_base_settings_humanizer_hook() {
  local b="$REPO/settings/base.json"
  assert_eq "$(jq -r '[.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[].command] | join("|")' "$b")" \
    "bash ~/.claude/bash-rewrite-hook.sh|bash ~/.claude/main-guard-hook.sh|bash ~/.claude/humanizer-hook.sh" "ordre"
}
```

- [ ] **Step 2 : rouge** — `bash tests/run.sh test_base_settings_humanizer_hook` → `ÉCHEC`.

- [ ] **Step 3 : `settings/base.json`** — nouvelle entrée PreToolUse, insérée juste après celle de main-guard :

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "bash ~/.claude/humanizer-hook.sh"
    }
  ]
}
```

- [ ] **Step 4 : marqueurs dans les skills** (Edit, 120 colonnes au plus)
  - `global/skills/pr/rebase.md`, étape 5 : la commande devient
    `` `git push --force-with-lease=<headRefName>:<SHA distant noté> origin <headRefName> # humanizer: sans objet` ``,
    suivie de « (aucun texte publié : sans le marqueur, le hook `humanizer-hook.sh` refuse ce push forcé) ».
Décision de relecture : la réponse proposée aux fils et points non corrigés passe par `humanizer:humanizer` **avant**
d'être montrée ; l'utilisateur approuve donc le texte final, et le marqueur `déjà relu` dit vrai.


  - `global/skills/pr/comments.md`, étape 4 : les deux « réponse proposée dans le rapport », « publiée après
    accord » (fils, puis points hors fil) disent que la réponse proposée passe par `humanizer:humanizer` avant d'être
    montrée. Puis nouvelle sous-ligne après « ils restent en attente. » :
    « Réponse publiée après accord, déjà passée par `humanizer:humanizer` : marqueur `# humanizer: déjà relu` en fin
    d'appel, sinon le hook `humanizer-hook.sh` la refuse et un second passage changerait le texte approuvé. »
  - `global/skills/pr-risk/SKILL.md`, bloc bash : nouvelle ligne `# humanizer: sans objet` juste après
    `bash ~/.claude/profile.sh require-token || exit 1`, et une phrase (en anglais, comme le skill) avant le bloc :
    « The `# humanizer: sans objet` line tells `humanizer-hook.sh` this templated comment is not prose. »

Vérification :

```bash
git grep -nF '# humanizer: sans objet' -- global/skills/pr/rebase.md global/skills/pr-risk/SKILL.md
git grep -nF '# humanizer: déjà relu' -- global/skills/pr/comments.md
git grep -nF 'proposée, passée par `humanizer:humanizer` avant' -- global/skills/pr/comments.md
```

Attendu : une ligne par fichier pour les deux premières commandes, deux lignes (fils, points hors fil) pour la
troisième : la formulation ajoutée tient sur une ligne et reprend ce fragment.

- [ ] **Step 5 : vert** — `bash tests/run.sh test_base_settings` → tous `PASS` (dont `test_base_settings_profile_hook`).

- [ ] **Step 6 : commit**

```bash
git add settings/base.json tests/test_settings.sh global/skills/pr/rebase.md global/skills/pr/comments.md global/skills/pr-risk/SKILL.md
git commit -m "🔧 humanizer: Déclarer le hook et marquer les envois sans prose ou déjà relus

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 3 : documentation

§ spec : — (mise à jour de la doc). Le glossaire `docs/domaine.md` a été aligné et commité avec la spec ; cette
tâche vérifie qu'il ne garde rien de la version écartée (rappel au contexte).

- [ ] **Step 1 : grep des termes retirés** (fragments de l'ancienne rédaction, tenus sur une ligne)

```bash
git grep -nF 'hook PreToolUse `Bash` à créer' -- . ':!docs/superpowers'
git grep -nF 'ne déclenche pas de rappel' -- . ':!docs/superpowers'
git grep -nF 'additionalContext` ou `permissionDecisionReason' -- . ':!docs/superpowers'
```

Attendu : vide pour chacun. Une occurrence → la réécrire selon la spec et commiter
(`📝 humanizer: Aligner le glossaire sur le refus`). Rien à changer → pas de commit.

### Task 4 : points de publication ajoutés après la review (#167)

§ spec : §2 R1 (`gh pr close --comment`, `gh api …/comments`, option courte collée), §4 critères ajoutés. Décision
de l'utilisateur sur `code-review` R3 ; `gh issue comment` reste hors périmètre.

Tests : `test_humanizer_denies_pr_close_comment`, `test_humanizer_denies_api_comments`,
`test_humanizer_denies_glued_short_options`, lectures et `gh pr close` sans commentaire ajoutés à
`test_humanizer_silent_on_non_publication` (le cas « PATCH hors reviews » y devient un refus, déplacé). Une mutation
par garde ajoutée (lettre de l'option courte, ligne `close`, `comments` du chemin, segment d'identifiant, `?`, `-f`
et `-X` collés) : chacune fait échouer au moins un test.

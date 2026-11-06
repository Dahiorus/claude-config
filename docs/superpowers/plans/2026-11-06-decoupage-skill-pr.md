# Skill `pr` : un fichier par action — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `global/skills/pr/SKILL.md` passe sous 200 lignes ; `push`, `squash`, `rebase`, `recette`, `merge`, `review` et
`comments` vivent chacun dans `global/skills/pr/<action>.md`, lu à la demande.

**Architecture:** déplacement de texte tel quel, plus une table « action → fichier » dans `SKILL.md`. Seuls changent les
renvois d'une action à une autre (spec R3) et ceux des autres skills et de `docs/domaine.md` (spec R4). Un test bash
garde la table alignée sur les fichiers et interdit les renvois sans `.md`.

**Tech Stack:** Markdown, bash (`tests/run.sh`, shellcheck).

**Spec:** `docs/superpowers/specs/2026-11-06-decoupage-skill-pr-design.md`

## Découpage en PR

Une seule PR, une seule story (P1). Fichiers touchés hors tests, spec et plan : `pr/SKILL.md`, 7 fichiers d'action,
`feature/SKILL.md`, `bugfix/SKILL.md`, `docs/domaine.md` = 11 (< 15).

## Global Constraints

- Texte déplacé tel quel : seuls changent les titres (`### <action>` → `# <action>`) et les renvois listés en R3.
- `wc -l global/skills/pr/SKILL.md` ≤ 200.
- Commiter fichier par fichier (`git add <fichier>`), jamais `git add -A` : d'autres sessions peuvent modifier
  `global/skills/*`.
- Vérification : `bash tests/run.sh` (tests + shellcheck), tout au vert.

## Review Focus

1. Renvoi tourné autrement que les formes de R3 (sans backticks, « cf. ») : la tâche 1 relit chaque fichier déplacé
   en entier, pas seulement le grep.
2. `/pr help` : le bloc d'aide reste identique octet pour octet (tâche 1, étape 6).
3. Lignes perdues ou dupliquées au déplacement : `diff` du texte déplacé contre `main` (tâche 1, étape 6).
4. Agent Opus de `feature`/`bugfix` qui lit `~/.claude/skills/pr/review.md` étape 2 : le fichier contient bien
   « Erreur avalée » et « Test absent » (tâche 2, étape 4).
5. Fichier d'action absent : la règle de `SKILL.md` dit de s'arrêter ; le test de la tâche 1 empêche qu'un fichier de
   la table manque.

## Traçabilité

| Exigence (spec) | Tâche | Preuve |
|---|---|---|
| R1 — sept actions dans leur fichier, texte tel quel | 1 | `test_pr_skill_table_matches_files`, `diff` de l'étape 4 |
| R2 — table, règle de lecture (enchaînement, fichier introuvable), sections gardées | 1 | `test_pr_skill_table_matches_files` ; relecture de la règle |
| R3 — renvois internes (dont `SKILL.md:73` et `:101`) | 1 | `test_no_bare_reference_to_pr_action` (vert pour `pr/`) ; `grep -cF` des renvois vers `SKILL.md` (tâche 1, étape 6) |
| R4 — `feature:28`, `bugfix:36`, `domaine.md:33/59/72` | 2 | `test_no_bare_reference_to_pr_action` |
| R5 — installation inchangée | — | `~/.claude/skills/pr` est un lien vers le dossier, rien à changer (vérifié : `ls -la ~/.claude/skills`) |
| §4 critère ≤ 200 lignes, table ↔ fichiers | 1 | `test_pr_skill_table_matches_files` |
| §4 critère texte intact, aide inchangée | 1 | étape 4 (`diff`) |
| §4 critère aucun renvoi sans `.md` | 2 | `test_no_bare_reference_to_pr_action` |
| §4 critères de parcours (`push`, `squash merge`, `push recette`, `test`/`switch`/`list`, fichier absent) | 1 | règle de R2, recopiée telle quelle ; non testable automatiquement (texte lu par le modèle) |
| §5 filet | 1 | nouveau `tests/test_skills.sh` ; `diff` du texte déplacé |

Usages vérifiés à l'étape 1b (grep des renvois aux actions dans `global/` et `docs/domaine.md`) :

| Fichier | Usage | Devient |
|---|---|---|
| `pr/SKILL.md:73` | « voir `push` » | « voir `push.md` » (tâche 1) |
| `pr/SKILL.md:101` | « comme `push` » | « comme `push.md` » (tâche 1) |
| `pr/SKILL.md:248, 258, 260, 274, 277, 282` (`merge`) | renvois à `push`, `squash`, `recette`, Nettoyage | R3 (tâche 1) |
| `pr/SKILL.md:192, 204` (`squash`, `rebase`) | « (`approvals`) » | « (`approvals`, `SKILL.md`) » (tâche 1) |
| `pr/SKILL.md:168` (`push`) | « (`update-desc`) » | « (`update-desc`, `SKILL.md`) » (tâche 1) |
| `pr/SKILL.md:297` (`review`) | « l'étape 1 de `comments` » | « l'étape 1 de `comments.md` » (tâche 1) |
| `pr/SKILL.md:381` (`comments`) | « comme pour `recette` » | « comme pour l'action `recette` (`recette.md` du skill `pr`) » (tâche 1) |
| `pr/SKILL.md:274` (`merge`) | « comme `recette` » | « comme l'action `recette` (`recette.md` du skill `pr`) » (tâche 1) |
| `feature/SKILL.md:28`, `bugfix/SKILL.md:36` | « (skill `pr`, § `review`, étape 2) » | « (`~/.claude/skills/pr/review.md`, étape 2) » (tâche 2) |
| `docs/domaine.md:33, 59, 72` | « `global/skills/pr/SKILL.md` § `<action>` » | « `global/skills/pr/<action>.md` » (tâche 2) |
| `docs/superpowers/specs/*`, `plans/*` | citent des § du skill | inchangés (documents datés) |

Aucun test existant ne lit `pr/SKILL.md` (grep `skills/pr` dans `tests/` : rien).

---

### Task 1: Déplacer les sept actions

**Files:**
- Create: `tests/test_skills.sh`
- Modify: `global/skills/pr/SKILL.md` (supprimer les lignes 143-392, ajouter la section ci-dessous, lignes 73 et 101)
- Create: `global/skills/pr/push.md`, `squash.md`, `rebase.md`, `recette.md`, `merge.md`, `review.md`, `comments.md`

**Interfaces:**
- Produces: `test_pr_skill_table_matches_files` ; la table attendue dans `SKILL.md` a des lignes de la forme
  ``| `push` | `push.md` |``.

- [ ] **Step 1: Écrire le test**

`tests/test_skills.sh` :

```bash
# shellcheck shell=bash

PR_SKILL_DIR="$REPO_SRC/global/skills/pr"

test_pr_skill_table_matches_files() {
  local listed files f
  (( $(wc -l < "$PR_SKILL_DIR/SKILL.md") <= 200 )) || fail "pr/SKILL.md dépasse 200 lignes"
  listed="$(grep -oE '^\| `[a-z-]+` \| `[a-z-]+\.md` \|' "$PR_SKILL_DIR/SKILL.md" | grep -oE '[a-z-]+\.md' | sort)"
  [[ -n "$listed" ]] || fail "table des fichiers d'action absente de pr/SKILL.md"
  for f in $listed; do
    [[ -f "$PR_SKILL_DIR/$f" ]] || fail "$f cité dans la table mais absent"
  done
  files="$(find "$PR_SKILL_DIR" -maxdepth 1 -name '*.md' ! -name SKILL.md -printf '%f\n' | sort)"
  assert_eq "$files" "$listed" "fichiers d'action présents"
}
```

- [ ] **Step 2: Le voir échouer**

Run: `bash tests/run.sh test_pr_skill_table`
Expected: `FAIL  test_pr_skill_table_matches_files` avec `ÉCHEC : pr/SKILL.md dépasse 200 lignes`.

- [ ] **Step 3: Créer les sept fichiers**

Pour chaque action, le texte de `### <action>` jusqu'à la ligne vide avant la section suivante (`push` 143-172,
`squash` 174-193, `rebase` 195-206, `recette` 208-241, `merge` 243-284, `review` 286-354, `comments` 356-392),
titre devenu `# <action>`. Extraire avec `sed -n '<début>,<fin>p'` depuis `git show main:global/skills/pr/SKILL.md`,
pas à la main.

- [ ] **Step 4: Réécrire les renvois de R3 dans les fichiers créés**

Exactement les remplacements de la table R3 de la spec : `merge.md` (étapes 1, 3, 4, 5, 6), `squash.md` et
`rebase.md` (« (`approvals`, `SKILL.md`) »), `push.md` (« (`update-desc`, `SKILL.md`) »), `review.md` étape 0,
`comments.md` étape 2. Puis relire chaque fichier en entier : un renvoi à une autre action sous une autre forme
s'ajoute à la spec (le signaler, NEEDS_CONTEXT), il ne se réécrit pas en silence.

Décision : `recette.md` désigne aussi le fichier de suivi des résultats (« Dossier de suivi », `SKILL.md:34`). Les deux
renvois à l'action s'écrivent donc « comme l'action `recette` (`recette.md` du skill `pr`) » (`merge` étape 4) et « comme pour l'action `recette` (`recette.md` du skill `pr`) » (`comments`
étape 2) ; R3 de la spec est amendée en ce sens.

- [ ] **Step 5: Réduire `SKILL.md`**

Supprimer les lignes 143-392 (de `### push` à la fin de `comments`), garder `### test` puis ajouter juste après :

```markdown
### Actions à fichier

Les actions de cette table se lisent dans leur fichier, à côté de ce `SKILL.md`, avant la moindre commande.
Plusieurs actions à la suite : lire tous leurs fichiers avant la première commande. Un renvoi vers un autre fichier
(« étape 2 de `push.md` ») se lit au moment où il sert. Fichier introuvable → le dire et s'arrêter, ne jamais agir de
mémoire. Avant la première commande, une ligne de la réponse nomme les fichiers lus (« Lu : `squash.md`, `merge.md` ») ;
un fichier lu plus tard par renvoi a sa propre ligne avant la commande suivante (« Lu : `push.md`, étape 2 »). Sans
elles, l'utilisateur voit que la lecture a sauté. Action hors table (`help`, `view`, `test`, `switch`, `list`…) : pas de ligne « Lu ».

| Action | Lire avant d'agir |
|---|---|
| `push` | `push.md` |
| `squash` | `squash.md` |
| `rebase` | `rebase.md` |
| `recette` | `recette.md` |
| `merge` | `merge.md` |
| `review` | `review.md` |
| `comments` | `comments.md` |
```

Ligne 73 : « voir `push` » → « voir `push.md` ». Ligne 101 : « comme `push` » → « comme `push.md` ». « Nettoyage des
branches » reste à la fin de `SKILL.md`.

- [ ] **Step 6: Vérifier le texte déplacé et l'aide**

```bash
git show main:global/skills/pr/SKILL.md | sed -n '143,392p' | grep -v '^$' > /tmp/avant.txt
for a in push squash rebase recette merge review comments; do cat "global/skills/pr/$a.md"; done \
  | sed -E "s/l'action \`recette\` \(\`recette\.md\` du skill \`pr\`\)/\`recette\`/g" \
  | sed -E 's/^# /### /; s/`(push|squash|comments)\.md`/`\1`/g; s/, `SKILL\.md`\)/)/g; s/ de `SKILL\.md`//' \
  | grep -v '^$' > /tmp/apres.txt
diff /tmp/avant.txt /tmp/apres.txt && echo IDENTIQUE
diff <(git show main:global/skills/pr/SKILL.md | sed -n '/^## Aide/,/^## Résoudre/p') \
     <(sed -n '/^## Aide/,/^## Résoudre/p' global/skills/pr/SKILL.md) && echo AIDE-IDENTIQUE
```

Le `sed` annule les renvois avant le `diff` : vérifier aussi qu'ils sont bien écrits.

```bash
grep -cF '(`approvals`, `SKILL.md`)' global/skills/pr/squash.md global/skills/pr/rebase.md   # 1 chacun
grep -cF '(`update-desc`, `SKILL.md`)' global/skills/pr/push.md                              # 1
grep -cF '« Nettoyage des branches » de `SKILL.md`' global/skills/pr/merge.md               # 1
```

Expected: `IDENTIQUE`, `AIDE-IDENTIQUE` et les comptes indiqués (dossier temporaire du scratchpad à la place de `/tmp` si le sandbox l'exige).

- [ ] **Step 7: Tests**

Run: `bash tests/run.sh test_pr_skill_table` → `PASS`. Puis `wc -l global/skills/pr/SKILL.md` ≤ 200.

- [ ] **Step 8: Commit, fichier par fichier**

```bash
git add tests/test_skills.sh global/skills/pr/SKILL.md global/skills/pr/push.md global/skills/pr/squash.md global/skills/pr/rebase.md \
  global/skills/pr/recette.md global/skills/pr/merge.md global/skills/pr/review.md global/skills/pr/comments.md
git commit -m "♻️ skills: Move each long pr action into its own file"
```

### Task 2: Renvois des autres skills et du glossaire

**Files:**
- Modify: `global/skills/feature/SKILL.md:28`, `global/skills/bugfix/SKILL.md:36`, `docs/domaine.md:33,59,72`
- Modify: `tests/test_skills.sh`

**Interfaces:**
- Consumes: `review.md`, `comments.md`, `merge.md` (tâche 1).

- [ ] **Step 1: Écrire le test**

Ajouter à `tests/test_skills.sh` :

```bash
test_no_bare_reference_to_pr_action() {
  local hits
  hits="$(grep -rnE '(§|étapes?[^|]{0,20} de|comme( dans| pour)?|voir) `(push|squash|rebase|recette|merge|review|comments)`' \
    "$REPO_SRC/global" "$REPO_SRC/docs/domaine.md")" || [[ $? -eq 1 ]] || fail "grep en erreur"
  assert_eq "$hits" "" "renvois à une action de pr sans .md"
}
```

- [ ] **Step 2: Le voir échouer**

Run: `bash tests/run.sh test_no_bare_reference`
Expected: `FAIL`, la sortie cite `feature/SKILL.md:28`, `bugfix/SKILL.md:36` et `docs/domaine.md:33,59,72` (et rien
dans `global/skills/pr/`).

- [ ] **Step 3: Remplacer les renvois (spec R4)**

- `feature/SKILL.md:28` et `bugfix/SKILL.md:36` : « (skill `pr`, § `review`, étape 2) » → « (`~/.claude/skills/pr/review.md`, étape 2) ».
- `docs/domaine.md:33` : « `global/skills/pr/SKILL.md` § `review` » → « `global/skills/pr/review.md` » ; `:59` idem
  avec `comments` ; `:72` idem avec `merge`.

Vérifier avec `git diff --stat` : 3 fichiers, 5 lignes.

- [ ] **Step 4: Tests et contenu cité**

Run: `bash tests/run.sh` → tout `PASS`, shellcheck compris. Puis
`grep -c 'Erreur avalée\|Test absent' global/skills/pr/review.md` → `2` ou plus.

- [ ] **Step 5: Commit**

```bash
git add tests/test_skills.sh global/skills/feature/SKILL.md global/skills/bugfix/SKILL.md docs/domaine.md
git commit -m "📝 skills: Point the review rules references to pr/review.md"
```

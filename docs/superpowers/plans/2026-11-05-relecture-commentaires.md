# Relecture et retours de PR — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/pr comments` traite tous les retours en attente sans en retraiter, `/pr review` ne republie rien et approuve quand rien n'est nouveau, `/pr list à relire` liste les PR qui demandent ma relecture, `/pr merge` ne garde en mémoire que pièges et décisions, et un test protège les hooks sonar.

**Architecture:** Deux changements de code testés (requête des fils de la statusline, test de `base.json`), puis des règles réécrites dans `global/skills/pr/SKILL.md`, section par section. La mémoire du dépôt est nettoyée hors git.

**Tech Stack:** bash, jq, `gh api graphql`, markdown des skills.

**Spec:** `docs/superpowers/specs/2026-11-05-relecture-commentaires-design.md`

## Découpage en PR

Fichiers touchés hors tests, spec et plan : `global/statusline-command.sh`, `global/skills/pr/SKILL.md`, `docs/domaine.md` (déjà commité). 3 < 15 → **une seule PR**, une seule story (P1).

## Global Constraints

- « Soi » = compte du profil (`bash ~/.claude/profile.sh account`) ; sous le jeton ponctuel de `/pr`, `@me` le désigne.
- Toute commande `gh` du skill garde la forme du jeton ponctuel de l'en-tête de `pr/SKILL.md`.
- Texte publié (réponse, review) passé par `humanizer:humanizer`, corps écrit dans un fichier d'abord.
- Le commentaire contenant `<!-- pr-risk -->` et les auteurs de type `Bot` ne sont jamais des retours.
- Commits au format de `CONTRIBUTING.md`, un fichier ajouté à la fois (`git add <fichier>`), jamais `git add -A`.
- Vérification : `bash tests/run.sh` (tests + shellcheck), sortie lue, pas de pipe qui masque le code retour.

## Review Focus

1. Fil à un seul commentaire écrit par soi (sa propre review) : compté en attente, pas ignoré — Task 1 (statusline) le teste ; Task 3 le dit.
2. `comments(last: 1)` sans auteur (compte supprimé, `author: null`) : le fil est compté en attente, pas d'erreur jq — Task 1 le teste.
3. Push forcé depuis la dernière relecture : `merge-base --is-ancestor` échoue → diff complet — Task 4 l'écrit tel quel.
4. Relecture demandée à une équipe seulement : `reviewRequests` contient une équipe, pas un utilisateur — Task 4 dit comment conclure.
5. Commentaire `pr-risk` signé de soi postérieur à un retour : ne vaut pas réponse — Task 3 l'écrit dans la règle Q2.

## Décisions de relecture du plan

- Q10 : un fil de soi seul, sans réponse, compte « en attente » sur toute PR, la sienne comme celle d'un autre (règle de Tasks 1 et 3 inchangée).
- Q11 : un point sans demande (« LGTM », remerciement) reste un retour, trié et écarté à chaque passage.

## Table de traçabilité

| Exigence (§ spec) | Task | Preuve |
|---|---|---|
| R1 mémoire au merge, Q12 (§2 R1) | 6 | grep de l'étape 6 et de l'Aide ; recette au prochain `/pr merge` |
| Q7 nettoyage de `depot-livraison.md` | 7 | fichier relu : aucune ligne « Mergée le » |
| R2 hooks sonar (§2 R2, §4) | 2 | `test_base_settings_profile_hook`, rouge avec un hook retiré |
| R3 retours hors fil, rattachement, réponse Q2 (§2 R3) | 3 | grep ; recette §4 R3 et Q2 |
| R4 fils en attente, Q1 (§2 R4) | 3 | grep ; recette §4 R4 et Q1 |
| R4/Q3 statusline (§2 R4, §5) | 1 | `test_statusline_counts_threads_awaiting_account` |
| R5 tri Opus (§2 R5) | 3 | grep : plus de `Explore` dans § `comments`, en-tête cite le tri |
| R6 relecture incrémentale, Q4, Q5, Q8, Q9, Q13, Q14 (§2 R6) | 4 | grep ; recette §4 R6 |
| R7 `list à relire`, Q6 (§2 R7) | 5 | grep ; recette §4 R7 |

Usages vérifiés à l'étape 1b :

| Fichier | Usage | Devient |
|---|---|---|
| `global/statusline-command.sh:117-127` | `fetch_threads_count`, `--jq` interne à `gh` | JSON brut passé à `jq` (comme `fetch_ci_state`), filtre Q3 ; `gh_user` hors de portée (local à `select_gh_token`) → `viewer { login }`, même compte puisque le jeton exporté est le sien |
| `global/statusline-command.sh:224` | appel par `cached threads` | inchangé |
| `global/skills/pr/SKILL.md:20-22` | en-tête, étapes de jugement par Opus | + tri de plus de 3 retours |
| `global/skills/pr/SKILL.md:38-66` | Aide : lignes `list`, `merge`, `review`, `comments`, exemples | réécrites (Tasks 3 à 6) |
| `global/skills/pr/SKILL.md:3` | `description` | + PRs awaiting my review (Task 5) |
| `global/skills/pr/SKILL.md:76-84` | `list` | + consigne « à relire » (Task 5) |
| `global/skills/pr/SKILL.md:276-277` | `merge` étape 6 | Task 6 |
| `global/skills/pr/SKILL.md:281-325` | `review` | Task 4 |
| `global/skills/pr/SKILL.md:327-345` | `comments` | Task 3 |
| `docs/domaine.md` | glossaire et invariants | à jour (commit `1541d61`, puis « Review publiée », « Dernière relecture », « Retour hors fil » corrigés après la revue du plan) |
| `tests/test_settings.sh:170` | `test_base_settings_profile_hook` | Task 2 |

---

## Lot A — parallélisable (Tasks 1 et 2)

Fichiers : Task 1 → `global/statusline-command.sh`, `tests/test_statusline.sh` ; Task 2 → `tests/test_settings.sh`. Aucun fichier commun.

### Task 1: Statusline — compter les fils en attente (§2 R4, Q3, §5)

**Files:**
- Modify: `global/statusline-command.sh:115-127` (`fetch_threads_count`)
- Test: `tests/test_statusline.sh` (stub `make_gh_stub`, nouveau test)

**Interfaces:**
- Consumes: `cached`, `ci_repo_full`, `GH_TOKEN` exporté par `select_gh_token`.
- Produces: `fetch_threads_count <n°>` écrit toujours un entier ou rien.

- [ ] **Step 1: Étendre le stub gh** — dans `make_gh_stub`, nouveau cas qui renvoie `$GH_GRAPHQL` :

```bash
  "api graphql") printf '%s' "${GH_GRAPHQL:-}" ;;
```

- [ ] **Step 2: Écrire le test qui échoue**

```bash
test_statusline_counts_threads_awaiting_account() {
  repo_with_origin "$SANDBOX/p" https://github.com/someone/x.git
  local f="$SANDBOX/cache/claude-statusline/threads-someone_x-5" _
  # attendus : alice en dernier (1), bob seul sur son fil (1), auteur supprimé (1) ; répondu par bob et résolu : non
  GH_GRAPHQL='{"data":{"viewer":{"login":"bob"},"repository":{"pullRequest":{"reviewThreads":{"nodes":[
    {"isResolved":false,"all":{"totalCount":2},"last":{"nodes":[{"author":{"login":"alice"}}]}},
    {"isResolved":false,"all":{"totalCount":2},"last":{"nodes":[{"author":{"login":"bob"}}]}},
    {"isResolved":false,"all":{"totalCount":1},"last":{"nodes":[{"author":{"login":"bob"}}]}},
    {"isResolved":false,"all":{"totalCount":3},"last":{"nodes":[{"author":null}]}},
    {"isResolved":true,"all":{"totalCount":1},"last":{"nodes":[{"author":{"login":"alice"}}]}}]}}}}}' \
    GH_ACCOUNTS=bob GH_SEES=bob run_statusline "$SANDBOX/p" someone/x >/dev/null
  for _ in $(seq 50); do [[ -s "$f" ]] && break; sleep 0.1; done
  assert_eq "$(cat "$f" 2>/dev/null)" "3" "fils en attente"
}
```

- [ ] **Step 3: Lancer, voir le rouge** — `bash tests/run.sh` ; attendu : `test_statusline_counts_threads_awaiting_account` en échec (cache vide : le stub ignore `--jq`, et l'ancien filtre compterait 4).

- [ ] **Step 4: Réécrire `fetch_threads_count`** — requête avec alias `all: comments { totalCount }` et `last: comments(last: 1) { nodes { author { login } } }`, plus `viewer { login }` ; sortie brute de `gh api graphql` passée à `jq -r` (pas `--jq`), filtre :

```jq
.data.viewer.login as $me
| [.data.repository.pullRequest.reviewThreads.nodes[]
   | select((.isResolved | not)
            and ((.last.nodes[0].author.login // "") != $me or .all.totalCount < 2))]
| length
```

Le commentaire au-dessus de la fonction devient « Nombre de fils de revue en attente du compte de la statusline (vide si inconnu) ». Garder le `case` final qui n'écrit qu'un entier.

- [ ] **Step 5: Lancer, voir le vert** — `bash tests/run.sh` ; attendu : tout PASS, shellcheck propre.

- [ ] **Step 6: Commit**

```bash
git add tests/test_statusline.sh
git add global/statusline-command.sh
git commit -m "✨ statusline: Count only the threads awaiting me" # corps : pourquoi (même règle que /pr comments), Co-Authored-By
```

### Task 2: Test des hooks sonar de `base.json` (§2 R2)

**Files:**
- Test: `tests/test_settings.sh:170-176` (`test_base_settings_profile_hook`)

- [ ] **Step 1: Ajouter les assertions** à la fin de `test_base_settings_profile_hook` :

```bash
  assert_contains "$(jq -r '.hooks.PreToolUse[].hooks[].command' "$b")" "pretool-secrets.sh"
  assert_contains "$(jq -r '.hooks.UserPromptSubmit[].hooks[].command' "$b")" "prompt-secrets.sh"
```

- [ ] **Step 2: Prouver le rouge** — retirer à la main le hook `prompt-secrets.sh` de `settings/base.json`, `bash tests/run.sh` ; attendu : `test_base_settings_profile_hook` en échec sur `prompt-secrets.sh`. Puis `git checkout settings/base.json`.

- [ ] **Step 3: Lancer, voir le vert** — `bash tests/run.sh`, tout PASS.

- [ ] **Step 4: Commit**

```bash
git add tests/test_settings.sh
git commit -m "✅ tests: Check the sonar-secrets hooks stay in base.json"
```

---

## Tasks séquentielles sur `global/skills/pr/SKILL.md` (3 à 6)

Pas de test automatique pour les skills (décision de l'utilisateur, §5 de la spec). Chaque tâche vérifie par grep, relit la section modifiée en entier, puis lance `bash tests/run.sh`. Le texte ci-dessous fixe le contenu ; l'implémenteur l'insère dans le style des lignes voisines (français, phrases courtes, backticks pour les commandes).

### Task 3: `comments` — retours hors fil, fils en attente, tri Opus (§2 R3, R4, R5, Q1, Q2)

**Files:**
- Modify: `global/skills/pr/SKILL.md` (en-tête l.20-22, Aide ligne `comments`, § `comments` l.327-345)

- [ ] **Step 1: En-tête** — dans la liste « Les étapes qui demandent du jugement (… ) », ajouter « tri de plus de 3 retours (`comments`) ».

- [ ] **Step 2: Aide** — ligne `comments` :

```text
  comments      traite les fils et commentaires en attente, corrige, pousse, répond
```

- [ ] **Step 3: Étape 1 de `comments`** — remplacer par la collecte de deux sortes de retours :

```markdown
1. Retours en attente de soi (soi : compte du profil), filtrés par auteur si la consigne le dit (« de alice ») :
   - **Fils** : `gh api graphql`, `reviewThreads` avec `isResolved`, `all: comments { totalCount }`,
     `comments { databaseId path line body author { login } }`. Gardés : non résolus, dont le dernier commentaire
     n'est pas de soi, ou fil de soi seul, sans réponse (`totalCount` 1 : sa propre review est un retour).
   - **Hors fil** : commentaires de la conversation (`gh api repos/<o/r>/issues/<n°>/comments --paginate`) et `body`
     non vide des reviews (`gh api repos/<o/r>/pulls/<n°>/reviews --paginate`). Exclus : commentaire contenant
     `<!-- pr-risk -->`, auteur de type `Bot`, commentaire de conversation de soi (c'est une réponse ; seul le
     `body` d'une review de soi reste un retour). Chacun est découpé en points (puce, paragraphe, remarque préfixée
     de `/pr review`) ; un point est traité, donc exclu, quand un commentaire de soi autre que `pr-risk` le cite
     (`> …`). Rattachement : un point qui cite `fichier:ligne`, un `fichier`, ou un symbole qu'un grep trouve dans
     un seul fichier du diff, est rattaché à ce fichier (et cette ligne) ; sinon il vaut pour toute la PR.
   Aucun retour → « aucun retour en attente » et s'arrêter.
```

- [ ] **Step 4: Étape 2** — « Plus de 3 fils : … agent `Explore` » devient « Plus de 3 retours (fils et points hors fil) : … agent `general-purpose` (modèle `opus` passé explicitement) » ; le brief reçoit aussi, pour un point hors fil, son origine (commentaire ou review, id) et son rattachement. Le reste de l'étape (critères de tri) est inchangé.

- [ ] **Step 5: Étape 4** — après la phrase sur les fils, ajouter :

```markdown
   Points hors fil corrigés : un seul commentaire de conversation (`gh pr comment <n°> --body-file <fichier>`) qui
   cite chaque point (`> …`) avec ce qui a changé et le SHA, passé par `humanizer:humanizer`. Points non corrigés :
   comme les fils, réponse proposée, publiée après accord ; tant qu'aucune réponse ne les cite, ils restent en attente.
```

- [ ] **Step 6: Étape 5** — « Tri et SHA dans `final-review.md` » devient « Tri, SHA et, pour chaque point hors fil, origine et rattachement dans `final-review.md` ».

- [ ] **Step 7: Vérifier** — `grep -n 'Explore' global/skills/pr/SKILL.md` ne renvoie rien dans § `comments` ; `grep -n 'pr-risk -->' global/skills/pr/SKILL.md` renvoie la ligne de l'étape 1 ; relire § `comments` en entier ; `bash tests/run.sh` au vert.

- [ ] **Step 8: Commit** — `git add global/skills/pr/SKILL.md`, `✨ skills: Handle every pending PR feedback in /pr comments`.

### Task 4: `review` — remarques déjà faites, périmètre incrémental, approbation (§2 R6, Q4, Q5, Q8, Q9)

**Files:**
- Modify: `global/skills/pr/SKILL.md` (Aide ligne `review`, § `review` l.281-325)

**Interfaces:**
- Consumes: un point hors fil de soi est ouvert tant qu'aucune réponse d'un autre que soi ne le cite (pour Q8, c'est l'auteur de la PR qui répond aux bloquantes de soi).

- [ ] **Step 1: Aide** — ligne `review` :

```text
  review        relit la PR (la sienne comprise), évalue sa criticité (relecture humaine requise ?),
                publie les commentaires, ou approuve si rien n'est nouveau et la relecture demandée
```

- [ ] **Step 2: Nouvelle étape 0, avant l'étape 1** :

```markdown
0. **Déjà fait** — lire les remarques déjà faites (fils de la PR : `path`, `line`, texte, `isResolved` ; `body` des
   reviews ; commentaires de la conversation, `gh api repos/<o/r>/issues/<n°>/comments --paginate`), hors commentaire
   contenant `<!-- pr-risk -->` et auteurs de type `Bot` (fil dont le premier commentaire est d'un `Bot`), comme à
   l'étape 1 de `comments`, et la dernière relecture de soi (`commit_id` de sa review la plus récente au `body` non vide et d'`state` autre que `PENDING`,
   `gh api repos/<o/r>/pulls/<n°>/reviews --paginate` : les réponses aux fils créent des reviews vides, son brouillon
   est `PENDING`). Périmètre : `git diff <commit_id>...HEAD` si `git merge-base --is-ancestor <commit_id> HEAD`
   réussit dans l'arbre de la PR **et** que `git rev-list --merges <commit_id>..HEAD` est vide, sinon (aucune
   relecture, push forcé, squash, rebase, merge de la base) le diff complet contre la base : le code des PR déjà
   mergées sur la base n'est pas relu.
```

- [ ] **Step 3: Étape 1 (brief)** — le brief reçoit aussi le périmètre de l'étape 0 et les remarques déjà faites ; les fichiers touchés hors périmètre servent de contexte, sans remarque.

- [ ] **Step 4: Étape 2** — ajouter après les deux règles :

```markdown
   Une remarque sur le même point qu'une remarque déjà faite (même fichier, ligne proche ou même symbole, même
   problème) n'est pas rendue, résolue ou non ; une remarque résolue dont le code a régressé est nouvelle.
```

- [ ] **Step 5: Étape 4** — remplacer « Publier une seule review `COMMENT`, jamais `APPROVE` ni `REQUEST_CHANGES` : » par :

```markdown
4. Publier au plus une review, jamais `REQUEST_CHANGES`. Remarques nouvelles → une review `COMMENT` :
```

  et ajouter, après le paragraphe sur le format des commentaires :

```markdown
   Aucune remarque nouvelle → `APPROVE` seulement si la PR est d'un autre, que soi est relecteur demandé
   (`gh pr view <n°> --json reviewRequests` : son login, ou une équipe dont il est membre,
   `gh api orgs/<org>/teams/<slug>/memberships/<soi>` qui répond `active`) et qu'aucune remarque bloquante de soi
   (préfixe `**[bloquant]**`) n'est ouverte (fil non résolu, point hors fil qu'aucune réponse d'un autre ne cite). Corps court, passé par
   `humanizer:humanizer`. Sinon rien n'est publié : sa propre PR, pas de demande en cours (GitHub la retire à
   chaque review de soi, l'auteur la redemande), ou bloquantes ouvertes,
   listées dans le rapport, chacune marquée « corrigée, fil à résoudre » ou « toujours là ».
```

- [ ] **Step 6: Étape 5** — le rapport dit aussi le périmètre relu (depuis `<sha court>` ou complet), le nombre de remarques écartées comme déjà faites, et ce qui a été publié (review, approbation ou rien, avec la raison).

- [ ] **Step 7: Vérifier** — `grep -n 'jamais `APPROVE`' global/skills/pr/SKILL.md` vide ; `grep -n 'merge-base --is-ancestor' global/skills/pr/SKILL.md` trouve l'étape 0 ; le texte des invariants de `docs/domaine.md` (contexte Relecture de PR) dit la même chose que l'étape 4 ; `bash tests/run.sh` au vert.

- [ ] **Step 8: Commit** — `✨ skills: Skip known remarks and approve in /pr review`.

### Task 5: `list à relire` (§2 R7, Q6)

**Files:**
- Modify: `global/skills/pr/SKILL.md` (`description` l.3, Aide ligne `list` et exemples, § `list` l.76-84)

- [ ] **Step 1: `description`** — après « list the current repo's pull requests », ajouter « (or those awaiting my review) » ; ajouter l'exemple « « quelles PR dois-je relire ? » » à la liste des citations.

- [ ] **Step 2: § `list`** — dans les traductions de consigne, ajouter : « « à relire » → `--search "review-requested:@me"` (sous jeton ponctuel, `@me` = soi ; demandes à une équipe comprises), dépôt courant seulement ; aucune → « aucune PR ne demande ta relecture » ».

- [ ] **Step 3: Aide** — ligne `list` : `liste les PR du dépôt (sans n°) : open par défaut, closed, à relire` ; ajouter `/pr list à relire` aux exemples.

- [ ] **Step 4: Vérifier** — `grep -n 'review-requested:@me' global/skills/pr/SKILL.md` trouve § `list` ; lancer la commande `gh pr list --search "review-requested:@me" --json number` sous jeton ponctuel dans ce dépôt : elle répond (liste vide acceptée) ; `bash tests/run.sh` au vert.

- [ ] **Step 5: Commit** — `✨ skills: List the PRs awaiting my review`.

### Task 6: `merge` — mémoire réduite aux pièges et décisions (§2 R1)

**Files:**
- Modify: `global/skills/pr/SKILL.md` (Aide ligne `merge`, § `merge` étape 6 l.276-277)

- [ ] **Step 1: Étape 6** :

```markdown
6. **Mémoire** — n'y écrire qu'un piège (comportement inattendu et son contournement) ou une décision de
   l'utilisateur (choix à ne pas reproposer, avec sa raison) apparus dans la PR ; jamais n° de PR, SHA, date ou état
   du déploiement, que git et GitHub gardent. Rien de nouveau → rien. Ce qui reste à faire va dans le reste à faire
   versionné s'il existe ; sinon un bug ou un point hors périmètre devient une issue, proposée puis créée après accord
   comme à l'étape **Issues** de `push` (label `hors-perimetre`, ou `bug` pour un bug). Jamais dans la mémoire.
```

- [ ] **Step 2: Aide** — ligne `merge`, « déploiement, nettoyage, mémoire » → « déploiement, nettoyage, pièges et décisions en mémoire ».

- [ ] **Step 3: Vérifier** — `grep -n 'SHA de merge, déploiement' global/skills/pr/SKILL.md` vide ; `bash tests/run.sh` au vert.

- [ ] **Step 4: Commit** — `✨ skills: Keep only traps and decisions in memory`.

### Task 7: Nettoyer la mémoire du dépôt (Q7) — contrôleur, hors git

**Files:**
- Modify: `~/.claude/projects/-home-bung-france-groupe-intra-IdeaProjects-claude-config/memory/depot-livraison.md`

- [ ] **Step 1:** Garder les pièges et les décisions (avec leur raison), regrouper les pièges des lignes « Mergée le … » sous « Pièges rencontrés », retirer n° de PR, SHA, dates et états de déploiement. Ce qui reste à faire (dette statusline 265 lignes, divergence `pr-risk` à reporter dans harnais) reste, sous « À faire » sans n° de PR.
- [ ] **Step 2: Vérifier** — `grep -c 'Mergée' <fichier>` renvoie 0 ; la ligne de `MEMORY.md` décrit toujours le fichier.

## Convergence 1

### Task 8: Requête des fils de `comments` : dernier auteur (§2 R4, Q1)

**Files:**
- Modify: `global/skills/pr/SKILL.md` (§ `comments`, étape 1 puce « Fils », étape 2 première phrase)

- [ ] **Step 1: Puce « Fils »** — la requête lit aussi `last: comments(last: 1) { nodes { author { login } } }`, comme la statusline et `docs/domaine.md` (« Fil en attente de soi ») ; « dont le dernier commentaire n'est pas de soi » se lit sur `last`.
- [ ] **Step 2: Étape 2** — « Pour chaque fil » devient « Pour chaque retour » (le tri porte sur les fils et les points hors fil, R5).
- [ ] **Step 3: Vérifier** — `grep -n 'comments(last: 1)' global/skills/pr/SKILL.md` renvoie la puce « Fils » ; `grep -n 'Pour chaque fil' global/skills/pr/SKILL.md` vide ; `bash tests/run.sh` au vert.
- [ ] **Step 4: Commit** — `git add global/skills/pr/SKILL.md`, `✨ skills: Read the last thread author in /pr comments`.

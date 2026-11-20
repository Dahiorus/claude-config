# Contrôle YAGNI de la spec : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** avant sa première ouverture dans Plannotator, la spec passe au contrôle YAGNI d'un agent neuf,
`spec-yagni-checker`, en même temps que `ddd revue spec`.

**Architecture :** un agent en lecture seule (`global/agents/spec-yagni-checker.md`, sur le modèle de
`convergence-checker.md`), appelé par le § « Validation fonctionnelle » de `global/skills/feature/SKILL.md`. Pas de
script.

**Tech Stack :** Markdown (agents et skills Claude Code).

**Spec :** `docs/superpowers/specs/2026-11-20-yagni-spec-design.md`

## Découpage en PR

Une seule PR : 3 fichiers touchés hors spec et plan (`docs/domaine.md` déjà commité avec la spec).

## Contraintes globales

- Lignes de 120 colonnes au plus dans tout Markdown ajouté ou réécrit ; une ligne déjà plus longue ne se réécrit pas
  (`CLAUDE.md` du dépôt).
- Édition par Edit/Write uniquement, jamais `sed -i`, `python3 -c`, `printf` ni `echo` (`CLAUDE.md` du dépôt).
- Termes du glossaire (`docs/domaine.md`, contexte « Conception de feature ») : contrôle YAGNI, utilitaire existant,
  option spéculative, optimisation prématurée, écart. À ne pas dire : relecteur YAGNI, revue YAGNI, doublon,
  évolutivité, performance (au sens de l'optimisation prématurée).
- Commit par fichier (`git add <fichier>`), jamais `git add -A` : une autre session peut toucher `global/skills/*`.
- Commits : `Co-Authored-By: <modèle de l'implémenteur>`.
- Pas de test automatique des skills ni des agents : le « test » d'une tâche est un `git grep` qui échoue avant le
  texte (rouge) et réussit après (vert). `bash tests/run.sh` (timeout 580000) reste vert ; `test_links.sh` lie les
  agents par motif.

## Traçabilité

| Exigence (spec) | Tâche | Preuve |
|---|---|---|
| R1 agent Sonnet, lecture seule | Task 1 | grep `disallowedTools: Edit, Write, NotebookEdit` et `model: sonnet` dans l'agent |
| R1 trois sortes d'écarts, preuve `fichier:ligne` | Task 1 | grep « Utilitaire existant », « Option spéculative », « Optimisation prématurée » |
| R1 invariant de la demande initiale | Task 1 | grep « n'est jamais une option spéculative » dans l'agent |
| R2 entrée : spec et racine, sans l'avis de l'auteur | Task 1 | grep « Le chemin de la spec et la racine du dépôt » |
| R3 tri, option spéculative toujours « à trancher » | Task 1 | grep « toujours « à trancher » » dans l'agent |
| R3 rien à signaler : une ligne | Task 1 | grep « rien à signaler » dans l'agent |
| R4 étape 1, agent seul puis `ddd` au message suivant | Task 2 | grep « `spec-yagni-checker` » dans `feature` |
| R4 attendre les deux rapports | Task 2 | grep « avant le retour des deux » dans `feature` |
| R5 un point vu deux fois, texte déjà corrigé | Task 2 | grep « un seul bloc », « porte sur le texte corrigé » |
| R5 pas relancé ; rapport dans la conversation | Task 2 | grep « ne les relancent pas », « reste dans la conversation » |
| R6 pas de contrôle du plan | Task 2 | grep « plan n'y passe pas » |
| §2 « Exécution » : mêmes interdits | Task 2 | grep « `spec-yagni-checker` obéit aux mêmes interdits » |
| §2 reste à faire, point 3 cite l'agent | Task 3 | grep `spec-yagni-checker` dans `docs/reste-a-faire.md` |
| §2 reste à faire, point 2 rayé | Étape 5 de `feature` | `docs/reste-a-faire.md` |
| §4 critères d'acceptation, sur un cas réel | Recette (étape 6) | agent neuf sur la spec d'essai ci-dessous |

Usages vérifiés à l'étape 1b
(`git grep -n "spec-yagni\|Validation fonctionnelle\|validation fonctionnelle" -- . ':!docs/superpowers'`) :
`feature/SKILL.md` l. 20, 22, 137 et `docs/domaine.md`. L. 20 et 22 renvoient au § sans le détailler (inchangées,
spec §2) ; `docs/domaine.md` est déjà à jour (commit de la spec). Énumération des agents : `feature/SKILL.md` l. 170
(Task 2). `bugfix` n'a pas de spec, `ddd` écarte la qualité du code (l. 105).

Tâche de doc : la Task 3 (reste à faire). Aucun terme n'est retiré ni renommé : pas de grep de terme retiré.
Les tâches n'ont aucun fichier commun mais tiennent en quelques lignes : exécutées l'une après l'autre.

---

### Task 1 : agent `spec-yagni-checker`

Spec : R1, R2, R3.

**Files :**
- Create : `global/agents/spec-yagni-checker.md`

- [ ] **Step 1 : constater le rouge**

```bash
git grep -c "name: spec-yagni-checker" -- global/agents
```

Attendu : aucune sortie, code de retour 1.

- [ ] **Step 2 : écrire l'agent**

`global/agents/spec-yagni-checker.md`, texte exact :

```markdown
---
name: spec-yagni-checker
description: Contrôle YAGNI d'une spec avant sa première ouverture dans Plannotator (skill feature, validation fonctionnelle, étape 1) — cherche dans le code un utilitaire existant, une option spéculative ou une optimisation prématurée, et rend les écarts triés, sans rien modifier. Lancer avec model sonnet, passé explicitement.
model: sonnet
disallowedTools: Edit, Write, NotebookEdit
---

# Contrôle YAGNI de la spec

Tu lis une spec contre le code du dépôt, sans la conversation qui l'a produite ni l'avis de son auteur. Tu cherches
ce qu'elle prévoit d'écrire en trop. Tu ne juges ni le besoin métier (c'est `ddd revue`) ni la qualité du code
(c'est la review finale).

## Entrée (dans le brief)

Le chemin de la spec et la racine du dépôt. Rien d'autre.

## Ce qui se cherche

Lire la spec entière, § « Demande initiale » compris : c'est la référence. Puis, pour chaque élément que la spec
prévoit d'écrire (fonction, script, règle, skill, agent, option, mode, réglage, cas), chercher dans le code par
`git grep` sur tout le dépôt (`git grep -n "<terme>" -- . ':!docs/superpowers'`), jamais sur une liste de dossiers.
Trois sortes d'écarts :

- **Utilitaire existant** : le dépôt, ou un outil standard qu'il utilise déjà, fait déjà ce que la spec prévoit
  d'écrire. Preuve exigée : `fichier:ligne` de l'existant. Un élément voisin qui ne fait pas la même chose est
  écarté.
- **Option spéculative** : option, mode, réglage ou cas que la spec ajoute sans que la demande initiale le demande.
- **Optimisation prématurée** : cache, parallélisme ou détour écrit pour la vitesse sans lenteur constatée ni volume
  qui l'exige.

Un élément cité dans le § « Demande initiale » n'est jamais une option spéculative : à ce titre, il est écarté, avec
la citation. Il peut encore être un utilitaire existant (la demande prévoit d'écrire ce que le dépôt fait déjà).

## Tri

- **À corriger** : une seule correction raisonnable, sans effet sur le comportement ni la portée (réutiliser un
  utilitaire existant qui fait exactement la même chose, retirer une optimisation sans effet visible). Citer le
  passage et le texte corrigé.
- **À trancher** : le correctif change le comportement ou la portée, ou plusieurs options se valent. Une option
  spéculative est toujours « à trancher » : la retirer change la portée. 2-3 lignes : impact, options,
  recommandation.
- **Écarté** : élément examiné qui ne pose pas problème (cité par la demande, élément voisin qui ne fait pas la même
  chose), une ligne de raison.

## Interdits

- Éditer un fichier, commiter, changer de branche dans le dépôt de travail.
- Écrire dans la spec ou dans le dossier de suivi : le rapport va dans ta réponse.

## Refus du mode auto

Un refus « a hook changed this call's input » n'est pas un jugement : relancer l'appel seul, à l'identique, sans
autre appel dans le même message, une fois. Refusé encore → le dire dans la réponse, avec la commande.

## Réponse

Trois parties, dans cet ordre : **À corriger**, **À trancher**, **Écarté**. Chaque écart donne sa sorte (utilitaire
existant, option spéculative, optimisation prématurée), le § de la spec et sa preuve. Rien à signaler : la seule
ligne « rien à signaler ».
```

- [ ] **Step 3 : constater le vert**

```bash
git grep -n "name: spec-yagni-checker\|model: sonnet\|n'est jamais une option spéculative\|toujours « à trancher »\|Le chemin de la spec et la racine du dépôt\|rien à signaler" -- global/agents/spec-yagni-checker.md
awk 'length>120 && NR>5' global/agents/spec-yagni-checker.md
```

Attendu : six lignes trouvées par le grep ; `awk` n'imprime rien (seule la `description` du frontmatter dépasse,
comme dans les autres agents).

- [ ] **Step 4 : commit**

```bash
git add global/agents/spec-yagni-checker.md
git commit -m "✨ feature: Agent spec-yagni-checker

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 2 : la validation fonctionnelle lance le contrôle YAGNI

Spec : R4, R5, R6, §2 (« Exécution »).

**Files :**
- Modify : `global/skills/feature/SKILL.md:137-141` (§ « Validation fonctionnelle ») et `:172` (§ « Exécution »)

- [ ] **Step 1 : constater le rouge**

```bash
git grep -c "spec-yagni-checker" -- global/skills/feature/SKILL.md
```

Attendu : aucune sortie, code de retour 1.

- [ ] **Step 2 : § « Validation fonctionnelle »**

Remplacer, de « sans l'avis de l'auteur. Ses » jusqu'à « ou la portée. » (l. 138-141, la suite à partir de
« Pour une spec, avant d'appliquer » reste telle quelle) :

```markdown
sans l'avis de l'auteur. Pour une
spec, le contrôle YAGNI s'y ajoute : l'agent `spec-yagni-checker` (**Sonnet**, modèle passé explicitement), avec le
chemin de la spec et la racine du dépôt pour seule entrée, part en arrière-plan seul dans son message, puis `ddd revue
spec` au message suivant. Les deux tournent en même temps ; aucun écart ne s'applique avant le retour des deux. Un
plan n'y passe pas. Les « à corriger » de `ddd revue` et, pour une spec, du contrôle YAGNI s'appliquent avant
l'ouverture, leurs « à trancher » deviennent des blocs
`:::question` à l'endroit qu'ils touchent. Un point relevé par les deux donne une seule correction ou un seul bloc ;
un « à trancher » posé sur un passage qu'un « à corriger » de l'autre réécrit porte sur le texte corrigé. Le rapport
du contrôle YAGNI reste dans la conversation, comme celui de `ddd revue`. Les réouvertures suivantes ne les relancent
pas, sauf si les annotations changent le comportement ou la portée.
```

Recouper ensuite les lignes pour tenir sous 120 colonnes, sans changer un mot.

- [ ] **Step 3 : § « Exécution »**

Après la phrase qui finit par « et le contrôleur écrit le fichier. » (l. 172), ajouter sur une nouvelle ligne :

```markdown
`spec-yagni-checker` obéit aux mêmes interdits ; son rapport, rendu dans sa réponse, reste dans la conversation.
```

- [ ] **Step 4 : constater le vert**

```bash
git grep -n "spec-yagni-checker\|avant le retour des deux\|un seul bloc\|porte sur le texte corrigé\|ne les relancent pas\|reste dans la conversation\|plan n'y passe pas" -- global/skills/feature/SKILL.md
git diff -U0 global/skills/feature/SKILL.md | grep '^+' | awk 'length>121'
```

Attendu : le grep trouve chaque fragment (un fragment coupé par le recoupage des lignes se cherche par sa fin) ;
`awk` n'imprime rien.

- [ ] **Step 5 : commit**

```bash
git add global/skills/feature/SKILL.md
git commit -m "✨ feature: Contrôle YAGNI de la spec à la validation fonctionnelle

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 3 : reste à faire, point 3

Spec : — (doc), §2.

**Files :**
- Modify : `docs/reste-a-faire.md:16`

- [ ] **Step 1 : constater le rouge**

```bash
git grep -c "spec-yagni-checker" -- docs/reste-a-faire.md
```

Attendu : aucune sortie, code de retour 1.

- [ ] **Step 2 : citer l'agent**

Dans le point 3, remplacer « un agent de review, de convergence ou
   `ddd revue` qui expire » par « un agent de review, de convergence, `spec-yagni-checker` ou `ddd revue` qui
   expire », en recoupant les lignes sous 120 colonnes.

- [ ] **Step 3 : constater le vert**

```bash
git grep -n "spec-yagni-checker" -- docs/reste-a-faire.md
```

Attendu : une ligne du point 3.

- [ ] **Step 4 : commit**

```bash
git add docs/reste-a-faire.md
git commit -m "📝 todo: Citer spec-yagni-checker au point 3

Co-Authored-By: <modèle de l'implémenteur>"
```

---

## Recette (étape 6)

Un agent neuf exécute `spec-yagni-checker` sur la spec d'essai ci-dessous, écrite dans le dossier de suivi
(`spec-essai.md`). Si le type d'agent n'est pas proposé (session démarrée avant le lien), lancer
`bin/claude-config install` depuis le dépôt principal, puis à défaut un agent `general-purpose` en Sonnet dont le
brief est le corps de `global/agents/spec-yagni-checker.md`.

Spec d'essai :

```markdown
# Lien des agents

## 1. Demande initiale

> Ajouter un script qui lie chaque agent de `global/agents` dans `~/.claude/agents`,
> avec une option `--verbose`.

## Règles

R1 — Nouveau script `bin/link-agents` : lie chaque `global/agents/*.md` dans `~/.claude/agents`.
R2 — Option `--verbose` : affiche chaque lien créé.
R3 — Option `--dry-run` : affiche sans rien lier.
R4 — Les liens déjà faits sont gardés dans un cache JSON, `~/.claude/agents-cache.json`, pour aller plus vite.
```

Attendu, dans `recette.md` du dossier de suivi :

| Scénario | Attendu |
|---|---|
| R1 utilitaire existant, cité par la demande | relevé (pas écarté) avec `fichier:ligne` de `lib/links.sh` (l. 15-16, lien des agents un par un par `install`) |
| R2 option citée par la demande | écartée, avec la citation |
| R3 option spéculative | « à trancher », jamais « à corriger » |
| R4 optimisation prématurée | relevée |
| Lecture seule | `git status` inchangé après l'agent |

Le cas combiné de R5 (point vu par les deux contrôles) se vérifie à la lecture de la Task 2.

# Skill `pr` : un fichier par action

## But

`/pr push` ne charge plus les 408 lignes du skill : `SKILL.md` garde ce qui vaut pour toutes les actions et renvoie
chaque action longue à son propre fichier, lu seulement quand elle est demandée. Le texte des actions ne change pas.

## 1. Demande initiale

Issue #86, « pr/SKILL.md dépasse 200 lignes : le découper » :

> Constat : `global/skills/pr/SKILL.md` fait 405 lignes (361 avant la branche `feat/relecture-commentaires`), au-delà
> des 200 lignes de la grille qualité (point 7).
>
> Impact : chaque action (`push`, `review`, `comments`, `merge`…) charge tout le skill, même pour une seule.
>
> Piste : un fichier par action, chargé à la demande depuis `SKILL.md`.
>
> Origine : dette reportée, §7 de la spec `docs/superpowers/specs/2026-11-05-relecture-commentaires-design.md`.

Demande de l'utilisateur : `/feature issue 86`.

## 2. Portée

### R1 — Une action longue vit dans son fichier

Chaque action listée ci-dessous quitte `SKILL.md` pour `global/skills/pr/<action>.md`, texte déplacé tel quel
(titre `### <action>` devenu `# <action>`). Seuls changent les renvois d'une action à une autre (R3).

| Action | Lignes actuelles | Devient |
|---|---|---|
| `push` | 143-172 | `pr/push.md` |
| `squash` | 174-193 | `pr/squash.md` |
| `rebase` | 195-206 | `pr/rebase.md` |
| `recette` | 208-241 | `pr/recette.md` |
| `merge` | 243-284 | `pr/merge.md` |
| `review` | 286-354 | `pr/review.md` |
| `comments` | 356-392 | `pr/comments.md` |

Décision : seules les sept actions du tableau sortent. `test`, `switch` et les actions sans arbre (`list`, `view`,
`approvals`, `update-desc`) restent dans `SKILL.md`, qui passe sous 200 lignes ; un fichier de 4 lignes coûterait un
appel `Read` de plus pour rien.

### R2 — `SKILL.md` dit quel fichier lire

`SKILL.md` garde : l'introduction (compte gh, worktree, enchaînement des actions, agent Opus), « Dossier de suivi »,
« Aide », « Résoudre la PR », « Actions sans arbre », `switch`, « Arbre de la PR » avec ses préconditions, `test`, et
« Nettoyage des branches » (elle sert aussi à une PR fermée sans merge, pas seulement à `merge`).

À la place des sections déplacées, une table sous « Arbre de la PR » :

```markdown
| Action | Lire avant d'agir |
|---|---|
| `push` | `push.md` |
| `squash` | `squash.md` |
…
```

précédée d'une règle : « Les actions de cette table se lisent dans leur fichier, à côté de ce `SKILL.md`, avant la moindre commande.
Plusieurs actions à la suite : lire tous leurs fichiers avant la première commande. Un renvoi vers un autre fichier
(« étape 2 de `push.md` ») se lit au moment où il sert. Fichier introuvable → le dire et s'arrêter, ne jamais agir de
mémoire. Avant la première commande, une ligne de la réponse nomme les fichiers lus (« Lu : `squash.md`, `merge.md` ») ;
un fichier lu plus tard par renvoi a sa propre ligne avant la commande suivante (« Lu : `push.md`, étape 2 »). Sans
elles, l'utilisateur voit que la lecture a sauté. Action hors table (`help`, `view`, `test`, `switch`, `list`…) : pas de ligne « Lu ». » L'« Aide » ne change
pas.

Décision (retour `pr-risk` de la PR #89, « échec silencieux ») : rien n'oblige techniquement le modèle à lire le
fichier d'action ; la ligne « Lu : … » rend l'oubli visible au lieu de silencieux. Un hook qui bloquerait les commandes
tant que le fichier n'est pas lu est écarté : il devrait suivre, d'un appel à l'autre, quelle action est en cours et
quels fichiers sont lus, pour un seul skill.

Décision : actions enchaînées (`/pr push recette`, `/pr 42 squash merge`) → tous leurs fichiers se lisent avant la
première commande, pour que les refus propres à chaque action (les préconditions communes sont déjà dans `SKILL.md`)
soient connus avant le premier push. La règle de R2 le dit : « Plusieurs actions à la suite : lire tous leurs fichiers
avant la première commande. »

### R3 — Renvois d'une action à une autre

Les renvois internes deviennent des renvois de fichier, que le lecteur suit en lisant le fichier cité :

| Renvoi actuel | Où | Devient |
|---|---|---|
| « étape 2 de `push` » | `merge` étapes 1 et 3 | « étape 2 de `push.md` » |
| « étapes de `squash` », « étape 1 de `squash` », « comme dans `squash` » | `merge` étape 3 | idem avec `squash.md` |
| « étape **Issues** de `push` » | `merge` étape 6 | « étape **Issues** de `push.md` » |
| « (agent Sonnet, comme `recette`) » | `merge` étape 4 | « comme l'action `recette` (`recette.md` du skill `pr`) » : `recette.md` seul désigne aussi le fichier de suivi des résultats |
| « section « Nettoyage des branches » » | `merge` étape 5 | « section « Nettoyage des branches » de `SKILL.md` » |
| « (`approvals`) » | `squash` étape 3, `rebase` étape 5 | « (`approvals`, `SKILL.md`) » |
| « comme à l'étape 1 de `comments` » | `review` étape 0 | « comme à l'étape 1 de `comments.md` » (voir la décision ci-dessous) |
| « comme pour `recette` » | `comments` étape 2 | « comme pour l'action `recette` (`recette.md` du skill `pr`) » |
| « voir `push` » | « Résoudre la PR » (`SKILL.md:73`) | « voir `push.md` » |
| « comme `push` » (`Closes #n`) | `update-desc` (`SKILL.md:101`) | « comme `push.md` » : la règle est déjà écrite en entier sur place, le renvoi ne sert qu'au parallèle |
| « (`update-desc`) » | `push` étape 4 | « (`update-desc`, `SKILL.md`) » |
| « l'agent Opus » | `squash`, `rebase`, `merge` | inchangé : défini dans l'introduction de `SKILL.md`, déjà chargée |
| « Dossier de suivi », « Arbre de la PR » | toutes | inchangé : sections de `SKILL.md` |

Décision : les exclusions communes à `review` et `comments` (commentaire `<!-- pr-risk -->`, auteurs `Bot`) gardent
leur forme actuelle : `review` étape 0 les nomme et renvoie à l'étape 1 de `comments.md` pour le détail. L'issue
demande un déplacement, pas une réécriture.

### R4 — Renvois depuis les autres skills

| Endroit | Texte actuel | Devient |
|---|---|---|
| `global/skills/feature/SKILL.md:28` (étape 7) | « règles de `/pr review` (skill `pr`, § `review`, étape 2) » | « règles de `/pr review` (`~/.claude/skills/pr/review.md`, étape 2) » : le chemin, car la session `feature` n'a pas chargé `pr` |
| `global/skills/bugfix/SKILL.md:36` (étape 8) | même texte | même remplacement |
| `feature/SKILL.md:27-28`, `bugfix/SKILL.md:36` | « skill `pr`, « Dossier de suivi » » | inchangé : la section reste dans `SKILL.md` |
| `feature/SKILL.md:27` | « comme dans `/pr recette` » | « comme dans `/pr recette` (`~/.claude/skills/pr/recette.md`, étape 3) » : la règle « un appel par scénario » ne vit plus que là, et la session `feature` n'a pas chargé `pr` |
| `docs/domaine.md:33` (Relecture de PR) | « Dans le code : `global/skills/pr/SKILL.md` § `review` » | « `global/skills/pr/review.md` » |
| `docs/domaine.md:59` (Retours de PR) | « … § `comments` » | « `global/skills/pr/comments.md` » |
| `docs/domaine.md:72` (Livraison) | « … § `merge` » | « `global/skills/pr/merge.md` » |
| `docs/domaine.md`, autres lignes | citent `/pr review`, `/pr` | inchangé : noms de commandes |
| specs et plans de `docs/superpowers/` | citent des § du skill | inchangés : documents datés, ils décrivent l'état d'alors |

### R5 — Installation

`~/.claude/skills/pr` est un lien vers `global/skills/pr` (dossier entier) : les nouveaux fichiers y sont visibles sans
changer `bin/claude-config`. Inchangé.

## 3. Données existantes

Aucune donnée : les dossiers de suivi (`.superpowers/sdd/*`) ne citent pas les sections du skill.

## 4. Critères d'acceptation

**Story P1 — l'action lit son fichier** (seule story : le découpage ne se livre pas à moitié).

- `wc -l global/skills/pr/SKILL.md` ≤ 200.
- Chaque fichier de la table de R2 existe, et chaque `*.md` de `global/skills/pr/` autre que `SKILL.md` est dans la
  table.
- Texte déplacé intact : la concaténation des sept fichiers, titres et renvois de R3 mis à part, est identique aux
  lignes 143-392 de `SKILL.md` sur `main` (lignes vides de séparation mises à part).
- `/pr 42 push` : la session lit `SKILL.md` puis `push.md`, pas les autres fichiers.
- `/pr 42 squash merge` (cas combiné) : `squash.md` et `merge.md` lus avant la première commande ; `merge.md` renvoie
  à l'étape 2 de `push.md`, lu au moment où ce renvoi sert.
- `/pr push recette` (cas combiné) : `push.md` et `recette.md` lus avant le premier `git push`.
- `/pr 42 test`, `/pr 42 switch`, `/pr list` : aucun fichier d'action lu.
- Chaque fois qu'un fichier d'action est lu : la ligne « Lu : … » qui le nomme précède la première commande, ou la
  commande suivante pour un fichier lu par renvoi (`/pr 42 merge` : « Lu : `squash.md` » avant le squash).
- Ces parcours se vérifient en vrai, par des agents qui invoquent le skill `pr` sans exécuter de commande (aucun test
  bash ne voit ce que lit le modèle), résultat dans `recette.md` du dossier de suivi.
- Fichier d'action absent (lien cassé) : la session le dit et s'arrête, sans agir.
- `feature` étape 7, `bugfix` étape 8 : la consigne de l'agent Opus cite `~/.claude/skills/pr/review.md` étape 2, qui
  contient bien les règles « Erreur avalée » et « Test absent ».
- `/pr help` : bloc d'aide inchangé, octet pour octet.
- Aucun renvoi de R3 ni de R4 ne reste sous sa forme sans `.md` dans `global/` ni dans `docs/domaine.md` ; le grep
  couvre `§`, `étape(s) … de`, `comme (dans|pour)?` et `voir` suivis d'une action en backticks.

## 5. Filet sur l'existant

Le skill est du texte : pas de test de comportement possible. Le filet est la vérification du texte déplacé
(critère 3), faite par un `diff` dans le plan, et un nouveau test `tests/test_skills.sh` (pris par le motif
`test_*.sh` de `tests/run.sh`) qui garde le lien entre la table de
R2 et les fichiers présents (critère 2), pour qu'un fichier renommé ou oublié se voie.

## 6. Origine

| Point | Origine |
|---|---|
| Découpage de `pr/SKILL.md` | *dette* reportée, §7 de `docs/superpowers/specs/2026-11-05-relecture-commentaires-design.md` ; issue #86 |

## 7. Dette du code touché

| Fichier | Écart | Décision |
|---|---|---|
| `global/skills/pr/SKILL.md` | 408 lignes, au-delà de 200 (grille, point 7) | corrigé dans cette PR |
| `global/skills/feature/SKILL.md` | 227 lignes avant la branche ; R4 remplace un renvoi sans ajouter de ligne | reporté : la grille ne le signale que s'il grossit de plus de deux lignes |
| `global/skills/bugfix/SKILL.md` | 64 lignes | — |

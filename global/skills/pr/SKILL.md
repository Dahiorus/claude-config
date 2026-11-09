---
name: pr
description: Use when the user invokes /pr, or asks to list the current repo's pull requests (or those awaiting my review) or act on one — show, check out, test, push and open, squash, rebase, recette, merge, rewrite its description, review it or address its review comments (« pousse et crée la PR », « squash et merge », « relis la PR 114 », « quelles PR dois-je relire ? », « traite les commentaires de alice »).
model: sonnet
argument-hint: "list | <n°|branche> [action…] [consigne]"
---

# PR

Sans `/pr`, l'action vient de la demande : `squash`, `rebase`, `merge` et `review` seulement si l'utilisateur les
nomme, jamais déduites.

`view` par défaut. Plusieurs actions à la suite (`/pr 81 squash update-desc`, `/pr push recette`) s'exécutent dans
l'ordre, arrêt au premier échec ; chaque action attend la fin de la précédente, agents compris (`review comments` :
`comments` ne lit les fils qu'une fois la review publiée ; sur sa propre PR, la paire reprend selon l'étape 6 de
`comments.md`). Le texte libre qui suit les actions est une consigne pour elles (« en mode boîte
noire », « la partie front », « de amercadal »). La PR est cherchée dans le dépôt courant uniquement. Les commandes `gh`
et les `git push`, `git fetch` et `git pull` passent par le compte du profil du projet (`bash ~/.claude/profile.sh account` ; vide sans profil : compte actif), en jeton ponctuel testé, en une commande : `t=$(gh auth token -u <compte>); [ -n "$t" ] && GH_TOKEN=$t gh …` (même forme devant `git push`, `fetch` et `pull` ; sur un dépôt privé, un `fetch` sans jeton répond « Repository not found » et laisse `origin/main` périmée), jamais le jeton recopié en clair ; jeton vide → s'arrêter (gh prendrait le compte actif), jamais par `gh auth switch`. Les étapes écrivent `git fetch`, `git pull` et `git push` sans ce préfixe : il s'ajoute à chacune. En session `EnterWorktree`, Claude Code
refuse `git -c …` et `VAR=… git/gh …` (commandes `gh` à jeton comprises) : `ExitWorktree` avec `action: "keep"`, puis lancer fetch, pull et push depuis le dépôt principal. Le classifieur du mode auto peut refuser `gh pr merge` et le push forcé de `rebase` et `squash` : donner alors d'emblée la commande à lancer avec `!`. Seul `switch` change la branche de l'arbre
courant, et seulement s'il est propre : les autres actions travaillent dans l'arbre de la PR, le travail en cours n'est
pas touché. Ce skill porte toutes les étapes d'une PR, qu'elle vienne de `feature`, de `bugfix` ou de `release` ;
`feature` reste la référence pour le tri des retours et la grille qualité. Les étapes qui demandent du jugement
(tri des reliquats, découpage d'une PR volumineuse, conflits de rebase, leçons, tri de plus de 3 retours de
`comments`) passent par un agent `general-purpose` (modèle `opus` passé explicitement), qui rend sa décision :
la session l'applique.

## Dossier de suivi

La conversation peut être effacée (`/clear`) à tout moment : rien ne s'appuie sur elle d'une invocation à l'autre.
Ce qui doit durer vit dans `<racine>/.superpowers/sdd/<sujet>/`, où `<racine>` est le dépôt principal (premier chemin
de `git worktree list`, même depuis un worktree) et `<sujet>` le nom de la branche sans son préfixe `<type>/`
(`feat/x` → `x`, `feat/x-p2` → `x-p2`). À la première écriture, ajouter `.superpowers/` à
`$(git rev-parse --git-common-dir)/info/exclude` s'il n'y est pas : sinon `switch` voit l'arbre « pas propre ».

- `final-review.md` : retours de review et commentaires de PR, triés (`feature`, `bugfix`, `comments`) ;
- `recette.md` : chaque recette, datée : environnement, scénarios et résultat, correctifs (SHA), ce qui reste ;
- `ponytail-review.md`, `opus-review.md` : rapport complet de chaque review (`feature` étape 7, `bugfix` étape 8) ;
  `convergence-N.md` : sortie du tour N de convergence (`feature` étape 5b). Écrits par le contrôleur à partir de
  la réponse de l'agent, dont le brief interdit d'écrire dans le dossier de suivi ;
- `lecons.md` : une ligne datée par friction (correction de l'utilisateur, commande refusée, piège, consigne
  oubliée), ajoutée en fin de session de travail sur la branche (`feature` étape 7, `bugfix` étape 8, `push`, `squash`,
  `recette`, `comments`, `rebase`, `merge` avant son étape 2, puis à la fin pour la PR suivante). Rien à noter → rien.

## Aide

`/pr` ou `/pr help` → afficher ce bloc tel quel, sans rien faire d'autre. Action inconnue proche d'une action connue
(`viw`, `sswitch`) → proposer celle-ci et attendre ; sinon la nommer et afficher ce bloc.

```text
/pr <n°|branche> [action…] [consigne]   PR du dépôt courant, « view » par défaut

  list          liste les PR du dépôt (sans n°) : open par défaut, closed, à relire
  view          affiche la PR
  approvals     compte les approbations (2 = prête pour la QA)
  switch        extrait la branche ici ; arbre pas propre → propose son worktree
  test          lance la vérification du projet dans l'arbre de la PR
  push          pousse les commits tels quels, crée la PR ou met à jour sa description
  squash        réécrit en un commit (un par pan fonctionnel si PR volumineuse), push forcé
  rebase        rebase sur origin/main, résout les conflits, push forcé
  recette       déroule la recette (env. de la PR, sinon local), corrige, pousse ; retours en
                liste numérotée écran + élément + observé + attendu + périmètre
  merge         reliquats faisables traités dans la PR, leçons, squash si besoin, merge en rebase,
                déploiement, nettoyage, pièges et décisions en mémoire
  update-desc   réécrit la description d'après les commits et le suivi
  review        relit la PR (la sienne comprise), évalue sa criticité (relecture humaine requise ?),
                publie les commentaires, ou approuve si rien n'est nouveau et la relecture demandée
  comments      traite les fils et commentaires en attente, corrige, pousse, répond
  help          cette aide

Exemples : /pr list · /pr list closed · /pr list à relire · /pr 42 · /pr 42 switch · /pr push recette · /pr 42 squash merge · /pr 42 review la partie front
           /pr 42 comments de alice · /pr main switch
```

## Résoudre la PR

`gh pr view <n°|branche> --json number,headRefName,isCrossRepository,state`. Introuvable → le dire et s'arrêter
(PR d'un autre dépôt : lancer `/pr` depuis ce projet). Ne visent pas de PR : `/pr list`, `/pr main switch`, et `push` sur une
branche qui n'a pas encore de PR (`/pr push` sans référence vise la branche courante, `main` comprise : voir `push.md`).

## Actions sans arbre

- **`list`** — tableau markdown, rendu tel quel dans la réponse (pas dans un bloc de code) ; la consigne se traduit en
  options `gh` (`open` ou « ouvertes » → défaut, `closed` ou « fermées » → `--state closed`, « toutes » → `--state all`, « de alice » → `--author alice`,
  « les miennes » → `--author @me`, « à relire » → `--search "review-requested:@me"` (sous jeton ponctuel, `@me` =
  soi ; demandes à une équipe comprises), dépôt courant seulement ; aucune → « aucune PR ne demande ta relecture ») :

  ```bash
  gh pr list --json number,title,headRefName,state,isDraft,author,updatedAt --jq '
    "| N° | Titre | Branche | État | Auteur | Mise à jour |", "|---|---|---|---|---|---|",
    (.[] | "| #\(.number) | \(.title | gsub("\\|"; "\\|")) | `\(.headRefName)` | \(if .isDraft then "DRAFT" else .state end) | \(.author.login) | \(.updatedAt[:10]) |")'
  ```
- **`view`** — `gh pr view <n°>` et rendre la sortie telle quelle.
- **`approvals`** — dernier avis décisif de chaque relecteur (un `COMMENTED` n'annule pas une approbation) :

  ```bash
  gh pr view <n°> --json reviews --jq '[.reviews[] | select(.state != "COMMENTED" and .state != "PENDING")]
    | group_by(.author.login) | map(max_by(.submittedAt)) | map(select(.state == "APPROVED") | .author.login)'
  ```

  Rapport : `2/2 approbations (alice, bob) → prête pour la QA`, ou `1/2 (alice) — il en manque 1`. Au-delà de 2,
  toujours prête. Signaler aussi les `CHANGES_REQUESTED` encore actifs.
- **`update-desc`** — l'invocation vaut demande de réécrire la description. Sources : le dossier de suivi
  (`recette.md`, `final-review.md`), puis les commits de la PR que la description ne reflète pas encore
  (`gh pr view <n°> --json body,commits,files`). Suivre le format de description du projet (AGENTS.md, CLAUDE.md,
  CONTRIBUTING.md, `.github/pull_request_template.md`), en français, fonctionnelle : elle décrit l'état final de la
  PR, pas l'historique des correctifs, sans détail d'un autre projet (nom, PR, taille, venus d'une autre session). Garder les lignes `Closes #n` (et en ajouter une par issue que la PR règle entièrement, comme `push.md`) et tel quel ce que l'auteur n'a pas écrit (bloc d'un bot de déploiement en
  tête, comme `<span id="carmen">…</span>`), les liens et les sections inchangées ; ne pas toucher au titre. Rien à
  changer → le dire. Sinon texte passé par `humanizer:humanizer` puis relu contre le diff (comme `push.md` étape 4), `gh pr edit <n°> --body-file <fichier>`, puis rapport : sections modifiées et pourquoi.

## `switch`

1. Session dans un worktree (entrée par `EnterWorktree`) → d'abord `ExitWorktree` avec `action: "keep"`, pour ne pas
   changer la branche d'un worktree nommé d'après une autre PR. La suite se joue dans le dépôt principal.
2. Branche déjà extraite dans un autre worktree (`git worktree list`) → `EnterWorktree` avec `path: <ce chemin>`.
3. Arbre courant propre (`git status --porcelain` vide) → `gh pr checkout <n°>` (branche locale suivie, PR de fork
   comprises), puis `git pull --ff-only` si la branche existait déjà.
4. Arbre courant pas propre → ne rien stasher. Lister les fichiers en cause et proposer d'ouvrir la PR dans son
   worktree (`EnterWorktree` sur le chemin de « Arbre de la PR ») ; refus → s'arrêter.

`/pr main switch` : depuis un worktree, `ExitWorktree` avec `action: "keep"` (le worktree reste sur le disque) ; si la
session n'était pas entrée par `EnterWorktree`, donner le chemin du dépôt principal à ouvrir. Dans le dépôt principal
propre : `git switch main && git pull --ff-only` ; pas propre → le dire et s'arrêter.

## Arbre de la PR (`test`, `push`, `squash`, `rebase`, `recette`, `merge`, `review`, `comments`)

Branche déjà extraite quelque part (`git worktree list` la montre, arbre courant compris) → travailler dans ce chemin.
Sinon worktree `<racine>.worktrees/pr-<n°>`, à côté du dépôt, où `<racine>` est le premier chemin de
`git worktree list` (le dépôt principal) :

1. Worktree absent → `git fetch origin <headRefName>`, puis : branche locale existante →
   `git worktree add <chemin> <headRefName>` (ne pas l'écraser) ; sinon
   `git worktree add <chemin> -B <headRefName> --track origin/<headRefName>`. PR d'un fork (`isCrossRepository`) :
   `git fetch origin pull/<n°>/head` puis `git worktree add --detach <chemin> FETCH_HEAD`.
2. Worktree présent → arbre propre : `git -C <chemin> pull --ff-only` ; modifications non commitées ou pull refusé :
   ne rien toucher, le signaler, continuer sur l'état local.

`push` sur une branche sans PR qui n'est extraite nulle part → le dire et s'arrêter.

Préconditions communes à `push`, `squash`, `rebase`, `merge` et `comments` (s'arrêter et le dire si l'une manque) :
branche ≠ `main` (sauf `push`, qui crée alors sa branche) ; arbre propre, ou modifications en cours à intégrer (les lister et demander avant de les commiter) ; PR de fork
ou `state` ≠ `OPEN` → refuser, sauf `push` qui n'a pas encore de PR.

### `test`

Lancer la vérification du projet (commande du CLAUDE.md, installation des dépendances comprise si le worktree est
neuf) dans l'arbre de la PR, sans quitter l'arbre courant. Rapporter le résultat et lire la sortie : rouge se dit rouge.

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

## Nettoyage des branches

Après un merge, ou une PR fermée sans merge. Branche d'une PR fermée sans merge dont le contenu n'est pas dans main
(ni intégré dans une autre PR) : demander avant de la supprimer, ses commits seraient perdus. Branche gardée pour
une nouvelle PR : retirer la marque « livrée » de la story dans son plan.

1. **Worktrees** — chaque worktree où la branche est extraite (`git worktree list --porcelain`), `pr-<n°>` compris.
   Dépôt principal : `git switch main && git pull --ff-only`. Autre worktree propre : `git worktree remove <chemin>`
   (session dedans : `ExitWorktree` avec `action: "keep"` d'abord). Pas propre → le laisser et le dire. Puis
   `git worktree prune`.
2. **Branche locale** — `git branch -D` une fois vérifié que main contient son contenu (`git diff --quiet origin/main
   <branche> -- $(git diff --name-only origin/main...<branche>)`) : un merge en rebase change les SHA, `-d` refuse. Écart → le montrer et demander.
3. **Branche distante** — sauf si le dépôt la supprime au merge (`gh api repos/<owner/repo> --jq
   .delete_branch_on_merge`) : `git push origin --delete <branche>…`, toutes les branches en un appel. Refusé
   (permissions) → donner la commande prête à lancer avec `!`.

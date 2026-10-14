---
name: pr
description: Agit sur une PR du dépôt courant sans git checkout — « view » (défaut) l'affiche, « approvals » compte les approbations (2 = prête pour la QA), « switch » bascule la session dans son worktree, « test » lance la vérification dans son worktree, « rebase » la rebase sur origin/main, résout les conflits et pousse, « recette » déroule les scénarios et les retours de recette sur l'environnement dédié de la PR ou en local, corrige et pousse, « update-desc » met à jour sa description d'après les retours de Claude dans la session. Invoqué par /pr <n°|branche> [view|approvals|switch|test|rebase|recette|update-desc].
disable-model-invocation: true
argument-hint: "<n°|branche> [view|approvals|switch|test|rebase|recette|update-desc]"
---

# PR

Une action par invocation, `view` par défaut. La PR est cherchée dans le dépôt courant uniquement. Les commandes `gh`
passent par le compte indiqué par la mémoire du projet (jeton ponctuel `GH_TOKEN=$(gh auth token -u <compte>)`, sans
changer le compte actif). Jamais de `git checkout`/`git switch` dans l'arbre courant : le travail en cours n'est pas
touché.

## Résoudre la PR

`gh pr view <n°|branche> --json number,headRefName,isCrossRepository,state`. Introuvable → le dire et s'arrêter
(PR d'un autre dépôt : lancer `/pr` depuis ce projet). Seul `/pr main switch` ne vise pas de PR.

## Actions sans worktree

- **`view`** — `gh pr view <n°>` et rendre la sortie telle quelle.
- **`approvals`** — dernier avis décisif de chaque relecteur (un `COMMENTED` n'annule pas une approbation) :

  ```bash
  gh pr view <n°> --json reviews --jq '[.reviews[] | select(.state != "COMMENTED" and .state != "PENDING")]
    | group_by(.author.login) | map(max_by(.submittedAt)) | map(select(.state == "APPROVED") | .author.login)'
  ```

  Rapport : `2/2 approbations (alice, bob) → prête pour la QA`, ou `1/2 (alice) — il en manque 1`. Au-delà de 2,
  toujours prête. Signaler aussi les `CHANGES_REQUESTED` encore actifs.
- **`update-desc`** — l'invocation vaut demande de réécrire la description. Sources : les retours de Claude dans la
  session (recette, correctifs, review, rebase), puis les commits de la PR que la description ne reflète pas encore
  (`gh pr view <n°> --json body,commits,files`). Suivre le format de description du projet (AGENTS.md, CLAUDE.md,
  CONTRIBUTING.md, `.github/pull_request_template.md`), en français, fonctionnelle : elle décrit l'état final de la
  PR, pas l'historique des correctifs. Garder tel quel ce que l'auteur n'a pas écrit (bloc d'un bot de déploiement en
  tête, comme `<span id="carmen">…</span>`), les liens et les sections inchangées ; ne pas toucher au titre. Rien à
  changer → le dire. Sinon `gh pr edit <n°> --body-file <fichier>`, puis rapport : sections modifiées et pourquoi.

## Worktree de la PR (`switch`, `test`, `rebase`, `recette`)

Emplacement : `<racine>.worktrees/pr-<n°>`, à côté du dépôt, où `<racine>` est le premier chemin de
`git worktree list` (le dépôt principal).

1. Branche déjà extraite ailleurs (`git worktree list` la montre, y compris dans le dépôt principal) → utiliser ce
   chemin, ne pas en créer un second.
2. Worktree absent → `git fetch origin <headRefName>` puis
   `git worktree add <chemin> -B <headRefName> --track origin/<headRefName>`. PR d'un fork (`isCrossRepository`) :
   `git fetch origin pull/<n°>/head` puis `git worktree add --detach <chemin> FETCH_HEAD`.
3. Worktree présent → arbre propre : `git -C <chemin> pull --ff-only` ; modifications non commitées ou pull refusé :
   ne rien toucher, le signaler, continuer sur l'état local.

### `switch`

Session déjà dans un worktree → d'abord `ExitWorktree` avec `action: "keep"` : hors de `.claude/worktrees/`,
`EnterWorktree` refuse de passer directement d'un worktree à un autre, mais accepte tout chemin depuis le répertoire de
lancement. Puis `EnterWorktree` avec `path: <chemin>`. `/pr main switch` : `ExitWorktree` avec `action: "keep"` (le worktree reste
sur le disque) ; si la session n'était pas entrée par `EnterWorktree`, donner le chemin du dépôt principal à ouvrir.

### `test`

Lancer la vérification du projet (commande du CLAUDE.md, installation des dépendances comprise si le worktree est
neuf) dans `<chemin>`, sans quitter l'arbre courant. Rapporter le résultat et lire la sortie : rouge se dit rouge.

### `rebase`

L'invocation vaut demande de réécrire la branche et de la pousser. PR de fork ou `state` ≠ `OPEN` → refuser.

1. Arbre du worktree propre, sinon s'arrêter. Noter le SHA local et le SHA distant (`git rev-parse
   origin/<headRefName>`) : retour par `git reset --hard <sha>`.
2. `git fetch origin main`, puis `git rebase origin/main` dans le worktree.
3. Conflits : lire les deux versions et garder l'intention de chacune, fichier par fichier ; jamais `--ours`/`--theirs`
   en bloc. Intention ambiguë → montrer le conflit et attendre la décision (rebase laissé en cours).
4. Vérification du projet dans le worktree. Rouge → ne pas pousser, rapporter, laisser le worktree en l'état.
5. Approbations existantes (`approvals`) → prévenir qu'un push forcé peut les invalider, puis pousser :
   `git push --force-with-lease=<headRefName>:<SHA distant noté> origin <headRefName>`, jamais `--force` seul.
6. Rapport : commits rejoués, fichiers en conflit et résolution choisie, résultat des tests, nouveau SHA.

### `recette`

Exécuter la recette sur l'environnement dédié de la PR ou, à défaut, sur l'application lancée depuis le worktree, puis
corriger. Les retours de l'utilisateur viennent avec l'invocation ou dans le message qui suit (liste numérotée écran +
élément + observé + attendu + périmètre).

1. **Scénarios** — les retours de l'utilisateur, plus la recette prévue par la PR (description, plan commité sur la
   branche). Aucun des deux → déduire les scénarios de la description et du diff, les lister et attendre l'accord.
2. **Environnement** — la PR a un environnement dédié si son titre se termine par `[DEPLOY_PR][<env-id>]` (convention
   de renoshield) : son lien est dans la description, dans le bloc ajouté par le déploiement
   (`:heavy_check_mark: … http://…-<env-id>…`). Bloc présent et marqué réussi → recetter sur ce lien, sans lancement
   local. Sinon (pas de tag, bloc absent ou en échec, lien injoignable) → le dire et démarrer l'application dans
   `<chemin>` (commande du CLAUDE.md du projet, dépendances installées si le worktree est neuf), en arrière-plan. Port
   déjà pris ou service injoignable : le diagnostiquer, ne pas recetter une autre instance.
3. **Exécution** — chaque scénario étape par étape (Playwright pour une interface web), avec observé et attendu.
   Rapport : un tableau scénario → conforme / non conforme, capture d'écran à l'appui des écarts.
4. **Correctifs** — les retours de l'utilisateur valent demande de correction ; un écart trouvé par un scénario déduit
   se propose d'abord. Appliquer la règle générale plutôt que le cas, sur tout le périmètre indiqué. Intention ambiguë
   ou changement de comportement non prévu par la spec → demander. Puis vérification du projet et nouvelle exécution
   des scénarios touchés, en local : rouge → ne pas pousser, rapporter. Sur environnement dédié, les rejouer aussi
   après le push, une fois le build du nouveau SHA au vert (redéploiement).
5. **Push** — nouveaux commits au format de `CONTRIBUTING.md`, `push` simple, sans réécriture ni squash. PR de fork ou
   `state` ≠ `OPEN` → corriger dans le worktree sans pousser, et le dire.
6. **Arrêt** — arrêter l'application lancée en local. Rapport : environnement recetté (lien ou local), scénarios et
   résultat, correctifs (SHA), ce qui reste.

## Nettoyage

L'étape Nettoyage de `/pr-deliver merge` supprime le worktree de la branche mergée. Worktree d'une PR fermée sans merge :
`git worktree remove <chemin>` après avoir vérifié qu'il est propre.

---
name: pr
description: Agit sur une PR du dépôt courant — « view » (défaut) l'affiche, « approvals » compte les approbations (2 = prête pour la QA), « switch » extrait sa branche dans l'arbre courant (worktree proposé si l'arbre n'est pas propre), « test » lance la vérification, « push » pousse la branche et crée ou met à jour la PR, « squash » réécrit l'historique en un commit (ou un par pan fonctionnel si la PR est volumineuse) et pousse, « rebase » la rebase sur origin/main, résout les conflits et pousse, « recette » déroule les scénarios et les retours de recette sur l'environnement dédié de la PR ou en local, corrige et pousse, « merge » squashe puis merge en rebase, suit le déploiement, nettoie et met à jour la mémoire, « update-desc » met à jour sa description d'après les retours de Claude dans la session, « help » affiche la syntaxe et les actions. Invoqué par /pr <n°|branche> [view|approvals|switch|test|push|squash|rebase|recette|merge|update-desc|help].
disable-model-invocation: true
argument-hint: "<n°|branche> [view|approvals|switch|test|push|squash|rebase|recette|merge|update-desc|help]"
---

# PR

Une action par invocation, `view` par défaut. La PR est cherchée dans le dépôt courant uniquement. Les commandes `gh`
et les `git push` passent par le compte indiqué par la mémoire du projet (jeton ponctuel
`GH_TOKEN=$(gh auth token -u <compte>)`, sans changer le compte actif). Seul `switch` change la branche de l'arbre
courant, et seulement s'il est propre : les autres actions travaillent dans l'arbre de la PR, le travail en cours n'est
pas touché. `push`, `squash` et `merge` reprennent les étapes 8 à 13 du skill `feature`, qui reste la
référence (règles, signaux d'alarme).

## Aide

`/pr`, `/pr help` ou action inconnue → afficher ce bloc tel quel (action inconnue : la nommer avant), sans rien faire
d'autre :

```text
/pr <n°|branche> [action]      PR du dépôt courant, action « view » par défaut

  view          affiche la PR
  approvals     compte les approbations (2 = prête pour la QA)
  switch        extrait la branche ici ; arbre pas propre → propose son worktree
  test          lance la vérification du projet dans l'arbre de la PR
  push          pousse les commits tels quels, crée la PR ou met à jour sa description
  squash        réécrit en un commit (un par pan fonctionnel si PR volumineuse), push forcé
  rebase        rebase sur origin/main, résout les conflits, push forcé
  recette       déroule la recette (env. dédié ou local), corrige, pousse ; retours en
                liste numérotée écran + élément + observé + attendu + périmètre
  merge         squash si besoin, merge en rebase, déploiement, nettoyage, mémoire
  update-desc   réécrit la description d'après la session et les commits
  help          cette aide

Exemples : /pr 42 · /pr 42 switch · /pr push · /pr feat/x push · /pr 42 merge · /pr main switch
```

## Résoudre la PR

`gh pr view <n°|branche> --json number,headRefName,isCrossRepository,state`. Introuvable → le dire et s'arrêter
(PR d'un autre dépôt : lancer `/pr` depuis ce projet). Ne visent pas de PR : `/pr main switch`, et `push` sur une
branche qui n'a pas encore de PR (`/pr push` sans référence vise la branche courante).

## Actions sans arbre

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

## Arbre de la PR (`test`, `push`, `squash`, `rebase`, `recette`, `merge`)

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

Préconditions communes à `push`, `squash`, `rebase` et `merge` (s'arrêter et le dire si l'une manque) : branche ≠
`main` ; arbre propre, ou modifications en cours à intégrer (les lister et demander avant de les commiter) ; PR de fork
ou `state` ≠ `OPEN` → refuser, sauf `push` qui n'a pas encore de PR.

### `test`

Lancer la vérification du projet (commande du CLAUDE.md, installation des dépendances comprise si le worktree est
neuf) dans l'arbre de la PR, sans quitter l'arbre courant. Rapporter le résultat et lire la sortie : rouge se dit rouge.

### `push`

L'invocation vaut demande explicite de pousser et d'ouvrir la PR. Jamais de squash ni de réécriture : une PR peut
porter plusieurs commits ; un historique désordonné se signale au plus dans le rapport.

1. Vérification au vert dans cette session, sinon la lancer et lire la sortie. Rouge → on ne pousse pas.
2. `git push` simple (`-u origin <branche>` la première fois).
3. Aucune PR ouverte pour la branche : `gh pr create` (titre = sujet du commit ou de la feature, description
   fonctionnelle en français). PR existante : mettre à jour la description si le périmètre a changé (`update-desc`).
4. Rapport : commit(s), lien de la PR, ce qui reste (recette, review). Terminer par ce rappel, mot pour mot :
   « Recette : `/clear`, puis `/pr N recette` avec tous les retours en un message — liste numérotée écran + élément +
   observé + attendu + périmètre, règle générale plutôt que cas. »

### `squash`

L'invocation vaut demande de réécrire l'historique et de le pousser.

1. `git fetch origin main`, noter le SHA local et le SHA distant (`git rev-parse origin/<headRefName>`) : retour par
   `git reset --hard <sha>`. Puis repartir de `origin/main` : `git reset --soft $(git merge-base HEAD origin/main)`,
   en rebasant d'abord sur `origin/main` si la branche est en retard. Messages dans la langue et au format de
   `CONTRIBUTING.md` (attribution du system-reminder).
   - **PR de taille normale** : un seul commit qui résume la feature.
   - **PR volumineuse** (plus de ~30-40 fichiers modifiés hors fichiers générés) : un commit par pan fonctionnel
     métier, chacun avec son code, ses tests et sa doc. Ordre de dépendance, pas de commit « correctifs de review ».
     Chaque commit doit compiler : compiler les intermédiaires (`git rebase --exec '<build>' origin/main`).
2. Arbre final identique à celui du SHA de départ (`git diff <sha>` vide), puis vérification du projet sur le dernier
   commit. Rouge → ne pas pousser, rapporter.
3. Approbations existantes (`approvals`) → prévenir qu'un push forcé peut les invalider, puis
   `git push --force-with-lease=<headRefName>:<SHA distant noté> origin <headRefName>`, jamais `--force` seul.
4. Rapport : découpage en commits (SHA et sujet), résultat de la vérification.

### `rebase`

L'invocation vaut demande de réécrire la branche et de la pousser.

1. Noter le SHA local et le SHA distant (`git rev-parse origin/<headRefName>`) : retour par `git reset --hard <sha>`.
2. `git fetch origin main`, puis `git rebase origin/main` dans l'arbre de la PR.
3. Conflits : lire les deux versions et garder l'intention de chacune, fichier par fichier ; jamais `--ours`/`--theirs`
   en bloc. Intention ambiguë → montrer le conflit et attendre la décision (rebase laissé en cours).
4. Vérification du projet dans l'arbre de la PR. Rouge → ne pas pousser, rapporter, laisser l'arbre en l'état.
5. Approbations existantes (`approvals`) → prévenir qu'un push forcé peut les invalider, puis pousser :
   `git push --force-with-lease=<headRefName>:<SHA distant noté> origin <headRefName>`, jamais `--force` seul.
6. Rapport : commits rejoués, fichiers en conflit et résolution choisie, résultat des tests, nouveau SHA.

### `recette`

Exécuter la recette sur l'environnement dédié de la PR ou, à défaut, sur l'application lancée depuis l'arbre de la PR,
puis corriger. Les retours de l'utilisateur viennent avec l'invocation ou dans le message qui suit (liste numérotée
écran + élément + observé + attendu + périmètre).

1. **Scénarios** — les retours de l'utilisateur, plus la recette prévue par la PR (description, plan commité sur la
   branche). Aucun des deux → déduire les scénarios de la description et du diff, les lister et attendre l'accord.
2. **Environnement** — la PR a un environnement dédié si son titre se termine par `[DEPLOY_PR][<env-id>]` (convention
   de renoshield) : son lien est dans la description, dans le bloc ajouté par le déploiement
   (`:heavy_check_mark: … http://…-<env-id>…`). Bloc présent et marqué réussi → recetter sur ce lien, sans lancement
   local. Sinon (pas de tag, bloc absent ou en échec, lien injoignable) → le dire et démarrer l'application dans
   l'arbre de la PR (commande du CLAUDE.md du projet, dépendances installées si le worktree est neuf), en arrière-plan.
   Port déjà pris ou service injoignable : le diagnostiquer, ne pas recetter une autre instance.
3. **Exécution** — chaque scénario étape par étape (Playwright pour une interface web), avec observé et attendu.
   Rapport : un tableau scénario → conforme / non conforme, capture d'écran à l'appui des écarts.
4. **Correctifs** — les retours de l'utilisateur valent demande de correction ; un écart trouvé par un scénario déduit
   se propose d'abord. Appliquer la règle générale plutôt que le cas, sur tout le périmètre indiqué. Intention ambiguë
   ou changement de comportement non prévu par la spec → demander. Puis vérification du projet et nouvelle exécution
   des scénarios touchés, en local : rouge → ne pas pousser, rapporter. Sur environnement dédié, les rejouer aussi
   après le push, une fois le build du nouveau SHA au vert (redéploiement).
5. **Push** — nouveaux commits au format de `CONTRIBUTING.md`, `push` simple, sans réécriture ni squash. PR de fork ou
   `state` ≠ `OPEN` → corriger dans l'arbre de la PR sans pousser, et le dire.
6. **Arrêt** — arrêter l'application lancée en local. Rapport : environnement recetté (lien ou local), scénarios et
   résultat, correctifs (SHA), ce qui reste.

### `merge`

L'invocation vaut demande de squasher et de merger : c'est le merge qui impose l'historique final.

1. **Squash** — étapes de `squash`, sauf si l'historique en est déjà le résultat (un commit, ou un par pan fonctionnel,
   sans commit de correctif depuis) et à jour avec `origin/main`.
2. **Merge** — CI de la PR au vert s'il y en a une (`gh pr checks --watch`), puis `gh pr merge --rebase`, jamais
   `--merge`. Dépôt avec un `Jenkinsfile` à la racine : le statut `continuous-integration/jenkins/pr-head` n'apparaît
   qu'une fois le build lancé, et rien côté GitHub n'empêche de merger sans lui. Ne merger que lorsqu'il est `SUCCESS`
   sur le SHA poussé (`gh pr view --json headRefOid,statusCheckRollup`). Absent ou `PENDING` : attendre et revérifier
   toutes les quelques minutes, sans timeout plus court que celui du `Jenkinsfile`. `FAILURE`/`ERROR`, ou toujours
   absent après ~15 min : ne pas merger, rapporter avec le lien Jenkins (`targetUrl`). Si un push sur main déploie :
   suivre le run (`gh run watch`) jusqu'au succès ou à l'échec, et le rapporter.
3. **Nettoyage** — branche extraite dans le dépôt principal : `git switch main && git pull --ff-only` ; sinon
   `git fetch origin main`. Worktree `pr-<n°>` : `git worktree remove <chemin>` après avoir vérifié qu'il est propre
   (session dedans : `ExitWorktree` avec `action: "keep"` d'abord). Supprimer la branche locale après avoir vérifié
   que main contient son contenu ; supprimer la branche distante si le dépôt ne le fait pas au merge.
4. **Mémoire** — mettre à jour la mémoire du projet : PR, SHA de merge, déploiement, ce qui reste à faire.
5. Rapport : une ligne par étape faite (SHA, lien de PR, état du déploiement) et ce qui n'a pas été fait, avec la
   raison.

## Nettoyage d'une PR fermée sans merge

`git worktree remove <chemin>` après avoir vérifié qu'il est propre.

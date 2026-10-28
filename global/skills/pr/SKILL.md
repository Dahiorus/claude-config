---
name: pr
description: Use when the user invokes /pr, or asks to list the pull requests of the current repo (« liste les PR ») or act on one — show it, count approvals, check it out, test it, push and open it, squash, rebase, run its recette, merge it, rewrite its description, review someone else's PR or address its review comments (« pousse et crée la PR », « squash et merge », « rebase la PR 42 », « fais la recette de la PR », « relis la PR 114 », « review la partie front », « traite les commentaires de alice », « la PR a-t-elle ses approbations », « mets à jour la description de la PR »).
argument-hint: "list | <n°|branche> [action…] [consigne]"
---

# PR

Sans `/pr`, l'action vient de la demande : `squash`, `rebase`, `merge` et `review` seulement si l'utilisateur les
nomme, jamais déduites.

`view` par défaut. Plusieurs actions à la suite (`/pr 81 squash update-desc`, `/pr push recette`) s'exécutent dans
l'ordre, arrêt au premier échec. Le texte libre qui suit les actions est une consigne pour elles (« en mode boîte
noire », « la partie front », « de amercadal »). La PR est cherchée dans le dépôt courant uniquement. Les commandes `gh`
et les `git push` passent par le compte indiqué par la mémoire du projet (jeton ponctuel
`GH_TOKEN=$(gh auth token -u <compte>)`, sans changer le compte actif). Seul `switch` change la branche de l'arbre
courant, et seulement s'il est propre : les autres actions travaillent dans l'arbre de la PR, le travail en cours n'est
pas touché. `push`, `squash` et `merge` reprennent les étapes 8 à 13 du skill `feature`, qui reste la
référence (règles, signaux d'alarme).

## Aide

`/pr` ou `/pr help` → afficher ce bloc tel quel, sans rien faire d'autre. Action inconnue proche d'une action connue
(`viw`, `sswitch`) → proposer celle-ci et attendre ; sinon la nommer et afficher ce bloc.

```text
/pr <n°|branche> [action…] [consigne]   PR du dépôt courant, « view » par défaut

  list          liste les PR du dépôt (sans n°) : open par défaut, closed
  view          affiche la PR
  approvals     compte les approbations (2 = prête pour la QA)
  switch        extrait la branche ici ; arbre pas propre → propose son worktree
  test          lance la vérification du projet dans l'arbre de la PR
  push          pousse les commits tels quels, crée la PR ou met à jour sa description
  squash        réécrit en un commit (un par pan fonctionnel si PR volumineuse), push forcé
  rebase        rebase sur origin/main, résout les conflits, push forcé
  recette       déroule la recette (env. de la PR, sinon local), corrige, pousse ; retours en
                liste numérotée écran + élément + observé + attendu + périmètre
  merge         reliquats faisables traités dans la PR, squash si besoin, merge en rebase, déploiement,
                nettoyage, mémoire
  update-desc   réécrit la description d'après la session et les commits
  review        relit la PR d'un autre, évalue sa criticité (relecture humaine requise ?),
                publie les commentaires (statut « commenté »)
  comments      traite les commentaires non résolus, corrige, pousse, répond aux fils
  help          cette aide

Exemples : /pr list · /pr list closed · /pr 42 · /pr 42 switch · /pr push recette · /pr 42 squash merge · /pr 42 review la partie front
           /pr 42 comments de alice · /pr main switch
```

## Résoudre la PR

`gh pr view <n°|branche> --json number,headRefName,isCrossRepository,state`. Introuvable → le dire et s'arrêter
(PR d'un autre dépôt : lancer `/pr` depuis ce projet). Ne visent pas de PR : `/pr list`, `/pr main switch`, et `push` sur une
branche qui n'a pas encore de PR (`/pr push` sans référence vise la branche courante, `main` comprise : voir `push`).

## Actions sans arbre

- **`list`** — tableau markdown, rendu tel quel dans la réponse (pas dans un bloc de code) ; la consigne se traduit en
  options `gh` (`open` ou « ouvertes » → défaut, `closed` ou « fermées » → `--state closed`, « toutes » → `--state all`, « de alice » → `--author alice`,
  « les miennes » → `--author @me`) :

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

### `push`

L'invocation vaut demande explicite de pousser et d'ouvrir la PR. Jamais de squash ni de réécriture : une PR peut
porter plusieurs commits ; un historique désordonné se signale au plus dans le rapport.

0. **Depuis `main`** — `git fetch origin main` ; ni modification en cours ni commit en avance sur `origin/main`
   (`git log origin/main..HEAD`) → rien à pousser, le dire et s'arrêter. Sinon `git switch -c <type>/<sujet>` depuis
   l'état courant (type d'après le contenu : `feat`, `fix`, `docs`, `chore` ; sujet court en kebab-case), qui emporte
   commits et modifications, puis `git branch -f main origin/main` pour remettre `main` au niveau du distant (ses
   commits vivent désormais sur la branche). Modifications en cours : les lister et demander avant de les commiter.
1. Vérification au vert dans cette session, sinon la lancer et lire la sortie. Rouge → on ne pousse pas.
2. **Reste à faire** — le projet en a un (skill `todo`) : y rayer les points que la PR règle et ajouter ses « hors
   périmètre » et reliquats (spec, plan, rapport de recette, points non retenus de `final-review.md`), puis le
   commiter avec la PR. Rien à changer → passer.
3. `git push` simple (`-u origin <branche>` la première fois).
4. Aucune PR ouverte pour la branche : `gh pr create` (titre = sujet du commit ou de la feature, description
   fonctionnelle en français). PR existante : mettre à jour la description si le périmètre a changé (`update-desc`).
5. Rapport : commit(s), lien de la PR, ce qui reste (recette, review). Terminer par ce rappel, mot pour mot :
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

Exécuter la recette sur l'environnement de recette indiqué dans la description de la PR ou, par défaut, en local sur
l'application lancée depuis l'arbre de la PR, puis corriger. Les retours de l'utilisateur viennent avec l'invocation
ou dans le message qui suit (liste numérotée écran + élément + observé + attendu + périmètre).

1. **Scénarios** — les retours de l'utilisateur, plus la recette prévue par la PR (description, plan commité sur la
   branche). Aucun des deux → déduire les scénarios de la description et du diff, les lister et attendre l'accord.
2. **Environnement** — chercher dans la description de la PR un environnement de recette : lien d'un environnement
   déployé pour la PR, par exemple le bloc ajouté par le déploiement d'une PR titrée `[DEPLOY_PR][<env-id>]`
   (convention de renoshield : `:heavy_check_mark: … http://…-<env-id>…`). Lien présent, déploiement réussi →
   recetter sur ce lien, sans lancement local. Aucun environnement dans la description → recette en local, par
   défaut, sans demander. Environnement indiqué mais en échec ou injoignable → le dire, puis recette en local. En
   local : démarrer l'application dans l'arbre de la PR (commande du CLAUDE.md du projet, dépendances installées si
   le worktree est neuf), en arrière-plan.
   Port déjà pris ou service injoignable : le diagnostiquer, ne pas recetter une autre instance.
3. **Exécution** — chaque scénario étape par étape, avec observé et attendu. Interface web : un scénario = un seul
   appel `browser_run_code_unsafe` de Playwright qui enchaîne ses étapes et renvoie l'observé de chacune ; snapshot
   et capture seulement sur un écart (chaque appel MCP relit tout le contexte).
   Rapport : un tableau scénario → conforme / non conforme, capture d'écran à l'appui des écarts.
4. **Correctifs** — les retours de l'utilisateur valent demande de correction ; les écarts trouvés par un scénario
   déduit se trient comme dans `feature` (« Tri des retours ») : « à corriger » corrigés d'office, « à trancher »
   rapportés. Appliquer la règle générale plutôt que le cas, sur tout le périmètre indiqué. Intention ambiguë ou
   changement de comportement non prévu par la spec → « à trancher ». Puis vérification du projet et nouvelle exécution
   des scénarios touchés, en local : rouge → ne pas pousser, rapporter. Sur environnement dédié, les rejouer aussi
   après le push, une fois le build du nouveau SHA au vert (redéploiement).
5. **Push** — nouveaux commits au format de `CONTRIBUTING.md`, `push` simple, sans réécriture ni squash. PR de fork ou
   `state` ≠ `OPEN` → corriger dans l'arbre de la PR sans pousser, et le dire.
6. **Arrêt** — arrêter l'application lancée en local. Rapport : environnement recetté (lien ou local), scénarios et
   résultat, correctifs (SHA), ce qui reste.

### `merge`

L'invocation vaut demande de squasher et de merger : c'est le merge qui impose l'historique final.

1. **Reliquats** — avant d'envoyer quoi que ce soit au reste à faire, passer en revue les points qu'il recevrait (ceux
   de l'étape 2 de `push`, plus ceux déjà ajoutés par cette PR) et ceux qu'il contient déjà sur le périmètre de la
   PR. Chacun se trie comme dans `feature` (« Tri des retours ») : faisable ici (petit, dans le périmètre, une seule
   façon raisonnable, sans effet sur la spec) → le faire dans la PR, un commit par point, vérification du projet au
   vert ; sinon → reste à faire, avec sa raison en une ligne. Rien de faisable → passer.
2. **Squash** — reste à faire à jour d'abord (étape 2 de `push`), puis étapes de `squash`, sauf si l'historique en
   est déjà le résultat (un commit, ou un par pan fonctionnel, sans commit de correctif depuis) et à jour avec
   `origin/main`.
3. **Merge** — CI de la PR au vert s'il y en a une (`gh pr checks --watch`), puis `gh pr merge --rebase`, jamais
   `--merge`. Dépôt avec un `Jenkinsfile` à la racine : le statut `continuous-integration/jenkins/pr-head` n'apparaît
   qu'une fois le build lancé, et rien côté GitHub n'empêche de merger sans lui. Ne merger que lorsqu'il est `SUCCESS`
   sur le SHA poussé (`gh pr view --json headRefOid,statusCheckRollup`). Absent ou `PENDING` : attendre et revérifier
   toutes les quelques minutes, sans timeout plus court que celui du `Jenkinsfile`. `FAILURE`/`ERROR`, ou toujours
   absent après ~15 min : ne pas merger, rapporter avec le lien Jenkins (`targetUrl`). Si un push sur main déploie :
   suivre le run (`gh run watch`) jusqu'au succès ou à l'échec, et le rapporter.
4. **Nettoyage** — branche extraite dans le dépôt principal : `git switch main && git pull --ff-only` ; sinon
   `git fetch origin main`. Worktree `pr-<n°>` : `git worktree remove <chemin>` après avoir vérifié qu'il est propre
   (session dedans : `ExitWorktree` avec `action: "keep"` d'abord). Supprimer la branche locale après avoir vérifié
   que main contient son contenu ; supprimer la branche distante si le dépôt ne le fait pas au merge.
5. **Mémoire** — mettre à jour la mémoire du projet : PR, SHA de merge, déploiement, ce qui reste à faire.
6. Rapport : une ligne par étape faite (SHA, lien de PR, état du déploiement) et ce qui n'a pas été fait, avec la
   raison.

### `review`

L'invocation vaut demande de relire et de publier. PR dont on est l'auteur → refuser (`push`, `recette`).

1. Diff de la PR contre sa base (`git diff origin/<baseRefName>...HEAD` dans l'arbre de la PR), restreint au
   périmètre de la consigne s'il y en a un, et les fichiers qu'il touche. Contexte : description, spec ou issue liée.
2. Grille : celle du projet (WORKFLOW.md, AGENTS.md, CONTRIBUTING.md), sinon la grille qualité du skill `feature`.
   Diff qui touche une API Angular → skill `angular-developer` aussi, comme dans `feature`. Bugs et sécurité
   d'abord, puis lisibilité ; chaque remarque est vérifiée dans le code, pas supposée. Pas de
   remarque de goût sans règle du projet derrière.
3. Criticité : skill `pr-risk` sur la PR, qui publie (ou met à jour) son commentaire de risque : niveau, nombre de
   relectures humaines, dangers à vérifier.
4. Publier une seule review `COMMENT`, jamais `APPROVE` ni `REQUEST_CHANGES` :
   `gh api repos/<owner/repo>/pulls/<n°>/reviews --input <fichier>` avec `event: "COMMENT"`, un `body` qui ouvre
   sur la criticité (`Criticité : <niveau> — <0|1|2> relecture(s) humaine(s), détail dans le commentaire de risque`)
   avant la synthèse, et un `comments` par remarque (`path`, `line` du nouveau fichier, `side: "RIGHT"`), en
   français, problème + suggestion. Ligne hors du diff → dans le `body`, avec `fichier:ligne`.
5. Rapport : verdict de `pr-risk` (niveau, relectures, dangers), lien de la review, remarques par gravité.

### `comments`

L'invocation vaut demande de corriger, pousser et répondre.

1. Fils non résolus (`gh api graphql`, `reviewThreads` avec `isResolved`, `comments { databaseId path line body
   author { login } }`), filtrés par auteur si la consigne le dit (« de alice »). Aucun → le dire et s'arrêter.
2. Pour chaque fil : vérifier le commentaire dans le code, puis le trier comme dans `feature` (« Tri des retours ») :
   « à corriger » → corrigé (règle générale plutôt que cas, comme pour `recette`) ; « écarté » (faux ou hors règle
   du projet) → raison ; « à trancher » (ambigu, changement de comportement non prévu par la spec) → options et
   recommandation, rien n'est corrigé avant l'accord.
3. Vérification du projet ; rouge → ne pas pousser. Commits au format de `CONTRIBUTING.md`, `push` simple.
4. Répondre à chaque fil corrigé (`gh api repos/<owner/repo>/pulls/<n°>/comments/<databaseId>/replies -f body=…`) :
   ce qui a changé et le SHA. Ne pas résoudre les fils : c'est au relecteur. Fils non corrigés : réponse proposée
   dans le rapport, publiée après accord.
5. Rapport : décompte corrigés (SHA) / écartés, puis seuls les « à trancher » détaillés, lien de la PR.

## Nettoyage d'une PR fermée sans merge

`git worktree remove <chemin>` après avoir vérifié qu'il est propre.

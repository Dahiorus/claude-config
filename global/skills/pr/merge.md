# `merge`

L'invocation vaut demande de squasher et de merger : c'est le merge qui impose l'historique final.
PR en draft (`gh pr view <n°> --json isDraft,body`) → ne rien faire : le dire, avec les tâches restantes de
sa section « État » s'il y en a, et proposer `/pr push` (qui la sort du draft, `push.md`), puis `merge`.

1. **Reliquats** — avant d'envoyer quoi que ce soit au reste à faire, passer en revue les points qu'il recevrait (ceux
   de l'étape 2 de `push.md`, plus ceux déjà ajoutés par cette PR) et ceux qu'il contient déjà sur le périmètre de la
   PR. L'agent `feedback-triager` (mode `reliquats`, modèle `sonnet` passé explicitement) les trie comme dans `feature` (« Tri des retours ») : faisable ici (petit, dans le périmètre, une seule
   façon raisonnable, sans effet sur la spec) → le faire dans la PR, un commit par point, vérification du projet au
   vert ; sinon → reste à faire, avec sa raison en une ligne. Rien de faisable → passer.
2. **Leçons** — avant le squash, pour qu'elles partent dans la PR et pas dans une PR à part. Sans attendre de demande, l'agent `lessons-extractor` (modèle `sonnet` passé explicitement ; brief :
   dossier de suivi, racine, arbre de la PR, description de la PR, projet `claude-config` ou non) lit le `lecons.md` et le
   `final-review.md` du dossier de suivi, puis ceux des PR précédentes (`<racine>/.superpowers/sdd/*/`) et, pour une
   règle globale, les `lecons.md` des autres projets, et trie les
   leçons par étiquette (agent `lessons-extractor`, « Trier » et « Récidive ») : il propose une garde mécanique, une
   règle, ou le déplacement ou le retrait d'une règle qui a récidivé ; un hook ou un script trop gros pour la PR
   devient une issue ou un point du reste à faire, créé par la session après accord comme à l'étape **Issues** de
   `push.md`. Cibles : l'`AGENTS.md`, le `CLAUDE.md` ou les tests du projet, la grille qualité
   (`~/.claude/grille-qualite.md`) pour une règle de tous les projets, ou les fichiers globaux quand la règle est
   pour le skill ou l'agent global en cause. Ses propositions arrivent ensemble, en diff, et ne s'appliquent qu'après
   accord, en un commit de la PR. Une règle
   globale (grille qualité, skills `pr`…) hors du projet `claude-config` ne s'écrit pas dans ses fichiers depuis
   cette session : après accord, `/notify claude-config` avec le diff proposé (skill `notify`), et la session
   `claude-config` l'applique dans sa propre PR. Si elle a quand même été écrite directement dans ses fichiers,
   `/notify claude-config` au minimum : fichiers modifiés et diff, pour qu'elle passe dans une PR. Une proposition qui
   s'appuie sur un autre projet le dit : ni le nom de ce projet, ni le texte de ses leçons, ni les chemins de la
   colonne « Source » ne vont dans le commit, la description ou une issue ; le message `notify` peut les citer, en
   rappelant qu'ils restent hors de la PR. Les leçons des étapes
   suivantes (squash, merge, nettoyage) vont dans `lecons.md` à la fin : la PR suivante les lira.
3. **Squash** — reste à faire à jour d'abord (étape 2 de `push.md`), puis étapes de `squash.md`, sauf si l'historique en
   est déjà le résultat (un commit, ou un par pan fonctionnel, sans commit de correctif depuis) et à jour avec
   `origin/<base>` (`baseRefName` de la PR). Squash sauté : marque « livrée » en PR multiples (étape 1 de
   `squash.md`) et message du commit passé par `humanizer:humanizer` quand même, push forcé avec bail comme dans
   `squash.md` si le message change.
4. **Merge** — fichier de `src/` supprimé ou déplacé alors que le déploiement ne supprime pas (rsync sans
   `--delete`) → le signaler avant de merger. Issues réglées entièrement par la PR (spec, commits, branche) absentes de
   `gh pr view --json closingIssuesReferences` → ajouter leur `Closes #n` à la description avant de merger, relue contre le diff comme à l'étape 4 de `push.md` ; après le merge,
   vérifier que chacune est `CLOSED` (`gh issue view <n> --json state`), sinon la fermer avec un commentaire qui cite la
   PR et le SHA de merge, passé par `humanizer:humanizer`.
   PR empilée (base ≠ main, ou visée par une PR ouverte : `gh pr list --base <headRefName> --state open` non vide) :
   merger de bas en haut. `gh pr merge` et l'API synchrone refusent une PR de pile (« part of a stack ») :
   `gh api -X PUT repos/<owner/repo>/pulls/<n°>/merge-async -f merge_method=rebase -f merge_action=direct_merge
   -f sha=<headRefOid complet>`, sur la PR du bas seulement, à la place de `gh pr merge --rebase` ci-dessous.
   Toujours « enqueued » après quelques minutes : renvoyer la même requête. Merge fini quand
   `gh pr view <n°> --json state,mergeCommit` donne `MERGED` (revérifier toutes les 10 s) : le SHA de merge est
   `mergeCommit.oid`. Issues, déploiement et nettoyage (étape 5) ne partent qu'ensuite, le nettoyage une fois la
   suivante repointée sur main (`gh pr view <suivante> --json baseRefName`). GitHub rebase et repointe lui-même la
   suivante, sans `gh pr edit --base` ni rebase local (le push forcé échouerait en « stale info ») : dans son arbre,
   `git fetch` puis `git reset --hard origin/<branche>`, attendre sa CI sur le nouveau SHA, puis la merger de même
   (merge-async tant qu'une PR ouverte la vise, sinon `gh pr merge --rebase`).
   CI de la PR au vert si le dépôt en a une (`.github/workflows/` non vide) : revérifier toutes
   les 10 s `gh pr view --json headRefOid,statusCheckRollup` jusqu'à ce que `headRefOid` soit égal à `git rev-parse HEAD`
   et qu'au moins un check apparaisse, puis lancer `gh pr checks --watch`. Lancé juste après un push, `gh pr checks
   --watch` répond « no checks reported » ou suit le run annulé de l'ancien SHA. Toujours aucun check après ~2 min (filtre
   `on:` du workflow ?) : ne pas merger, rapporter. Puis `gh pr merge --rebase`, jamais `--merge`. Refus « not mergeable », « Head branch is out of date » juste après un push forcé, ou erreur 5xx : la
   mergeabilité est encore `UNKNOWN`, relancer seul jusqu'à 3 fois à 10 s d'écart avant de rapporter l'échec. Refus
   « Base branch was modified » (main a bougé pendant le merge) : même relance. Dépôt avec un `Jenkinsfile` à la racine : le statut `continuous-integration/jenkins/pr-head` n'apparaît
   qu'une fois le build lancé, et rien côté GitHub n'empêche de merger sans lui. Ne merger que lorsqu'il est `SUCCESS`
   sur le SHA poussé (`gh pr view --json headRefOid,statusCheckRollup`). Absent ou `PENDING` : attendre et revérifier
   toutes les quelques minutes, sans timeout plus court que celui du `Jenkinsfile`. `FAILURE`/`ERROR`, ou toujours
   absent après ~15 min : ne pas merger, rapporter avec le lien Jenkins (`targetUrl`). Si un push sur main déploie :
   suivre le run (`gh run watch`, run trouvé par `gh run list --branch main --commit <sha>`, jamais filtré sur un nom
   de workflow accentué) jusqu'au succès ou à l'échec, et le rapporter ; succès → rejouer un ou deux
   scénarios de recette sur l'environnement déployé (agent `recette-runner`, modèle `sonnet` passé explicitement, comme l'action `recette` (`recette.md` du skill `pr`)). Écart → le rapporter, sans
   revenir en arrière seul.
5. **Nettoyage** — de la branche de la PR et de celles des PR qu'elle a intégrées puis fermées (citées dans la
   description ou les commits) : section « Nettoyage des branches » ci-dessous, sans redemander, main contenant leur
   contenu.
6. **Mémoire** — n'y écrire qu'un piège (comportement inattendu et son contournement) ou une décision de
   l'utilisateur (choix à ne pas reproposer, avec sa raison) apparus dans la PR ; jamais n° de PR, SHA, date ou état
   du déploiement, que git et GitHub gardent. Rien de nouveau → rien. Ce qui reste à faire va dans le reste à faire
   versionné s'il existe ; sinon un bug ou un point hors périmètre devient une issue, proposée puis créée après accord
   comme à l'étape **Issues** de `push.md` (label `hors-perimetre`, ou `bug` pour un bug). Jamais dans la mémoire.
7. Leçons du squash, du merge et du nettoyage dans `lecons.md` : la PR suivante les lira. Rapport : une
   ligne par étape faite (SHA, lien de PR, état du déploiement) et ce qui n'a pas été fait, avec la raison.

## Nettoyage des branches

Après un merge, ou une PR fermée sans merge. Branche d'une PR fermée sans merge dont le contenu n'est pas dans main
(ni intégré dans une autre PR) : demander avant de la supprimer, ses commits seraient perdus. Branche gardée pour
une nouvelle PR : retirer la marque « livrée » de la story dans son plan.

1. **Worktrees** — chaque worktree où la branche est extraite (`git worktree list --porcelain`), `pr-<n°>` compris.
   Dépôt principal : `git switch main && git pull --ff-only`. Autre worktree propre : `git worktree remove <chemin>`
   (session dedans : `ExitWorktree` avec `action: "keep"` d'abord). Pas propre → le laisser et le dire. Puis
   `git worktree prune`.
2. **Branche locale** — `git branch -D` une fois vérifié que main contient son contenu (`git diff --quiet origin/main
   <branche> -- $(git diff --name-only origin/main...<branche>)`) : un merge en rebase change les SHA, `-d` refuse.
   Écart → le montrer et demander.
3. **Branche distante** — sauf si le dépôt la supprime au merge (`gh api repos/<owner/repo> --jq
   .delete_branch_on_merge`) : `git push origin --delete <branche>…`, toutes les branches en un appel, dans un appel
   seul (ni squash, ni autre push, ni switch). Refusé (permissions ou hook) → donner la commande prête à lancer
   avec `!`.

# `merge`

L'invocation vaut demande de squasher et de merger : c'est le merge qui impose l'historique final.

1. **Reliquats** — avant d'envoyer quoi que ce soit au reste à faire, passer en revue les points qu'il recevrait (ceux
   de l'étape 2 de `push.md`, plus ceux déjà ajoutés par cette PR) et ceux qu'il contient déjà sur le périmètre de la
   PR. L'agent Opus les trie comme dans `feature` (« Tri des retours ») : faisable ici (petit, dans le périmètre, une seule
   façon raisonnable, sans effet sur la spec) → le faire dans la PR, un commit par point, vérification du projet au
   vert ; sinon → reste à faire, avec sa raison en une ligne. Rien de faisable → passer.
2. **Leçons** — avant le squash, pour qu'elles partent dans la PR et pas dans une PR à part. Sans attendre de demande, l'agent Opus lit le `lecons.md` et le `final-review.md` du dossier de
   suivi, puis ceux des PR précédentes (`<racine>/.superpowers/sdd/*/`) : une friction qu'une règle écrite aurait
   évitée, ou un même type de point vu deux fois, devient une règle proposée pour l'`AGENTS.md` ou le
   `CLAUDE.md` du projet, ou pour la grille qualité de `feature` s'il vaut pour tous les projets. Les propositions
   arrivent ensemble, en diff, et ne s'appliquent qu'après accord, en un commit de la PR. Les frictions des étapes
   suivantes (squash, merge, nettoyage) vont dans `lecons.md` à la fin : la PR suivante les lira.
3. **Squash** — reste à faire à jour d'abord (étape 2 de `push.md`), puis étapes de `squash.md`, sauf si l'historique en
   est déjà le résultat (un commit, ou un par pan fonctionnel, sans commit de correctif depuis) et à jour avec
   `origin/main`. Squash sauté : marque « livrée » en PR multiples (étape 1 de `squash.md`) et message du commit passé
   par `humanizer:humanizer` quand même, push forcé avec bail comme dans `squash.md` si le message change.
4. **Merge** — fichier de `src/` supprimé ou déplacé alors que le déploiement ne supprime pas (rsync sans
   `--delete`) → le signaler avant de merger. Issues réglées entièrement par la PR (spec, commits, branche) absentes de
   `gh pr view --json closingIssuesReferences` → ajouter leur `Closes #n` à la description avant de merger ; après le merge,
   vérifier que chacune est `CLOSED` (`gh issue view <n> --json state`), sinon la fermer avec un commentaire qui cite la
   PR et le SHA de merge. CI de la PR au vert s'il y en a une (`gh pr checks --watch`), puis `gh pr merge --rebase`, jamais
   `--merge`. Refus « not mergeable », « Head branch is out of date » juste après un push forcé, ou erreur 5xx : la
   mergeabilité est encore `UNKNOWN`, relancer seul jusqu'à 3 fois à 10 s d'écart avant de rapporter l'échec. Dépôt avec un `Jenkinsfile` à la racine : le statut `continuous-integration/jenkins/pr-head` n'apparaît
   qu'une fois le build lancé, et rien côté GitHub n'empêche de merger sans lui. Ne merger que lorsqu'il est `SUCCESS`
   sur le SHA poussé (`gh pr view --json headRefOid,statusCheckRollup`). Absent ou `PENDING` : attendre et revérifier
   toutes les quelques minutes, sans timeout plus court que celui du `Jenkinsfile`. `FAILURE`/`ERROR`, ou toujours
   absent après ~15 min : ne pas merger, rapporter avec le lien Jenkins (`targetUrl`). Si un push sur main déploie :
   suivre le run (`gh run watch`) jusqu'au succès ou à l'échec, et le rapporter ; succès → rejouer un ou deux
   scénarios de recette sur l'environnement déployé (agent Sonnet, comme l'action `recette` (`recette.md` du skill `pr`)). Écart → le rapporter, sans
   revenir en arrière seul.
5. **Nettoyage** — de la branche de la PR et de celles des PR qu'elle a intégrées puis fermées (citées dans la
   description ou les commits) : section « Nettoyage des branches » de `SKILL.md`, sans redemander, main contenant leur contenu.
6. **Mémoire** — n'y écrire qu'un piège (comportement inattendu et son contournement) ou une décision de
   l'utilisateur (choix à ne pas reproposer, avec sa raison) apparus dans la PR ; jamais n° de PR, SHA, date ou état
   du déploiement, que git et GitHub gardent. Rien de nouveau → rien. Ce qui reste à faire va dans le reste à faire
   versionné s'il existe ; sinon un bug ou un point hors périmètre devient une issue, proposée puis créée après accord
   comme à l'étape **Issues** de `push.md` (label `hors-perimetre`, ou `bug` pour un bug). Jamais dans la mémoire.
7. Frictions du squash, du merge et du nettoyage dans `lecons.md`, pour les leçons de la PR suivante. Rapport : une
   ligne par étape faite (SHA, lien de PR, état du déploiement) et ce qui n'a pas été fait, avec la raison.

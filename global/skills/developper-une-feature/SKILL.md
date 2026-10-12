---
name: developper-une-feature
description: Use when the user asks to build, implement or ship a feature end to end (spec, plan, implementation, review, PR, merge), or says « implémente le plan », « fais une review », « squash », « pousse la PR », « merge » on feature work.
---

# Développer une feature

## Principe

Une feature suit toujours le même cycle, dans cet ordre. Chaque étape a son outil et son modèle. La pression
(« démo dans une heure ») ne raccourcit aucune étape : elle se signale à l'utilisateur, qui décide.

**Respecter la lettre du cycle, c'est en respecter l'esprit.**

## Le cycle

| # | Étape | Comment |
|---|---|---|
| 1 | Conception | `superpowers:brainstorming` → spec dans `docs/superpowers/specs/`, **toujours** ouverte dans Plannotator (`plannotator-annotate` sur le fichier de la spec) : appliquer chaque annotation, rouvrir jusqu'à l'approbation |
| 2 | Plan | `superpowers:writing-plans`, **fidèle à la spec** : aucun écart de signature, de champ d'API ni de code d'erreur. Si la spec tient mal face au code, proposer d'amender la spec. Plan commité **sur la branche `feat/…`** (il fait partie de la PR). Puis relecture du plan dans Plannotator (`plannotator-annotate` sur le fichier du plan) : appliquer chaque annotation, commiter, rouvrir jusqu'à l'approbation |
| 3 | `/clear` | Plan approuvé dans Plannotator, écrit dans cette session (ou session déjà utilisée) → **s'arrêter** et demander `/clear` puis la relance de l'exécution. Ne jamais enchaîner |
| 4 | Exécution | `superpowers:subagent-driven-development`. Implémenteur **Sonnet**. Contrôle par tâche **Haiku, effort low** : compilation + tests de la tâche, rien d'autre. Agents `sdd-implementer` / `sdd-task-reviewer` / `sdd-final-reviewer` du projet s'ils existent. Toujours passer le modèle explicitement |
| 5 | Vérification | Suite complète de tests + analyse statique, sortie lue. Une erreur d'environnement (base injoignable, port) se diagnostique, elle ne s'ignore pas |
| 6 | Recette | Si le plan en prévoit une : la faire soi-même dans le navigateur (Playwright), étape par étape |
| 7 | Reviews | **Automatiques**, sans attendre de demande, dès la vérification (et la recette) au vert : `ponytail:ponytail-review` et review complète par **Opus** (`sdd-final-reviewer`, modèle passé explicitement) sur toute la branche, en parallèle. Rapporter les deux, puis corriger ce que l'utilisateur retient ; un correctif qui change le comportement amende la spec d'abord |
| 8 | Squash | Un seul commit par feature (spec + plan + code), message qui résume la feature, `git reset --soft <merge-base>` |
| 9 | PR | Pousser la branche et ouvrir la PR avec le compte gh indiqué par la mémoire du projet (jeton ponctuel, sans changer le compte actif) |
| 10 | Re-squash | Si des correctifs arrivent après la PR : refusionner en un commit, `push --force-with-lease=<branche>:<sha attendu>` |
| 11 | Merge | `gh pr merge --rebase` (ou `--squash`), **jamais** `--merge`. Si un push sur main déploie : suivre le run jusqu'au succès |
| 12 | Nettoyage | Supprimer la branche distante, les branches locales de la feature (`feat/…`, `docs/…`) après avoir vérifié que main contient leur contenu ; repasser sur main à jour |
| 13 | Mémoire | Mettre à jour la mémoire du projet : PR, SHA de merge, déploiement, ce qui reste à faire |

Une demande peut couvrir plusieurs étapes (« implémente, squash »). L'exécution enchaîne d'elle-même vérification,
recette et reviews (étapes 5 à 7) : ne jamais demander s'il faut lancer les reviews. Pousser, ouvrir la PR et
merger attendent toujours une demande explicite de l'utilisateur.

## Excuses et réalité

| Excuse | Réalité |
|---|---|
| « Le contexte est frais, pas besoin de /clear » | Le `/clear` est exigé. On s'arrête et on le demande. |
| « Les commits sont propres, je les garde » | Une feature = un commit. On squash. |
| « Pas le temps, je fais une review courte » | Review complète, ou on dit que ce n'est pas prêt. |
| « Les tests DB échouent, c'est l'environnement » | Diagnostiquer (port, conteneur) et relancer jusqu'au vert. |
| « Haiku peut aussi juger la qualité » | Non : compilation et tests seulement. La qualité, c'est Opus à la fin. |
| « Petit écart pratique au plan, je le signale » | Pas d'écart. On amende la spec. |
| « Le plan est clair, je le résume dans le chat » | Le plan passe par Plannotator, approuvé avant le `/clear`. |
| « La spec est courte, l'utilisateur la lira dans le chat » | La spec s'ouvre toujours dans Plannotator. |
| « Je demande si l'utilisateur veut une review » | Non : ponytail-review et Opus se lancent seuls à la fin du développement. |

## Signaux d'alarme

- Implémenter dans la session qui a écrit le plan.
- Ouvrir une PR à plusieurs commits.
- `gh pr merge --merge`, ou un `push --force` sans `--force-with-lease`.
- Supprimer ou déplacer un fichier de `src/` quand le déploiement ne supprime pas (rsync sans `--delete`) : le signaler avant le merge.
- Terminer sans mettre à jour la mémoire.

---
name: feature
description: Use when the user invokes /feature, asks to build, implement or ship a feature end to end (spec, plan, implementation, review, PR, merge), starts designing one (« on attaque… », « commence la spec », « rédige la spec », « écris le plan », « nouvelle feature »), or says « implémente le plan », « fais une review », « corrige 1 et M3 », « squash », « pousse la PR », « merge » on feature work. Not for fixing a bug or a regression (use bugfix).
---

# Feature

## Principe

Une feature suit toujours le même cycle, dans cet ordre. Chaque étape a son outil et son modèle. La pression
(« démo dans une heure ») ne raccourcit aucune étape : elle se signale à l'utilisateur, qui décide.

**Respecter la lettre du cycle, c'est en respecter l'esprit.**

## Le cycle

| # | Étape | Comment |
|---|---|---|
| 1 | Conception | Feature multi-couches : avant les questions, 2-3 agents `Explore` en parallèle (angles distincts : features voisines, flux de données entre couches, tests existants), chacun rend 5-10 fichiers clés à lire. Puis `superpowers:brainstorming` → spec dans `docs/superpowers/specs/`, avec les sections de fidélité (ci-dessous), **toujours** ouverte dans Plannotator (`plannotator-annotate` avec les arguments `<fichier de la spec> --gate --json`, mode approbation) : appliquer chaque annotation, rouvrir jusqu'à l'approbation |
| 1b | Passage au plan | Dès `"decision": "approved"`, **sans demander** : (a) relire les annotations jointes à l'approbation, appliquer chacune à la spec et commiter ; une annotation qui change le comportement ou la portée → rouvrir Plannotator (`--gate`) ; (b) vérifier chaque fichier de la section « Portée » : il existe, la signature ou le champ cité correspond au code actuel ; (c) chercher dans tout le dépôt (grep, LSP) les usages de chaque symbole, route, champ ou concept modifié : un usage absent de « Portée » → amender la spec et rouvrir Plannotator, sinon le noter pour le plan. Tout est cohérent → étape 2 dans la foulée. La spec change un contrat partagé avec un autre dépôt (API, format d'échange ; dépôt lié cité par AGENTS.md, CLAUDE.md ou la mémoire) → prévenir sa session avec le skill `notify` : ce qui change et le chemin absolu de la spec |
| 2 | Plan | `superpowers:writing-plans`, **fidèle à la spec** : aucun écart de signature, de champ d'API ni de code d'erreur. Table de traçabilité obligatoire (ci-dessous), avec les usages vérifiés à l'étape 1b ; chaque tâche cite les § de spec qu'elle implémente. Le code du plan respecte la grille qualité (ci-dessous). Si la spec tient mal face au code, proposer d'amender la spec. Plan commité **sur la branche `feat/…`** (il fait partie de la PR). Puis relecture du plan dans Plannotator (`plannotator-annotate` avec les arguments `<fichier du plan> --gate --json`, mode approbation) : appliquer chaque annotation, commiter, rouvrir jusqu'à l'approbation |
| 3 | `/clear` | Plan approuvé dans Plannotator, écrit dans cette session (ou session déjà utilisée) → **s'arrêter** et demander `/clear`, en donnant la commande de relance prête à copier : `/feature implémente @<chemin du plan>`. Ne jamais enchaîner |
| 4 | Exécution | `superpowers:subagent-driven-development`. Implémenteur **Sonnet**, dont le brief rappelle la grille qualité (ci-dessous). Contrôle par tâche **Haiku, effort low** : compilation + **tests du contexte borné entier** (`tests/<Contexte>`, pas seulement ceux de la tâche) + présence de chaque test nommé dans le brief et de la preuve du rouge dans le rapport, rien d'autre. Un écart de l'implémenteur au brief, même « pratique », revient au contrôleur, qui amende la spec ou fait corriger : jamais accepté en silence. Agents `sdd-implementer` / `sdd-task-reviewer` / `sdd-final-reviewer` du projet s'ils existent. Toujours passer le modèle explicitement |
| 5 | Vérification | Suite complète de tests + analyse statique, sortie lue. Une erreur d'environnement (base injoignable, port) se diagnostique, elle ne s'ignore pas |
| 6 | Recette | Si le plan en prévoit une : la faire soi-même dans le navigateur (Playwright), étape par étape |
| 7 | Reviews | **Automatiques**, sans attendre de demande, dès la vérification (et la recette) au vert : `ponytail:ponytail-review` et review complète par **Opus** (`sdd-final-reviewer`, modèle passé explicitement) sur toute la branche, en parallèle. La review Opus vérifie d'abord la fidélité (demande initiale → spec → plan → code, ci-dessous) puis applique la grille qualité. Écrire les deux dans `.superpowers/sdd/<feature>/final-review.md`, numérotées une fois pour toutes (`P1…` pour ponytail, `C1…`, `I1…`, `M1…` par gravité pour Opus), rapporter, puis corriger ce que l'utilisateur retient (« corrige 1 et M3 », y compris après un `/clear` : relire ce fichier) ; chaque point corrigé y reçoit son SHA. Un correctif qui change le comportement amende la spec d'abord |
| 8 | PR | Pousser la branche et ouvrir la PR avec le compte gh indiqué par la mémoire du projet (jeton ponctuel, sans changer le compte actif). La PR peut porter plusieurs commits, poussés tels quels. Le projet a un reste à faire (skill `todo`) → avant de pousser, y rayer ce que la feature règle et ajouter les « hors périmètre » de la spec et les points de review non retenus, commité dans la PR |
| 9 | Correctifs | Correctifs après la PR (review, recette) : nouveaux commits, `push` simple, sans réécriture |
| 10 | Squash | Avant le merge seulement, reste à faire à jour (étape 8) : un seul commit par feature (spec + plan + code), message qui résume la feature, `git reset --soft <merge-base>`. PR de plus de ~30-40 fichiers modifiés : un commit par pan fonctionnel métier. Puis `push --force-with-lease=<branche>:<sha attendu>` |
| 11 | Merge | `gh pr merge --rebase` (ou `--squash`), **jamais** `--merge`. Si un push sur main déploie : suivre le run jusqu'au succès |
| 12 | Nettoyage | Supprimer la branche distante, les branches locales de la feature (`feat/…`, `docs/…`) après avoir vérifié que main contient leur contenu ; repasser sur main à jour |
| 13 | Mémoire | Mettre à jour la mémoire du projet : PR, SHA de merge, déploiement. Ce qui reste à faire va dans le reste à faire versionné s'il existe, pas dans la mémoire |

Une demande peut couvrir plusieurs étapes (« implémente, squash »). L'exécution enchaîne d'elle-même vérification,
recette et reviews (étapes 5 à 7) : ne jamais demander s'il faut lancer les reviews. Pousser, ouvrir la PR et
merger attendent toujours une demande explicite de l'utilisateur.

## Fidélité à la demande

La demande de l'utilisateur est la référence ; la spec la précise, le plan l'argumente, le code l'exécute. Rien ne
s'ajoute ni ne se perd en route.

**Spec** — six sections obligatoires, relues dans Plannotator :
1. **Demande initiale** : les mots de l'utilisateur, cités tels quels (et la recette ou le ticket d'origine s'il y en
   a). Toute exigence de la spec s'y rattache ; ce qui ne s'y rattache pas est retiré ou validé par l'utilisateur.
2. **Portée de chaque règle** : pour chaque règle nouvelle ou modifiée, la liste de tous les endroits qu'elle touche
   (écrans, boutons, champs, routes d'API, commandes, exports), établie en cherchant dans le code les usages de la
   donnée ou du concept, pas de mémoire. Chaque endroit dit ce qu'il devient, y compris « inchangé, parce que… ».
   Pour chaque donnée, colonne ou signature ajoutée ou modifiée : **tous ses lecteurs et écrivains**, dans le code
   serveur, l'interface, les gabarits et les exports, et dans les autres contextes ou modules qui la consomment
   (requêtes qui doivent la sélectionner, présentateurs, feuilles, imports). Un champ ajouté qu'un lecteur ne
   sélectionne pas, ou qu'un autre module ignore, est un oubli classique.
3. **Données existantes** : pour chaque validation ou contrainte ajoutée, ce que deviennent les enregistrements déjà
   en base qui ne la respectent pas (bloqués à l'enregistrement, corrigés par migration, tolérés).
4. **Critères d'acceptation** : cas nominaux, refus, et **cas combinés** (deux champs en erreur ensemble, deux règles
   qui se croisent, statut × état des données).
5. **Filet sur l'existant** : pour chaque fichier modifié dont le comportement actuel n'est couvert par aucun test,
   les tests de caractérisation à écrire **avant** de le modifier (comportement actuel figé, vert sur `main`), pour
   qu'une régression sur ce qui ne devait pas changer se voie. Le plan en fait sa première tâche.
6. **Origine** : chaque point traité (repris du reste à faire, d'une recette, d'une review) et chaque point laissé
   « hors périmètre » porte son origine : *régression* introduite par une PR (la citer), *défaut ancien* découvert,
   ou *hors périmètre* d'une spec (la citer). Le reste à faire reprend cette origine.

**Plan** — une table de traçabilité en tête : chaque exigence de la spec (§) → tâche → test qui la prouve ; pour
chaque fichier touché, les usages trouvés à l'étape 1b et ce qu'ils deviennent. Une
exigence sans test, ou une tâche sans exigence, est un défaut du plan. Les tests du plan couvrent les cas combinés
des critères d'acceptation. Un test existant que le plan rend faux est nommé dans la tâche qui le casse.

**Exécution** — l'implémenteur prouve le rouge (sortie du test qui échoue, dans son rapport) avant d'écrire le code,
et lance les tests du contexte borné entier avant de commiter. Ce que le brief ne dit pas ne s'invente pas :
NEEDS_CONTEXT. Un test existant modifié est signalé avec sa raison.

**Review finale** — avant la grille qualité, Opus vérifie la chaîne : chaque phrase de la demande initiale est
couverte par la spec, chaque exigence de la spec par du code et un test, et le diff ne contient rien que la spec ne
demande. Un écart (ajout, omission, règle appliquée à une partie seulement de sa portée) est au moins Important.

## Grille qualité (plan, implémentation, review Opus)

But : du code qu'un humain relit sans effort. Entrée de la review : `git diff main...HEAD` et les fichiers qu'il
touche. Grille du projet (WORKFLOW.md, AGENTS.md) si elle existe, sinon celle-ci, adaptée au langage :

- **SOLID, KISS, DRY**, en particulier : branchement exhaustif sur un type fermé plutôt qu'une chaîne de tests de
  type ; une règle métier remontée dans le module partagé plutôt que copiée entre features, mais deux lignes
  semblables par hasard ne sont pas un doublon.
- **Object calisthenics** :
  1. un niveau d'indentation par fonction, deux au plus ;
  2. pas de `else` après un `return` : retour anticipé ou branchement exhaustif ;
  3. une primitive qui porte une règle métier devient un type ;
  4. une collection qui porte une règle devient un type à elle ;
  5. un seul point par ligne pour traverser des objets (`a.b.c.d`) ; chaînes de transformations permises, une étape
     par ligne ;
  6. pas d'abréviation dans les noms (`qty`, `cfg`, `mgr`) hors vocabulaire du domaine ;
  7. fonction ≤ 20 lignes (composant d'interface ≤ 40), fichier ≤ 200 lignes ;
  8. ≤ 4 dépendances par constructeur ;
  9. pas d'état mutable exposé : objets immuables, flux en lecture seule, *Tell, don't ask*.

Ne pas signaler : code généré, tests (longueur libre), écart imposé par le framework ou une API externe, dépassement
d'une ou deux lignes des seuils du point 7. Sortie : écarts classés par gravité, avec `fichier:ligne`, principe
enfreint et correctif attendu ; ou « conforme ».

## Excuses et réalité

| Excuse | Réalité |
|---|---|
| « Le contexte est frais, pas besoin de /clear » | Le `/clear` est exigé. On s'arrête et on le demande. |
| « Les commits sont propres, je les merge tels quels » | Au merge, une feature = un commit (un par pan fonctionnel métier au-delà de ~30-40 fichiers). On squash avant de merger. |
| « Pas le temps, je fais une review courte » | Review complète, ou on dit que ce n'est pas prêt. |
| « Les tests DB échouent, c'est l'environnement » | Diagnostiquer (port, conteneur) et relancer jusqu'au vert. |
| « Haiku peut aussi juger la qualité » | Non : compilation et tests seulement. La qualité, c'est Opus à la fin. |
| « Petit écart pratique au plan, je le signale » | Pas d'écart. On amende la spec. |
| « Le plan est clair, je le résume dans le chat » | Le plan passe par Plannotator, approuvé avant le `/clear`. |
| « La spec est courte, l'utilisateur la lira dans le chat » | La spec s'ouvre toujours dans Plannotator. |
| « Spec approuvée, je demande si je passe au plan » | Non : l'approbation déclenche l'étape 1b puis le plan. |
| « Approuvée, donc les annotations jointes ne comptent pas » | Si : elles s'appliquent à la spec avant d'écrire le plan. |
| « Fermé sans annotation, c'est approuvé » | Non : seul `"decision": "approved"` (bouton Approuver de `--gate`) vaut approbation. Une session fermée (`dismissed`) se rouvre ou se confirme dans le chat. |
| « La règle ne touche que ce champ » | Chercher ses usages dans le code et lister toute sa portée dans la spec. |
| « La nouvelle validation ne concerne que les nouvelles saisies » | Elle s'applique aussi aux données en base au prochain enregistrement : la spec dit ce qu'elles deviennent. |
| « Les tests du plan passent, la tâche est finie » | Le contexte borné entier passe, et le rouge a été vu avant le code. |
| « Tests et code écrits d'un jet, c'est pareil » | Non : sans rouge constaté, le test ne prouve rien. |
| « Les retours de review sont dans le chat, ça suffit » | Ils vont dans `final-review.md` : le `/clear` les efface du chat. |
| « Je demande si l'utilisateur veut une review » | Non : ponytail-review et Opus se lancent seuls à la fin du développement. |

## Signaux d'alarme

- Implémenter dans la session qui a écrit le plan.
- Écrire le plan sans avoir cherché les usages des symboles modifiés.
- Merger une PR à plusieurs commits, hors découpage par pan fonctionnel métier d'une PR de plus de ~30-40 fichiers.
- `gh pr merge --merge`, ou un `push --force` sans `--force-with-lease`.
- Supprimer ou déplacer un fichier de `src/` quand le déploiement ne supprime pas (rsync sans `--delete`) : le signaler avant le merge.
- Terminer sans mettre à jour la mémoire.

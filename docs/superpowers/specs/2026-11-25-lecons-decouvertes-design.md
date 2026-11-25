# Découvertes dans les leçons

## But

`lecons.md` ne garde aujourd'hui que les frictions : le moment où le travail a buté. Ce que la session a appris sans
buter (une commande trouvée, une manière de tester qui a marché, une convention du code suivie, une particularité de
l'environnement) disparaît au `/clear`, et les sessions qui suivent le merge le cherchent de nouveau. La grille
« Step 1: Reflect » de `claude-md-management:revise-claude-md` vise justement ce savoir. Cette spec reprend sa
grille dans la règle de `lecons.md`, sans appeler le plugin : `lessons-extractor` trie ces lignes au merge comme les autres leçons. Termes du
glossaire : **découverte**, **leçon**, **friction**, **étiquette** (`docs/domaine.md`, contexte « Leçons »).

## 1. Demande initiale

> faudrait-il que les leçons des pr au merge soient gérées par /claude-md-management ?

Réponse donnée : non, `revise-claude-md` relit la conversation en cours (vide au merge, après `/clear`) et n'écrit que
des phrases dans `CLAUDE.md`. Puis :

> peut-on quand même intégrer le plugin pour une relecture de la session ?

Deux options proposées : A, reprendre la grille du plugin dans la règle de `lecons.md` ; B, appeler
`revise-claude-md` en fin de session et convertir ses diffs en leçons. Réponse :

> option A comme recommandé

## Approches

- **A, retenue** : la grille entre dans la règle de `lecons.md` (`global/skills/pr/SKILL.md`, « Dossier de suivi »).
  Aucune dépendance, un seul tri au merge.
- B, écartée : un tour de skill de plus par session, et son « Step 5 » propose d'appliquer les diffs dans
  `CLAUDE.md`, ce qui court-circuite le tri du merge (récidive, garde mécanique, budget de lignes).

## Règles

**R1 — Une leçon décrit une friction ou une découverte.** Découverte : savoir acquis en route qui aurait fait
gagner du temps s'il avait été écrit avant, d'après la grille du plugin : commande trouvée ou utile, manière de
tester qui a marché, convention du code suivie, particularité de l'environnement. Le format de la ligne ne change
pas : `- <date> (<action>) [<étiquette>] : <friction ou découverte>`. La liste d'exemples de friction reste ; celle
des découvertes s'y ajoute, avec « par exemple » (liste ouverte).

**R2 — Une découverte que la session a reçue du code, de git ou d'un fichier lu à chaque session ne s'écrit pas.**
Proche du filtre de `lessons-extractor` (« Rien non plus pour ce que git, GitHub ou le code disent déjà ») et du
plugin (« obvious information »), appliqué dès l'écriture pour ne pas grossir `lecons.md`. Une convention qu'on lit
dans le fichier voisin n'est pas une découverte. Une découverte refaite alors qu'une règle écrite la donnait s'écrit,
comme récidive (R4) : la règle n'a pas été trouvée (review finale, I3, décision de l'utilisateur). « Rien → rien »
reste.

**R3 — Étiquette d'une découverte.**

Les trois étiquettes restent. Seule la définition de `jugement` s'élargit : « seule une phrase lue l'évite ou la
transmet ». `méca` garde son sens, ce qu'un programme vérifie, et « garde mécanique » reste un contrôle : une
découverte devient donc presque toujours une règle (`jugement`), ou rien (`ponctuel`). Décision prise dans
Plannotator, contre l'élargissement de `méca` (script, alias), qui aurait changé le sens de « garde mécanique », et
contre une quatrième étiquette.

**R4 — Découverte déjà écrite.**

Une découverte que la session a dû refaire alors qu'une règle écrite la donnait déjà est une récidive : la règle n'a
pas été trouvée au moment voulu. La leçon porte `(récidive : <fichier> « <fragment> »)`, et l'extracteur la traite
comme celle d'une friction (déplacer, mécaniser ou retirer ; citée deux fois : mécaniser ou retirer). Décision prise
dans Plannotator.

**R5 — Particularité de l'environnement propre à la machine.**

Une particularité propre à la machine (chemin local, compte, outil installé ici seulement) est un piège : la session
l'écrit tout de suite dans la mémoire du projet (format de l'étape 6 « Mémoire » de `merge.md`), pas dans
`lecons.md`, qui alimente des règles versionnées et publiques. La règle de `lecons.md` le dit en une phrase ; rien ne
change au merge. Décision prise dans Plannotator ; « tout de suite » ajouté à la relecture de la PR : après un
`/clear`, l'étape 6 n'aurait plus rien pour la retrouver.

**R6 — Les étapes qui écrivent les leçons disent « leçons », plus « frictions ».** Elles renvoient au format de
`pr/SKILL.md` sans le recopier ; le mot « frictions » y ferait oublier les découvertes.

## 2. Portée

Établie par `git grep -n -i "friction" -- global docs/domaine.md CLAUDE.md` et `git grep -n "lecons.md"`.

| Endroit | Devient |
|---|---|
| `global/skills/pr/SKILL.md:54`, `lecons.md` (« Dossier de suivi ») | R1, R2 : format `<friction ou découverte>`, exemples de découverte ; étiquettes selon R3 ; récidive selon R4 ; R5 |
| `global/skills/pr/SKILL.md`, section « Nettoyage des branches » | déplacée telle quelle en fin de `merge.md` : R1-R5 font passer `SKILL.md` de 200 à 206 lignes, au-delà du budget de `test_pr_skill_table_matches_files`, qui ne se relève pas (décision de l'utilisateur à l'exécution) |
| `global/skills/pr/merge.md:67`, étape 5 « section « Nettoyage des branches » de `SKILL.md` » | renvoie à la section de `merge.md` |
| `global/skills/pr/SKILL.md`, sous la table « Actions à fichier » | une ligne : nettoyage après un merge ou une PR fermée sans merge → section de `merge.md` |
| `global/skills/feature/SKILL.md:28`, étape 7 « noter les frictions de la session » | R6 : « noter les leçons de la session » |
| `global/skills/bugfix/SKILL.md:36`, étape 8 « frictions de la session dans `lecons.md` » | R6 : « leçons de la session » |
| `global/skills/pr/comments.md:60`, « frictions dans `lecons.md` » | R6 : « leçons dans `lecons.md` » |
| `global/skills/pr/merge.md:28`, « Les frictions des étapes suivantes » | R6 : « Les leçons des étapes suivantes » |
| `global/skills/pr/merge.md:73`, « Frictions du squash, du merge et du nettoyage » | R6 : « Leçons du squash… » |
| `global/skills/pr/rebase.md:18`, « Frictions dans `lecons.md` » | R6 : « Leçons dans `lecons.md` » |
| `global/skills/pr/recette.md:39`, « Écrire `recette.md` et `lecons.md` » | inchangé : ne nomme pas le contenu |
| `global/agents/lessons-extractor.md:3`, description | « trie les leçons (frictions et découvertes) » |
| `global/agents/lessons-extractor.md:11`, but « buter sur les mêmes frictions » | ajoute « ni de refaire les mêmes découvertes » |
| `global/agents/lessons-extractor.md:36`, « quand la friction en vient » | « quand la leçon en vient » |
| `global/agents/lessons-extractor.md:43`, définitions des étiquettes | R3 : `jugement` « l'évite ou la transmet » |
| `global/agents/lessons-extractor.md:49`, « un `ponctuel` dont la friction revient » | « dont la leçon revient » |
| `global/agents/lessons-extractor.md`, « Récidive » et « Cible » | inchangés : R4 réutilise la récidive telle quelle, R5 ne passe pas par l'extracteur |
| `docs/domaine.md`, contexte « Leçons » | responsabilité, « Découverte », « Leçon » ; « Étiquette » (R3) ; « Récidive » : « friction revenue ou découverte refaite » (R4) |
| `docs/domaine.md`, contexte « Livraison », « Piège » | inchangé : R5 y range déjà la particularité de la machine |
| `CLAUDE.md` | inchangé : ne parle pas de `lecons.md` |
| `tests/` | inchangé : aucun test ne lit `lecons.md` ni le mot « friction » (`git grep -n "lecons\|friction" tests` vide) |

N'est plus lu : rien. « Nettoyage des branches » se lit dans `merge.md` par `merge` (étape 5) et, pour une PR
fermée sans merge, par une ligne de `pr/SKILL.md` sous la table des actions qui y renvoie (review finale, M1,
décision de l'utilisateur). La règle élargit ce qu'on écrit, pas ce qu'on lit.

## 3. Données existantes

Les `lecons.md` déjà écrits ne contiennent que des frictions : ils restent valides, le format ne change pas.

## 4. Critères d'acceptation

**P1 — Une session note ses découvertes et le merge les trie** (une seule story).

- Nominal : en fin de `feature` étape 7, une session qui a trouvé une commande utile écrit une ligne
  `- <date> (feature) [<étiquette>] : <découverte>` dans `lecons.md`.
- Nominal : au merge, `lessons-extractor` propose pour cette ligne une proposition qui suit son étiquette (R3).
- Nominal : les étapes de `feature`, `bugfix`, `comments`, `merge` et `rebase` qui écrivent `lecons.md` disent
  « leçons » (R6) ; `git grep -n -i friction -- global/skills` ne rend plus que la définition de `pr/SKILL.md`.
- Refus : une convention lisible dans le fichier voisin n'est pas écrite (R2) ; si elle l'est, l'extracteur ne
  propose rien.
- Refus : une session sans friction ni découverte n'écrit rien.
- Combiné : une session avec une friction et une découverte écrit deux lignes.
- Combiné : une découverte déjà donnée par une règle écrite porte `(récidive : …)` et l'extracteur propose de
  déplacer, mécaniser ou retirer la règle (R4).
- Combiné : une particularité propre à la machine ne s'écrit pas dans `lecons.md` ; la session l'écrit tout de suite
  dans la mémoire (R5).
- Combiné : une découverte qui se porterait par un script reste `jugement` et reçoit une règle (R3).
- Ancienne donnée : un `lecons.md` sans découverte se trie comme aujourd'hui.

## 5. Filet sur l'existant

Fichiers modifiés : du texte de skills et d'agent, sans test. Recette (étape 6) : un agent neuf joue
`lessons-extractor` sur un dossier de suivi d'essai qui contient une friction, une découverte et une découverte déjà
écrite, avant et après le changement.

## 6. Origine

Demande de l'utilisateur, née de la question sur `claude-md-management` ; aucun point du reste à faire.

## 7. Dette du code touché

Texte seulement. La ligne 54 de `pr/SKILL.md` grossit : elle reste sous 120 colonnes par ligne ; aucune fonction.

# main-guard : séparer jugement et suivi, remettre le fichier dans l'ordre

## But

Rendre `global/main-guard-hook.sh` lisible de haut en bas, sans changer ce qu'il refuse ou laisse passer. Le
jugement (`violates`) ne fait plus que répondre oui ou non. Le suivi des `cd` et des `switch` passe dans une
fonction à part. Le fichier suit l'ordre d'exécution.

## 1. Demande initiale

Issue #109 (label `dette-technique`), citée telle quelle :

> ## Contexte
>
> Avec la PR #103, `global/main-guard-hook.sh` est passé de 67 à 296 lignes. Le comportement est testé (135 tests), mais le fichier se lit mal : l'état est éparpillé, une fonction de jugement modifie l'état, et l'ordre du fichier ne suit pas l'exécution.
>
> Cette issue ne touche qu'à la structure, pas au comportement. Les tests existants doivent passer sans modification. On ne touche pas au parseur (`flatten`, `in_code`, `in_string`, `heredoc_*`) : la règle de `CLAUDE.md` sur les hooks qui analysent le shell s'applique.
>
> ## À faire
>
> 1. **Séparer le jugement du suivi.** `violates` décide si un segment viole la règle, mais remplit aussi `pending_here`, `pending`, `pending_dir` et `pending_to` quand le segment est un `cd` ou un `switch`. Extraire ce suivi dans une fonction `track` (cd/pushd, switch/checkout) appelée depuis la boucle principale, pour que `violates` ne fasse que répondre oui ou non.
> 2. **Regrouper l'état et les réglages en tête.** `forks` et les `pending_*` sont initialisés ligne 282, après des fonctions qui s'en servent. `LC_ALL=C` est réglé ligne 116, en plein milieu. Les déclarer avec `here` et `switched_*`, juste après la lecture de l'entrée.
> 3. **Ordre du fichier.** `deny` est défini après l'appel `flatten || flatten_plain`, alors que `violates` l'appelle (pour le plafond de forks). Mettre l'ordre suivant : entrée et état, fonctions de jugement (`branch_of`, `resolve`, `violates`, `deny`), parseur, puis le flux principal (`flatten || flatten_plain` et la boucle) à la fin.
> 4. **Code mort.** `ctx=""` dans `flatten_plain` ne sert à rien : aucune fonction appelée par le repli ne lit `ctx`.
> 5. **En-tête lisible.** Les trois lignes `shortcut:` des lignes 5 à 7, dont une de plus de 400 caractères, deviennent une ligne `shortcut:` par limite.
>
> ## Hors périmètre
>
> - Changer ce que le parseur accepte ou refuse, y compris les limites listées dans les `shortcut:`.
> - Remplacer le parseur par un vrai parseur shell.
> - Factoriser les deux boucles qui lisent les arguments positionnels (`switch`/`checkout` et `push`) : elles sont courtes et ne lisent pas les mêmes options.
>
> ## Vérification
>
> - `bash tests/run.sh` au vert, sans toucher à `tests/test_main_guard.sh`.
> - Le hook garde le même nombre de lignes, ou moins.

## 2. Portée

Vocabulaire : contexte « Garde de main » de `docs/domaine.md` (segment, jugement, suivi, dossier de départ, dossier
jugé, branche prise, préfixe de lancement, plafond de processus, repli).

Un seul fichier de code change : `global/main-guard-hook.sh`. Ses lecteurs, cherchés par `git grep main-guard-hook`
et `git grep main-guard` : `settings/base.json` (déclaration du hook PreToolUse, chemin inchangé),
`tests/test_main_guard.sh` (appelle le script par son chemin, inchangé), `CLAUDE.md` (décrit le comportement,
inchangé puisque le comportement ne change pas), la mémoire `depot-livraison.md` (idem). Aucune fonction du hook
n'est appelée de l'extérieur : le script se lance entier, entrée JSON sur stdin, décision JSON sur stdout.

### R1 — Lecture du segment, suivi et jugement séparés

`violates` lit aujourd'hui la tête du segment (préfixes de lancement, `cd`/`pushd`, options globales de git, `-C`,
sous-commande), compte le plafond de processus, remplit le changement en attente et juge. Il devient quatre rôles
(lecture, suivi, plafond, jugement), et le suivi se simplifie (R1b) :

| Fonction | Rôle | Écrit | Lit |
|---|---|---|---|
| `parse` (nouvelle) | lit la tête du segment, une seule fois, et remet ses sorties à zéro à chaque appel | `verb` (`cd` pour `cd` et `pushd`, `git` pour `git` et `*/git`, vide sinon), `dir` (dossier de `-C`, sinon dossier jugé), `sub` (sous-commande git, vide hors git), `args` (mots qui suivent) | `here` |
| `track` (nouvelle) | suivi : appelle `track_cd` ou `track_switch` | rien elle-même | `verb`, `sub` |
| `track_cd` | dossier d'un `cd`/`pushd` (options `-L -P -e -@`, `--`, chemin entre guillemets) | `here` | `args`, `cwd`, `here` |
| `track_switch` | branche d'un `switch`/`checkout` (bloc actuel, sans le `return 1`) | `switched_dir`, `switched_to` | `args`, `dir`, `sub`, `switched_*` |
| `violates` | jugement seul : `commit` sur main, ou `push` (délégué à `pushes_main`) | rien | `sub`, `dir`, `switched_*` |
| `pushes_main` (nouvelle, corps de la branche `push` actuelle) | refspecs, `--delete`, `--tags`, `HEAD` | rien | `args`, `dir`, `switched_*` (via `branch_of`) |

Amendement après review (dette §7 corrigée dans la PR) : quatre aides gardent un seul niveau de contrôle par
fonction, sans changer de décision. `git_option` (option git avant la sous-commande, code retour = mots lus, fixe
`dir` pour `-C`) sert `parse` ; `switch_arg` (range un argument dans `create` ou `pos`, locaux de `track_switch`) et
`previous_branch` (« - » : vide juste après un switch dans le même dépôt, sinon `@{-1}`) servent `track_switch` ;
`positional` (garde dans `pos` les mots qui ne sont pas des options) sert `pushes_main`, dont les refspecs se jugent
sans boucle, par expansion sur le tableau.

`track_switch` et `pushes_main` déclarent leurs variables de boucle en `local` (globales aujourd'hui) : sans effet sur
la décision, aucune autre fonction ne les lit. `violates` et `track` ne font rien quand `sub` ou `verb` n'est pas
celui qu'elles attendent : rien ne reste du segment précédent.

Le plafond de processus (`forks`, 2000) sort de `violates` et passe dans la boucle, une incrémentation par segment
dont `verb` n'est pas vide, entre `parse` et `track`. Le texte du refus reste identique. Son commentaire devient
« chaque `cd`, `pushd` ou git peut coûter un processus » : après R1, un `git status` sans `-C` n'en lance plus.

Ce qui reste identique, ligne pour ligne : la regex des préfixes de lancement, la lecture de `-C`/`-c`, le bloc de
`switch`/`checkout` (premier argument positionnel, `-b`/`-c` collés, `-`, `@{-1}`), les deux boucles d'arguments
positionnels (hors périmètre de l'issue), `branch_of`, `resolve`, les deux textes de refus.

Différence invisible : `branch_of` (un ou deux processus git) n'est plus appelé que pour `commit` et `push`, au lieu
de chaque segment git. La décision ne change pas ; seul le temps baisse.

Noms : `parse` ne pose aucune globale `n` ni `i` (le parseur se sert d'un `n` global, le nombre de caractères) ; ses
compteurs sont `local`.

### R1b — Le suivi s'applique tout de suite, sans changement en attente

Réponse à l'annotation « faudrait-il revoir simplement le jugement pour le simplifier ? ». Le jugement lui-même
(`commit` sur main, refspecs du `push`) n'a rien à retirer sans changer de décision. Le suivi, si : les quatre
`pending_*` ne servent qu'à différer d'un segment ce qu'un séparateur autre que `&&` annule de toute façon.

Aujourd'hui : un `cd` ou un `switch` remplit `pending_*` ; au segment suivant, `&&` les copie dans `here` et
`switched_*`, tout autre séparateur remet `here="$cwd"` et vide `switched_*`. Après R1b : `track_cd` écrit `here`,
`track_switch` écrit `switched_dir`/`switched_to` tout de suite ; la boucle garde seulement la remise au départ :

```bash
[[ -n "$sep" && "$sep" != "&&" ]] && here="$cwd" switched_dir="" switched_to=""
```

Même décision, segment par segment :
- le segment du `cd` ou du `switch` lui-même n'est jamais jugé sur ce qu'il change (`violates` ne juge que `commit`
  et `push`) ;
- suivant relié par `&&` : même valeur qu'aujourd'hui (copie de `pending_*`) ;
- suivant relié par `;` `||` `|` ou un saut de ligne : remise au départ dans les deux cas ;
- `switch -` relit `switched_*` avant de l'écrire : c'est l'état du segment, comme aujourd'hui ;
- segment vide entre deux `&&` : aujourd'hui il copie `pending_*` puis les vide, le suivant garde `here` ; après R1b
  `here` est déjà écrit : même valeur.

Le terme « changement en attente » sort du glossaire (`docs/domaine.md`) ; l'invariant « un `cd` ou un switch ne
compte que suivi de `&&` » reste vrai.

### R2 — État et réglages en tête

Juste après la lecture de l'entrée (`input`, `cmd`, `cwd`), dans cet ordre : `LC_ALL=C`, puis `here`,
`switched_dir`/`switched_to`, `forks`, et les sorties de `parse` (`verb dir sub args`), chacun avec son commentaire
d'une ligne, dans les termes du glossaire (`here` : dossier jugé, au lieu de « dossier courant » aujourd'hui ;
`forks` : plafond de processus). `LC_ALL=C` se place **après** les deux `jq` de lecture, comme le dit l'issue : il
doit seulement précéder la lecture caractère par caractère (`read -n1`) ; les `jq` gardent la locale de l'utilisateur.

La ligne 282 (`pending="" … forks=0`) disparaît, comme la remise à zéro par segment (`pending="" pending_here=""`) :
R1b retire les `pending_*`.

### R3 — Ordre du fichier

1. En-tête (rôle du hook, `shortcut:`), `set -uo pipefail`.
2. Entrée et état (R2).
3. Fonctions de jugement et de suivi : `branch_of`, `resolve`, `parse`, `track`, `track_cd`, `track_switch`,
   `violates`, `pushes_main`, `deny` ; chaque aide (R1) suit la fonction qu'elle sert.
4. Parseur, code inchangé hormis R4 (commentaires resserrés, R6) : commentaire de tête, `ch`/`n`/`stop`, `emit` …
   `flatten_plain`.
5. Flux principal : `flatten || flatten_plain`, puis la boucle.

### R4 — Code mort

`flatten_plain` initialise `flat="" last="" prev=""`, sans `ctx=""`. Vérifié : ni `escape`, ni `plain_char`, ni
`eol`, ni `amp_pipe`, ni `emit` ne lisent `ctx`.

### R5 — Une ligne `shortcut:` par limite

Les lignes 5 à 7 deviennent sept lignes, chacune au format `shortcut: <la limite>, <quand passer à mieux>` :

1. un `cd` non résolu (`$VAR`, `$(…)`, `cd -`) est jugé sur le dossier de départ ; résoudre les variables si ça gêne ;
2. après `;` `||` `|` ou un saut de ligne, retour au départ (depuis un worktree, `git switch main; git commit` passe) ;
   garder un retour vers main si ça gêne ;
3. le contenu de `$( )` et de `` ` `` n'est pas jugé ;
4. un `motif)` de `case` dans `$( )` ferme le `$( )` trop tôt ;
5. un `<<` arithmétique (`$((1<<2))`) est pris pour un heredoc ;
6. les lignes d'un heredoc hors `$( )` sont jugées comme des commandes ;
7. guillemets déséquilibrés ou contexte de lecture resté ouvert : repli où chaque saut de ligne coupe, guillemets
   ignorés.

Les lignes 3 à 7 finissent par « vrai parseur shell si ça gêne ». Le texte des limites est raccourci (style
télégraphique, demande en review, M3), sans en retirer une.

### R6 — Budget de lignes

Un essai jetable de R1 à R5 avec R1b (hors dépôt) passe les 14 tests de `tests/test_main_guard.sh`, les quatre du §5
et shellcheck, et compte 311 lignes contre 296 (318 sans R1b) : 243 lignes de code au lieu de 239 (+4 : en-têtes de
`parse`, `track`, `track_cd`, `pushes_main`, moins les `pending_*`), +6 lignes de commentaire (dont +4 pour R5), +5
lignes blanches entre fonctions. Le point 5 de l'issue ajoute à lui seul quatre lignes, ce qui contredit le critère
« même nombre de lignes, ou moins ».

Décision : le budget se compte en lignes de code, hors commentaires et lignes blanches, plafond 243 (mesure :
`grep -cvE '^\s*(#|$)' global/main-guard-hook.sh`). Le critère de l'issue « même nombre de lignes, ou moins » est
amendé dans ce sens ; commentaires et lignes blanches ne sont pas plafonnés.

Amendement après review (M3) : les commentaires sont resserrés (regroupés, ou en fin de ligne), sans toucher au code.
Le fichier revient à 296 lignes, comme sur `main` : le critère de l'issue « même nombre de lignes, ou moins » tient
aussi au total. Après la dette §7 corrigée (aides de R1) : 296 lignes, dont 239 de code, autant que sur `main`.

## 3. Données existantes

Sans objet : le hook ne stocke rien. Les appels déjà acceptés ou refusés gardent la même décision (R1).

## 4. Critères d'acceptation

### Story P1 — Le hook se lit de haut en bas, même décision

Seule story : la demande ne se découpe pas.

Cas nominaux :
- `bash tests/run.sh` au vert, `tests/test_main_guard.sh` identique à `main` (`git diff main -- tests/test_main_guard.sh` vide).
- `violates` ne contient aucune affectation d'une variable globale (`pending*`, `forks`, `here`, `switched_*`).
- `grep -n` des définitions de fonctions donne l'ordre de R3 ; `deny` est défini avant sa première utilisation.
- `LC_ALL=C` apparaît une seule fois, juste après la lecture de l'entrée.
- `flatten_plain` ne mentionne plus `ctx`.
- Sept lignes `shortcut:`, aucune au-delà de 200 caractères.
- Le hook compte au plus 243 lignes de code (R6).

Refus inchangés :
- Entrée illisible : code 2, message identique.
- Plus de 2000 segments `cd`/`pushd`/git : refus, même texte.
- Commit sur main, push vers main : refus, même texte.

Cas combinés (non couverts aujourd'hui, voir §5) :
- Depuis un worktree sur `feat/x`, `git -C ../work commit` (dépôt principal sur main) : refusé ;
  `git -C ../work switch -c y && git -C ../work commit` : permis (le suivi lit `-C`). Chemin relatif sans espace :
  `read -ra` coupe un chemin à espaces entre guillemets, et le bac à sable des tests en contient.
- `env cd ../wt && git commit` depuis main, `../wt` sur `feat/x` : permis (le suivi saute les préfixes).
- 1500 segments `git status` : permis (le plafond compte chaque segment une fois, pas deux).
- `git switch -c y && git commit -m x; echo ok` depuis main : permis (rien ne reste du segment précédent : au
  troisième segment, `;` efface la branche prise, et un `sub=commit` resté du deuxième serait jugé sur main).

## 5. Filet sur l'existant

`tests/test_main_guard.sh` couvre 14 fonctions de test, mais quatre comportements que R1 déplace n'y sont pas figés :
la lecture de `-C` pour un switch, les préfixes de lancement devant `cd`, le compte du plafond (le test actuel
envoie 2002 segments : un double comptage ne se verrait pas) et l'absence de reste d'un segment au suivant. L'issue
interdit de toucher à `tests/test_main_guard.sh` : les quatre cas de caractérisation des cas combinés (§4) vont dans un fichier nouveau,
`tests/test_main_guard_track.sh`, qui réutilise `make_repo` et `guard` du fichier existant (le runner source tous
les `tests/test_*.sh`). Ils passent au vert sur `main` avant toute modification du hook. C'est la première tâche du plan.

Vérifié dans l'essai jetable pour les trois premiers : ils passent sur le hook actuel et sur la version R1-R5, et chacun échoue sous sa
mutation (`track_switch` qui lit `here` au lieu de `dir` ; `cd` reconnu seulement en premier mot ; plafond compté
deux fois).

## 6. Origine

- Issue #109, *défaut ancien* (dette) introduit par la PR #103, qui a fait passer le hook de 67 à 296 lignes.
- Hors périmètre, repris de l'issue : changer ce que le parseur accepte ; un vrai parseur shell ; factoriser les deux
  boucles d'arguments positionnels.

## 7. Dette du code touché

Écarts à la grille qualité des fonctions modifiées (le parseur n'est pas modifié hormis R4, donc pas relevé) :

| Fonction | Écart | Décision |
|---|---|---|
| `violates` | 76 lignes, plusieurs niveaux de contrôle, état global écrit | corrigé par R1 |
| `track_switch` (bloc repris de `violates`) | ~22 lignes, `if` dans un `if` (règle 1) | corrigé après review : `switch_arg`, `previous_branch` (R1) |
| `pushes_main` (bloc repris de `violates`) | `[[ ]] && return` dans une boucle (règle 1) | corrigé après review : `positional`, refspecs jugées sans boucle (R1) |
| `parse` | boucle `while` + `case` imbriqué pour les options git (règle 1) | corrigé après review : `git_option` (R1) |
| fichier | 296 lignes > 200 (règle 7), déjà au-delà avant la branche | reporté au reste à faire : séparer parseur et jugement en deux fichiers serait un changement de structure plus large que l'issue |

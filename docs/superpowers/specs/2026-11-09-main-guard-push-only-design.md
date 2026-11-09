# main-guard : ne garder que ce que la protection de main exige

## But

`global/main-guard-hook.sh` compense l'absence de protection de branche côté GitHub. Le seul risque que rien ne
rattrape est un **push vers main** (glossaire, contexte « Garde de main »). Un commit local sur main se rattrape :
`/pr push` le fait déjà à son étape 0 (`git switch -c`, puis `git branch -f main origin/main`). Le hook ne garde que
ce qui sert à juger un push vers main sans faux refus, et passe de 296 lignes à moins de 200 (seuil de la grille qualité ; 190 sur le
brouillon qui a servi au plan).

## 1. Demande initiale

Issue #111 (label `dette-technique`), citée telle quelle :

> ## Contexte
>
> `global/main-guard-hook.sh` a été créé (30ec519) pour une seule raison : sur un projet GitHub, la protection de `main` ne peut pas être configurée, et rien n'empêche côté serveur un commit ou un push direct sur `main`. Le hook compense ce manque côté client.
>
> Depuis la PR #103, il va beaucoup plus loin. Il suit les `cd`/`pushd` et les `git switch`/`checkout` d'une même commande, lit les options globales de git (`-C`, `-c`), les préfixes de lancement (`rtk`, `sudo`, `env`, `X=1`), la branche précédente (`switch -`, `@{-1}`) et chaque forme de refspec (`+main`, `x:refs/heads/main`, `a b main`, `- main`). Le tout passe par un parseur shell maison qui a sept limites connues (`shortcut:`). Le fichier fait 296 lignes, contre 67 à l'origine.
>
> La liste des 100 jugements de référence (50 commandes, lancées depuis le dépôt principal sur `main` et depuis un worktree) montre ce que chaque règle apporte. Une bonne partie sert seulement à **laisser passer** des commandes légitimes que la règle de départ refusait à tort (`cd <worktree> && git commit`, `git switch -c x && git commit`), et pas à protéger `main`.
>
> ## Ce qu'on protège vraiment
>
> Le risque qu'on ne peut pas rattraper, c'est un **push vers `main`** sur le dépôt distant. Un commit local sur `main` se rattrape (`git branch <x>` puis remettre `main` sur `origin/main`).
>
> ## À faire
>
> 1. Lister, pour chaque règle du hook, le risque qu'elle couvre : push vers `main`, commit local sur `main`, ou faux refus évité.
> 2. Retirer le superflu. Pistes, à trancher :
>    - **Ne juger que le push.** Le commit sur `main` n'est plus refusé, ce qui supprime l'essentiel du suivi `switch`/`checkout`, `previous_branch` et le cas particulier du `checkout <fichier>`.
>    - **Refspecs** : garder seulement `main`, `+main`, `<src>:main` et le push sans refspec depuis `main`. Les formes rares (`refs/heads/main`, plusieurs refspecs, `-`) se retirent ou se notent en `shortcut:`.
>    - **Suivi des `cd`** : à garder tant qu'un push sans refspec reste jugé sur la branche courante (`cd <worktree> && git push`).
> 3. Mettre à jour `CLAUDE.md` (paragraphe « main-guard »), `docs/domaine.md` (contexte « Garde de main ») et les tests (`tests/test_main_guard.sh`, `tests/test_main_guard_track.sh`).
>
> ## Hors périmètre
>
> - Remplacer le parseur par un vrai parseur shell.
> - Configurer la protection de branche côté GitHub (impossible sur ce projet, c'est l'origine du hook).
>
> ## Vérification
>
> - La nouvelle liste des 100 jugements, avec chaque décision qui change, justifiée dans la PR.
> - Le fichier du hook nettement plus court, et chaque `shortcut:` restant toujours nécessaire.
> - `bash tests/run.sh` au vert.

Vocabulaire : contexte « Garde de main » de `docs/domaine.md` (segment, jugement, suivi, push vers main, faux refus,
dossier de départ, dossier jugé, branche prise, préfixe de lancement).

## 2. Portée

### Ce que couvre chaque règle aujourd'hui (À faire, point 1)

| Règle (code actuel) | Risque couvert | Devient |
|---|---|---|
| `violates` → `commit` sur main | commit local | retirée (R1) |
| `pushes_main` : sans refspec ou `HEAD` depuis main | push vers main | gardée |
| `pushes_main` : `main`, `+main`, `x:main`, `refs/heads/main`, plusieurs refspecs, `- main` | push vers main | gardée (R3) |
| `--delete`, `-d`, `--tags` permis | faux refus évité | resserrée (R3) |
| `track_cd`, `here`, `resolve` (`cd`, `pushd`, `~`, options de `cd`) | faux refus (`cd <worktree> && git push`) | gardée |
| `git_option` (`-C`, `-c`, `--git-dir`, `--work-tree`, `--namespace`) | push vers main, faux refus | gardée (R5 : les trois dernières lues avec leur valeur) |
| Préfixes de lancement (`rtk`, `sudo`, `env`, `X=1`, `if`…) | push vers main | gardée |
| `track_switch` avec `-c`/`-b` | faux refus (`git switch -c x && git push -u origin HEAD`) | réduite (R2) |
| `checkout main`, `switch -`, `@{-1}`, `previous_branch`, `checkout <fichier>` | commit sur main après un retour sur main | retirés (R2) |
| Parseur (`flatten`, heredocs, `$( )`, backticks, `${…}`, repli, `\r`) | segment bien coupé : faux refus et push caché | réduit (R4) |
| Plafond de 2000 processus, entrée illisible = refus | jugement impossible | gardés |

### R1 — Ne juger que le push

Décision : le hook ne juge plus que le push. Un commit local sur main se rattrape (`/pr push` le fait à son étape
0), un push vers main non. Les textes qui contiennent « git commit » (message, heredoc, `jq`) ne sont plus refusés,
et le contournement par la plomberie (`commit-tree`) noté dans `CLAUDE.md` disparaît.

`violates` ne connaît plus que `push` ; message de refus « Pas de push vers main : passe par /pr push, qui crée la
branche et ouvre la PR. » ; en-tête du hook réécrit.

### R2 — Suivi des `switch` réduit

Un push sans refspec ou vers `HEAD` se juge sur la branche du dossier. Sans aucun suivi, `git switch -c x && git push
-u origin HEAD`, lancé depuis main, serait refusé : nouveau faux refus sur un enchaînement que les skills écrivent.

Décision : un `git switch` ou `git checkout` relié par `&&` qui crée une branche (`-c`, `-b`, `-C`, `-B`, `--create`,
`--force-create`, `--orphan`, options courtes collées comme `-qb`) la retient comme branche prise. Tout autre `switch`/`checkout` (`main`, `-`, `@{-1}`,
une branche existante, un fichier) rend la branche inconnue, jugée comme main : aucun push vers main ne se cache
derrière un switch, au prix d'un faux refus rare (`git switch feat/x && git push`, permis aujourd'hui).

`previous_branch`, les cas `-`/`@{-1}` et le cas `checkout <fichier>` disparaissent. La branche
prise vaut pour le dépôt du switch (`git rev-parse --show-toplevel`), sous-dossiers compris, comme aujourd'hui.

### R3 — Refspecs et options de push

Le contrôle des refspecs tient déjà en une ligne (`dests`) : retirer les formes rares ne raccourcit rien. Trois trous
existent depuis 30ec519, vérifiés sur le hook actuel :

- `git push --tags origin main` passe, alors qu'il pousse main en plus des tags (vérifié sur un dépôt nu). Sans
  refspec, `git push --tags` ne pousse que les tags.
- `git push origin --delete main` (ou `-d`) passe et supprime main sur le dépôt distant.
- `git push origin "main"` passe : les guillemets restent collés au mot.

Décision : les formes rares (`refs/heads/main`, plusieurs refspecs, `- main`) restent, elles ne coûtent aucune
ligne, et les trois trous se ferment : `--tags` ne dispense plus de juger les refspecs données, `--delete`/`-d` est
refusé quand il vise main, les guillemets sont retirés avant de comparer.

Décision : `git push --all`, `--branches` (alias de `--all`, git 2.43 et suivants) et `git push --mirror` sont refusés, d'où qu'ils partent. Ils poussent toutes les
branches locales, main compris, et avec R1 le main local peut porter des commits.

Décision : `-o`/`--push-option` se lit avec sa valeur (mot suivant), comme `-C` pour git : `git push -o ci.skip
origin` depuis main est un push sans refspec, refusé. La forme collée (`--push-option=x`, `-ox`) est déjà un seul
mot.

Reste en `shortcut:` : un push sans refspec depuis une branche dont l'upstream est main avec `push.default=upstream`
(le défaut de git, `simple`, refuse ce push quand les noms diffèrent).

### R4 — Parseur réduit

Le parseur actuel (`flatten`, `in_code`, `in_string`, `heredoc_op`, `heredoc_bodies`, `flatten_plain`…, environ 150
lignes) sert à ne pas couper un segment au milieu d'un texte. Avec R1, le texte qui posait problème (message de
commit, heredoc, argument `jq` contenant « git commit ») n'est plus jugé : seul compte un texte qui contient
« git push » juste après un séparateur.

Décision : la lecture ne suit plus que les guillemets simples et doubles (environ 50 lignes, contre 150). Un séparateur entre
guillemets ne coupe pas, pour que `cd "<dossier>" && echo "a; b" && git push` garde son dossier. Guillemets
déséquilibrés : chaque séparateur coupe. Heredocs, `$( )`, `${…}` ne sont plus suivis : une ligne de heredoc qui
commence par « git push … main » est refusée (faux refus, contourné en écrivant le texte avec Write). Un `$( )`
entre guillemets doubles n'est pas suivi : ses propres guillemets décalent la lecture, et deux apostrophes à
l'intérieur (`"$(printf "%s" "l'a")" && git push && echo "$(printf "%s" "c'est")"`) cachent la commande
qu'elles encadrent ; limite trouvée en écrivant le plan, notée en `shortcut:` avec son test.

`$(`, la `)` qui la ferme et `` ` `` hors guillemets valent `&&` : la substitution suit le dossier jugé et la
branche prise du segment, sans retour au départ (un compteur de `$(` ouverts, remis à zéro à chaque lecture,
distingue cette `)` d'une `)` nue). Limite en `shortcut:` : un `cd` dans `$( )` compte pour la suite
(`x=$(cd ../wt) && git push` depuis main passe). `$'…'` est lu comme `'…'` : `\'` y ferme le guillemet et décale la
lecture (`echo $'it\'s' ; git push origin main ; echo x\'` passe), limite en `shortcut:`.

`(` et `)` nus, `&` seul et `|&` hors guillemets coupent comme `;` ; `{` reste un
préfixe de lancement (R5), il ne coupe pas, pour que `cd ../wt && { git push; }` garde son dossier ; `\` suivi d'un
saut de ligne recolle ; un saut de ligne après `&&`, `||` ou `|` continue la chaîne. Les limites restantes sont en
`shortcut:`, une par limite, chacune vérifiée nécessaire.

Décision : hors guillemets, un `#` en début de mot est un commentaire, ignoré jusqu'au saut de ligne, comme
aujourd'hui. Sinon `# on pousse l'arbre` déséquilibrerait les guillemets et ferait couper toute la commande.

### R5 — Inchangé

Suivi des `cd`/`pushd` (dossier jugé, `~`, options, chemin non résolu → dossier de départ), retour au dossier de
départ après `;` `||` ou saut de ligne (un élément de pipeline repart de l'état d'avant le pipeline ; le `cd` ou le `switch` de son dernier élément compte pour la suite), redirections ignorées, `git -C` (et `--git-dir`, `--work-tree`, `--namespace`, lus avec leur valeur sans changer le dossier jugé), préfixes de lancement, plafond de 2000 processus, entrée
illisible = refus (exit 2), push d'un tag, d'une autre branche et `--delete` d'une autre branche permis.

### R6 — Documentation

- `CLAUDE.md`, paragraphe « main-guard » (ligne 10) : réécrit pour le push seul ; le contournement par la plomberie
  disparaît ; la mise en garde sur les textes change d'objet : un texte dont une ligne commence par
  `git push` vers main (heredoc, guillemets déséquilibrés) peut être refusé, l'écrire avec Write.
- `CLAUDE.md` ligne 11 (« Hook qui analyse une commande shell ») : inchangé, la règle vaut encore pour la lecture
  réduite.
- `docs/domaine.md`, contexte « Garde de main » : responsabilité, définitions de « Segment » (séparateurs de R4),
  « Jugement », « Suivi », « Branche prise » (un switch qui ne crée pas de branche rend la branche inconnue, jugée
  comme main), « Contexte de lecture », « Repli » alignées sur R1 à R4 ; invariant « push d'un tag,
  `--delete` d'une autre branche et push d'une autre branche restent permis depuis main » ; « Push vers main » et
  « Faux refus » ajoutés (commit de la spec).
- En-tête de `global/main-guard-hook.sh` : une ligne de rôle, une ligne `shortcut:` par limite restante.

### Lecteurs du hook

`git grep main-guard` : `settings/base.json:30` (déclaration PreToolUse, chemin inchangé), `CLAUDE.md:10-11`,
`docs/domaine.md` (contexte « Garde de main »), `tests/test_main_guard.sh` et `tests/test_main_guard_track.sh`
(lancent le script par son chemin), plans et specs passés (historique, inchangés). Aucun skill ne cite main-guard ;
`global/skills/pr/push.md` étape 0 (rattrapage d'un commit sur main) : inchangé.

## 3. Données existantes

Aucune donnée : le hook ne stocke rien. Les appels déjà refusés n'ont pas d'état à reprendre.

## 4. Critères d'acceptation

### Story P1 — Le hook ne juge que le push vers main

Une seule story : la demande ne se découpe pas.

Cas nominaux, dans un bac à sable : `work`, dépôt principal sur main ; `wt`, son worktree sur `feat/x`, à côté
(`../wt` depuis `work`, `../work` depuis `wt`) :

- Refusé depuis main : `git push`, `git push origin HEAD`, `git push origin +HEAD`, `git push origin main`,
  `git push -f origin main`, `git push origin +main`, `git push origin feat/x:main`,
  `git push origin x:refs/heads/main`, `git push origin a b main`, `git -C <dépôt sur main> push`.
- Refusé depuis le worktree : `git push origin HEAD:main`, `git -C ../work push`, `cd ../work && git push`.
- Permis : `git push -u origin feat/x`, `git push origin v1`, `git push origin --delete feat/x`, `git push --tags`,
  `cd ../wt && git push`, `git -C ../wt push` depuis main, `git switch -c z && git push -u origin HEAD` depuis main.
- Permis : tout `git commit`, sur main ou non.

Refus :

- R3 : `git push --tags origin main`, `git push origin --delete main`, `git push -d origin main`,
  `git push origin "main"` refusés.
- R3 : `git push -o ci.skip origin` refusé depuis main ; `git push --all origin`, `git push --branches origin` et `git push --mirror origin` refusés, depuis main comme depuis
  le worktree.
- R4 : `cd ../work && v=$(git rev-parse HEAD) && git push` (et avec des backticks) refusé depuis le worktree ;
  `git switch -c z && v=$(git rev-parse HEAD) && git push` permis depuis main.
- R5 : `git --git-dir .git push origin main` refusé.
- Entrée illisible : exit 2 ; plus de 2000 segments `cd` ou git : refus.

Cas combinés :

- Suivi × séparateur : `cd ../wt; git push` et `cd ../wt || git push` depuis main refusés ;
  `cd ../wt && git push` permis ; `cd ../wt &&⏎git push` permis.
- Suivi × switch (R2) : `git switch -c z && git switch main && git push` refusé ;
  `git switch -c z; git push` depuis main refusé ; `git switch main && git push` depuis le worktree refusé ;
  `git switch -c z && cd sub && git push` permis (sous-dossier du dépôt) ; `git switch feat/x && git push` depuis
  main refusé (faux refus accepté, permis aujourd'hui).
- Lecture × suivi (R4) : `cd ../wt && git commit -m "a; b" && git push` permis ;
  `cd ../wt && git commit -m "titre⏎⏎corps" && git push` permis ; guillemet seul suivi de `; git push` depuis main
  refusé.
- Préfixe × push : `rtk git push`, `sudo git push`, `X=1 git push`, `/usr/bin/git push` refusés depuis main ;
  `echo git push` permis.

Mesures :

- `global/main-guard-hook.sh` sous 200 lignes (`wc -l`) ; chaque `shortcut:`
  restant a un test qui montre la limite.
- Liste des jugements (script de la PR #110, mêmes 50 commandes, plus 8 commandes de push ajoutées (R2, R3, suivi),
  soit 116 jugements) : chaque décision qui change est justifiée dans la description de la PR. Les autres cas
  combinés de push sont figés par les tests de caractérisation (§5).
- `bash tests/run.sh` au vert, shellcheck compris.

## 5. Filet sur l'existant

Les tests actuels jugent surtout des `git commit`, qui changent de décision avec R1. Le suivi des `cd`, `-C`, les
préfixes et les séparateurs ne sont figés pour le push que par quelques cas (`git push`, `HEAD`, `HEAD:main`). Avant
de toucher au hook, une tâche ajoute à `tests/test_main_guard_track.sh` la caractérisation, verte sur `main`, des cas
de push gardés : chaque cas « Suivi × séparateur », « Préfixe × push » et `-C` ci-dessus, `cd ../wt && git commit -m
"a; b" && git push`, et `git switch -c z && git push -u origin HEAD` depuis main. Les tests de commit sont ensuite
réécrits ou retirés dans la tâche qui change la décision, chacun nommé.

## 6. Origine

- Issue #111 : *défaut ancien* de conception, la portée du hook a grossi avec la PR #103.
- Trous de R3 (`--tags` avec refspec, `--delete main`, guillemets) : *défaut ancien*, présents depuis 30ec519.
- Origine : review finale de la branche (I1, I2, M1, P2).
- Hors périmètre, repris de l'issue : vrai parseur shell ; protection de branche côté GitHub.
- Hors périmètre, relevé par l'analyse : `cd <worktree> && t=$(…); … git push` est refusé depuis main (le `;` ramène
  au dossier de départ), aujourd'hui comme demain ; noté dans « Limites » de la PR.

## 7. Dette du code touché

| Fonction | Écart | Décision |
|---|---|---|
| fichier `global/main-guard-hook.sh` | 296 lignes > 200 | corrigé dans cette PR (R1 à R4) |
| `flatten`, `in_code`, `heredoc_op`, `heredoc_bodies` | plusieurs niveaux de contrôle, > 20 lignes | corrigé : retirées (R4) |
| `track_switch` | plusieurs niveaux, dépend de `previous_branch` | corrigé : réduite (R2) |
| `pushes_main` | une ligne de 160 caractères, trois tableaux enchaînés | corrigé dans cette PR, sans effet sur la spec |
| `branch_of` | une ligne de 170 caractères | corrigé dans cette PR, sans effet sur la spec |

## Révision : AST shfmt

Décision de l'utilisateur, après les relectures adverses de la branche : chaque relecture trouvait une forme shell que
le parseur maison lisait mal (`$'…'`, heredocs, `case`, `{ }`, redirections collées). Le « vrai parseur shell », hors
périmètre au §6, entre dans la PR : le hook lit l'arbre de `shfmt --to-json` (mvdan/sh) et ne garde aucune lecture
maison de la syntaxe.

- Lecture : jq traduit l'arbre en programme pour une pile d'ensembles d'états possibles (dossier jugé, dépôt basculé,
  branche prise). `&&` part des états de réussite, `;` `||` et saut de ligne de tous les états (réussite et échec),
  pipeline, `( )`, `&`, `$( )` et backtick tournent en sous-shell ; `{ }` reste dans le shell ; if, case, boucles et
  corps de fonction sont jugés en un passage, leurs états ajoutés à ceux d'avant. Le corps d'un heredoc est du texte.
- Mots : guillemets, `$'…'` sans antislash, `~` et antislashs développés ; un mot calculé (variable, `$( )`, glob)
  est inconnu, et l'inconnu est jugé comme main : refspec, dépôt ou option de push inconnus refusent.
- git : options globales `-C` (cumulatif), `-c`, `--git-dir` (et `=`), `--work-tree`, `--namespace` ;
  `push.default` (`nothing`, `matching`, `upstream` avec l'upstream de la branche) pour un push sans refspec ;
  `-o`/`--push-option`/`--repo` et leur valeur, `-o` collé, `--`, refspecs `+`, `src:dst`, `:dst`, `@`, `HEAD`,
  `refs/heads/main`, `heads/main`, `:` et globs ; `--all`/`--branches`/`--mirror`, `--delete`, `--tags`.
- Préfixes : `env` (affectations), `sudo`, `command`, `builtin`, `nice`, `nohup`, `rtk`, `time`, `timeout`, `VAR=x` ;
  `command cd` et `builtin cd` changent le dossier du shell, `env cd` non ;
  `bash -c '…'` d'un script littéral est reparsé et jugé en sous-shell.
- Repli : sans shfmt, quand shfmt ne lit pas l'appel ou quand le hook plante (code non nul, que Claude Code laisse
  passer), tout appel qui cite `git` et `push` est refusé.
  `claude-config install` installe shfmt (brew, sinon binaire `v3.14.1` de la release GitHub dans `~/.local/bin`) ;
  il exige shfmt 3.14 ou plus, qui écrit `BinaryCmd.Op` en texte (`"&&"`) ; avec une version plus ancienne, tout appel qui cite `git` et `push` est refusé.
- Plafonds : 2000 processus (git, shfmt, jq) ; 64 états possibles en un point de l'appel (au-delà, un appel qui
  cite `git` et `push` est refusé : 400 `cd …;` prenaient 89 s, au-delà des 60 s du hook) ; budget de 40 s pour
  tout le jugement, même refus (3000 `cd …;` sur 60 dossiers prenaient 86 s sous le plafond d'états).

Décisions qui changent (faux refus acceptés, l'état réel n'est connu qu'à l'exécution) :

| Appel | Avant | Après | Raison |
|---|---|---|---|
| `x=$(cd ../wt) && git push` depuis main | permis | refusé | `$( )` est un sous-shell |
| `true \| cd ../wt && git push` depuis main | permis | refusé | élément de pipeline en sous-shell |
| `env cd ../wt && git push` depuis main | permis | refusé | `env cd` est un programme externe |
| anciens `shortcut:` (heredoc, `$'…'`, `case`, `{ }`…) | selon la lecture | jugés | arbre de shfmt |

Limites restantes, en `shortcut:` en tête du hook (sœurs regroupées) et montrées par
`test_guard_ast_shows_shortcuts` :

- commande lancée non jugée : alias et fonctions shell, `eval`, `bash -c` d'une variable ou avec `-o`, script lu dans
  un fichier, un pipe ou un heredoc, `xargs`, `find -exec`, `exec`, `trap`, `watch` ;
- non reconnus, le push peut passer : alias git (`!…` compris), options abrégées (`--mir`, `--cr`), options globales
  de git hors de la liste ci-dessus (`--config-env`…), `env -C/-u/-S`, `sudo -D`, `GIT_DIR` posé par `export` ou `declare` (seul
  `GIT_DIR=…` devant l'appel est lu) ;
- non suivis : `remote.*.push`, `branch -m`, second tour d'une boucle, `! cd … &&` lu comme un cd ;
- refus de trop : `"$X"` et `$(git branch --show-current)` inconnus, `checkout -- <fichier>` (branche inconnue),
  `pushd -n`, `git -C ""`, `command -v`, switch dans un second dépôt ou dans un dépôt inconnu (un état ne retient la
  branche prise que d'un dépôt connu : sinon la branche devient inconnue partout).

Réduction : une première version lisait aussi ces cas et faisait 467 lignes ; le hook réduit en fait environ 300,
programme jq compris. Chaque limite se lève quand un cas réel la rencontre.

Critères révisés : le critère « sous 200 lignes » du §4 tombe (environ 300 lignes, programme jq compris) ; latence
sous 1 s pour un appel de 70 Ko (heredoc) ; chaque règle gardée tuée par mutation.

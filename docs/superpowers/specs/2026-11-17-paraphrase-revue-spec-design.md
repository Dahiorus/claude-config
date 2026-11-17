# Paraphrase en tête de `ddd revue spec`

## But

La revue `ddd` d'une spec vérifie aujourd'hui les termes, les règles et les parcours un par un. Elle ne voit pas une
spec dont chaque terme est défini mais dont les parties ne s'enchaînent pas. Avant de dérouler les parcours, la
revue réécrit donc en quelques phrases ce que la spec propose et comment marche l'existant selon elle, à partir de
la spec seule. L'auteur de la spec compare ce texte à son intention avant d'ouvrir Plannotator : un écart montre le
passage qui égare le lecteur.

## 1. Demande initiale

`/feature paraphrase en tête de ddd revue spec`, qui reprend le point 1 des Features de `docs/reste-a-faire.md` :

> **Paraphrase en tête de `ddd revue spec`** (repris d'EGM, `agents/comprehension.md` de
> google/elephant-goldfish-model) : le relecteur réécrit d'abord en 2 à 5 phrases « ce que la spec propose » et
> « comment marche l'existant selon elle ». Une paraphrase fausse est un défaut. Elle repère une spec dont chaque
> terme est défini mais dont les parties ne s'enchaînent pas. L'auteur la compare à son intention avant Plannotator.

## Règles

**R1 — La revue `ddd` d'une spec commence par une paraphrase.** Dans `ddd revue spec`, avant de dérouler les
parcours, la revue écrit deux parties :
- **Ce que la spec propose** : le changement, pour qui, et pourquoi ;
- **L'existant selon la spec** : comment marche aujourd'hui ce que la spec change, tel que la spec le décrit (le
  but de la spec, et ce que deviennent les endroits de sa « Portée », regroupés par comportement). Si la spec n'en
  dit rien, la revue l'écrit : « la spec ne décrit pas l'existant ».

Chaque partie tient en 2 à 5 phrases, avec les mots du glossaire.

**R2 — La paraphrase s'écrit à partir du § « But », des règles et de la Portée de la spec, et du glossaire, avant
de lire le code.** Le § « But » donne le pourquoi que demande R1. Une spec sans § « But » (le gabarit de `feature` ne
l'impose pas) donne le pourquoi par ses règles ; si elles ne le disent pas, c'est un écart « à trancher ». Elle ne
reprend pas le § « Demande initiale » : l'auteur la compare ensuite à ce § (R5), et une paraphrase qui le
recopierait concorderait toujours. Sans lire le code d'abord : sinon la revue comble les trous de la spec avec ce
qu'elle sait du code, et ne les voit plus. Un passage que la revue ne parvient pas à enchaîner au reste (deux
parties qui ne se relient pas, une étape manquante entre deux règles) devient un écart, trié comme les autres : « à
corriger » si une seule réécriture s'impose, « à trancher » sinon. (Décision prise dans Plannotator, à la relecture
du plan.)

**R3 — La paraphrase ouvre le rapport, toujours.** Elle précède « À corriger », « À trancher » et « Écarté », même
quand la revue n'a rien d'autre à signaler.

**R4 — L'existant paraphrasé est ensuite vérifié dans le code.** Comme tout point de la revue : une description de
l'existant que le code contredit est un écart, trié « à corriger » ou « à trancher ».

**R5 — `feature` compare la paraphrase avant Plannotator.** À la validation fonctionnelle de la spec, l'auteur
compare la paraphrase au § « Demande initiale » et à son intention :
- elle correspond : rien à faire ;
- elle s'en écarte à cause d'une formulation : le passage de la spec qui a égaré la revue se réécrit avant
  l'ouverture, comme un « à corriger » ;
- l'écart révèle un comportement que la spec n'a pas tranché : un bloc `:::question` à l'endroit qu'il touche.

La revue n'est pas relancée après cette réécriture, comme après un « à corriger ».

La paraphrase ne passe pas dans Plannotator : l'auteur la compare seul, ancré sur la demande initiale pour limiter
l'indulgence envers sa propre spec. L'utilisateur ne la voit qu'à travers un éventuel `:::question` (décision prise
dans Plannotator).

**R6 — Pas de paraphrase pour `ddd revue plan`.** La demande ne vise que la spec ; le plan est relu contre une spec
déjà approuvée.

## 2. Portée

- `global/skills/ddd/SKILL.md`, § `revue <spec|plan>` (l. 56-76) : reçoit R1 à R4 et R6. La phrase « Rien à
  signaler : le dire en une ligne » devient : la paraphrase (pour une spec), puis « rien à signaler » en une ligne.
- `global/skills/ddd/SKILL.md`, en-tête (l. 11-13) : inchangé, il annonce déjà que `revue` vérifie que la spec
  répond au besoin.
- `global/skills/feature/SKILL.md`, § « Validation fonctionnelle » (l. 131-134) : reçoit R5.
- `global/skills/feature/SKILL.md`, étape 1 du cycle (l. 20) : inchangé, elle renvoie à la validation fonctionnelle
  sans la détailler.
- `global/skills/feature/SKILL.md`, « Excuses et réalité » (l. 282) : inchangé, « `ddd revue` la déroule parcours par
  parcours » reste vrai, la paraphrase s'y ajoute en tête.
- `global/skills/bugfix/SKILL.md` : inchangé, `bugfix` n'appelle pas `ddd revue` (`git grep -n ddd
  global/skills/bugfix` est vide).
- `docs/domaine.md` : inchangé, aucun contexte ne couvre la conception de feature ; « paraphrase » est défini dans le
  skill `ddd`.
- `docs/reste-a-faire.md`, Features point 1 : rayé avec la PR.

Rien n'est retiré de ce que la revue lisait : elle lit la spec une fois de plus, en tête, et le code comme avant.

## 3. Données existantes

Sans objet : aucune donnée. Les specs déjà approuvées ne sont pas repassées à la revue.

## 4. Critères d'acceptation

Une seule story, **P1 — la revue d'une spec rend une paraphrase que `feature` compare**.

- Nominal : `ddd revue spec <spec>` rend en tête « Ce que la spec propose » et « L'existant selon la spec », 2 à 5
  phrases chacune, puis les écarts triés.
- Rien à signaler : le rapport contient la paraphrase, puis « rien à signaler » en une ligne.
- Plan : `ddd revue plan <plan> <spec>` ne rend pas de paraphrase.
- Spec mal enchaînée : un passage que la revue ne relie pas au reste apparaît dans « À corriger » ou « À trancher ».
- Combiné : la paraphrase de l'existant reprend la spec et le code la contredit → la paraphrase reste telle que la
  spec la fait comprendre, et l'écart avec le code figure dans les écarts triés.
- `feature` : la paraphrase s'écarte de l'intention → le passage est réécrit ou devient un `:::question` avant la
  première ouverture dans Plannotator, sans relancer la revue.
- Sources : la paraphrase est écrite avant la lecture du code et ne reprend pas le § « Demande initiale ».
- Hors Plannotator : la paraphrase n'est pas ouverte dans Plannotator ; seul un éventuel `:::question` y apparaît.

Le dépôt n'a pas de test automatique du comportement des skills : chaque critère se vérifie à la lecture du texte des
skills, et le premier par une revue `ddd` lancée sur cette spec.

## 5. Filet sur l'existant

Aucun test de caractérisation : les fichiers touchés sont du texte de skill, sans test automatisé. `bash tests/run.sh`
reste vert (shellcheck et tests des scripts, non touchés).

## 6. Origine

Point 1 des Features de `docs/reste-a-faire.md`, idée reprise d'EGM (`agents/comprehension.md` de
google/elephant-goldfish-model). Ni régression ni défaut : une amélioration.

Hors périmètre, déjà au reste à faire : relecteur YAGNI sur la spec (Features 2), relecteur en échec « non lancé »
(Features 3).

## 7. Dette du code touché

Le § `revue` de `ddd` et le § « Validation fonctionnelle » de `feature` sont du texte : la grille de code ne
s'applique pas. Contrôles de texte : lignes de 120 colonnes au plus, mêmes mots dans `ddd` et `feature` (paraphrase,
« Ce que la spec propose », « L'existant selon la spec »).

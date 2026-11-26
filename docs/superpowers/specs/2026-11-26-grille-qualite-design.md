# Grille qualité dans son propre fichier

## But

La **grille qualité** (principes SOLID, KISS, DRY, object calisthenics, règles du texte, liste « Ne pas signaler »,
forme de la sortie) est aujourd'hui le § « Grille qualité » de `global/skills/feature/SKILL.md` (l. 266-355, 90
lignes sur 391). `bugfix`, `pr` et quatre agents la lisent pourtant aussi, en chargeant tout `feature` pour un seul §.
La grille passe dans un fichier à elle, que chaque lecteur cite par son chemin. Termes du glossaire : **grille**,
**grille qualité** (`docs/domaine.md`, contexte « Relecture de PR »).

## 1. Demande initiale

> sortir les régles des objets calisthenics et bonnes pratiques dans un fichier à part entière

« objets calisthenics » désigne les neuf points *object calisthenics* ; « bonnes pratiques » (mot de la colonne « À
ne pas dire » du glossaire) désigne le reste du § : SOLID, KISS, DRY et les règles du texte. La spec sort donc le §
entier : couper entre calisthenics et texte ferait deux grilles, et « Ne pas signaler » renvoie au point 7.

## Approches

La grille sert à `feature`, `bugfix`, `pr` et aux agents `sdd-implementer`, `sdd-final-reviewer`, `pr-reviewer`,
`lessons-extractor`. `lib/links.sh` lie chaque fichier de `global/` (hors `skills/` et `agents/`) dans `~/.claude/`,
et chaque dossier `global/skills/*` en entier. Les skills et agents de `~/.claude` pointent vers le dépôt principal,
branche extraite : dès le commit qui change les lecteurs, toutes les sessions de tous les projets lisent le nouveau
chemin.

- **A, retenue (décision de l'utilisateur dans Plannotator)** : `global/grille-qualite.md`, lu en
  `~/.claude/grille-qualite.md`, partagé, hors d'un skill. Le lien n'existe qu'après `bin/claude-config install` :
  le plan le lance depuis le dépôt principal dès la tâche qui crée le fichier, avant celle qui change les lecteurs,
  puis de nouveau après le merge (`CLAUDE.md`, « Installation »). Si le dépôt principal revient sur `main` avant le
  merge, le lien pend, sans effet : les lecteurs de `main` citent encore `feature`.
- B, écartée : `global/skills/feature/grille-qualite.md`. Rien à installer, mais la grille resterait rangée sous
  `feature` alors que d'autres skills la lisent.

Dans la suite, `<chemin>` vaut `~/.claude/grille-qualite.md`.

Écartée : copier la grille dans chaque lecteur. Les copies dérivent, c'est la règle « citer par son chemin, jamais par
une copie abrégée » de la grille elle-même.

## Règles

**R1 — Le fichier de la grille porte tout l'ancien §.** Contenu repris à l'identique, de « But : du code qu'un humain
relit sans effort » à « ; ou « conforme ». », sous un titre `# Grille qualité` suivi d'une ligne d'usage : « Lue au
plan, à l'implémentation et en review (`feature`, `bugfix`, `pr`), faute de grille du projet. » Seul change le renvoi
interne qui ne tient plus hors de `feature` : point 5, « amendée par le contrôleur comme tout écart, étape 4 »
devient « …, `feature` étape 4 ». Les renvois « point 7 » et « 3, 4, 5, 8 et 9 » restent valides (bloc déplacé entier).
Les 5 lignes du bloc qui dépassent 120 colonnes (l. 292, 296, 310, 318, 331) sont repliées, sans changer un mot :
dans un fichier neuf, `test_branch_respects_rules` les compte comme ajoutées.

**R2 — `feature/SKILL.md` garde un § « Grille qualité » de renvoi.** Le titre reste, pour que les citations
anciennes (plans et specs de `docs/superpowers/`, `AGENTS.md` d'autres projets) tombent sur une ligne qui donne le
chemin du fichier. Corps : « Grille du projet (WORKFLOW.md, ou un AGENTS.md qui en tient une complète) si elle
existe, sinon `<chemin>`, adaptée au langage et amendée par les conventions de l'`AGENTS.md` du projet. »

**R3 — Chaque lecteur cite le fichier par son chemin.** « section « Grille qualité » de
`~/.claude/skills/feature/SKILL.md` », « grille de `feature` », « grille qualité de `feature` » et « grille qualité
du skill `feature` » deviennent « grille qualité (`<chemin>`) » ou, quand la phrase cite déjà le chemin, le chemin
seul. Dans une parenthèse ou devant une autre parenthèse (`bugfix` l. 36, `lessons-extractor` l. 35, `docs/domaine.md`
l. 37), la forme est « grille qualité `<chemin>` », sans parenthèses. Liste fermée en § 2.

## 2. Portée

Établie par `git grep -n -i -e "grille de \`feature\`" -e "grille qualité de \`feature\`" -e "grille qualité du
skill" -e "« Grille qualité »" -e "grille qualité (ci-dessous)" -- . ':!docs/superpowers'`.

| Endroit | Devient |
|---|---|
| `global/skills/feature/SKILL.md` l. 22 (ét. 2) « respecte la grille qualité (ci-dessous) » | « (`<chemin>`) » |
| `global/skills/feature/SKILL.md` l. 24 (ét. 4) « section « Grille qualité » de `~/.claude/skills/feature/SKILL.md` » | `<chemin>` |
| `global/skills/feature/SKILL.md` l. 28 (ét. 7), l. 96 (§ 7 de spec), l. 215 (review finale) « la grille qualité » | inchangé : le terme reste juste, le chemin est au § de renvoi |
| `global/skills/feature/SKILL.md` l. 266-355, § « Grille qualité » | R2 : renvoi d'une phrase |
| `global/skills/bugfix/SKILL.md` l. 36 « grille qualité du skill `feature` » | « grille qualité (`<chemin>`) » |
| `global/skills/pr/SKILL.md` l. 28 « `feature` reste la référence pour le tri des retours et la grille qualité » | « …pour le tri des retours ; la grille qualité est `<chemin>` » |
| `global/skills/pr/review.md` l. 41 | `<chemin>` |
| `global/skills/pr/merge.md` l. 19 « la grille qualité de `feature` » | « la grille qualité (`<chemin>`) » |
| `global/skills/pr/merge.md` l. 21-22 « Une règle pour un skill global (grille de `feature`, skills `pr`…) » | « Une règle globale (grille qualité, skills `pr`…) », terme « Règle globale » du glossaire |
| `global/skills/pr/push.md` l. 42 « la liste « Ne pas signaler » de la grille » | inchangé : la liste suit la grille dans le fichier |
| `global/agents/sdd-implementer.md` l. 15, `sdd-final-reviewer.md` l. 42, `pr-reviewer.md` l. 32 | `<chemin>` |
| `global/agents/lessons-extractor.md` l. 35 (cibles), l. 94 (table) | `<chemin>` ; R1 rend la grille cible d'une règle « tous les projets » |
| `global/agents/frontend-reviewer.md` l. 10 « la grille qualité générale » | inchangé : ne cite pas d'emplacement |
| `CLAUDE.md` l. 60 « la grille de `feature` » | « la grille qualité » |
| `global/CLAUDE.md` l. 24-26, « Skills globaux » : protège `~/.claude/skills` seulement | la grille `<chemin>` aussi |
| `docs/domaine.md` l. 37, en-tête « Relecture de PR » : « grille qualité de `feature` (en aval, recopiée dans le brief faute de grille du projet) » | « grille qualité `<chemin>` (en aval, lue par l'agent faute de grille du projet) » : `pr/review.md` l. 40 dit « lue par l'agent » |
| `docs/domaine.md` l. 43 (Grille), l. 44 (Grille qualité, colonne « Dans le code »), l. 102, l. 117 | chemin du fichier au lieu de « de `feature` » / « § « Grille qualité » » ; la définition de l. 43 perd seulement « de `feature` », le chemin étant donné l. 44 |
| `docs/reste-a-faire.md` l. 96, point barré « la grille de `feature` ne fixe plus… » | inchangé : historique d'un point clos |
| `docs/superpowers/**` (specs et plans passés) | inchangé : historique ; R2 garde le titre qu'ils citent |
| `lib/links.sh` | inchangé : lie déjà tout fichier de `global/` |

Ce qui n'est plus lu : un lecteur qui chargeait `feature/SKILL.md` pour la grille ne lit plus le reste de `feature`
(cycle, fidélité, tri). Aucun ne s'en servait pour la grille : `sdd-final-reviewer` cite `feature` seulement pour la
relance (l. 77, « Exécution »), inchangé ; `pr/review.md` cite `feature` à part pour Angular, inchangé.

## 3. Données existantes

Plans, specs et `lecons.md` déjà écrits citent l'ancien §. R2 les fait tomber sur le renvoi. Briefs d'implémenteur
en cours (dossiers de suivi) : idem.

## 4. Critères d'acceptation

**P1 — La grille se lit dans son fichier, cité par chaque lecteur.** Une seule story.

- Le fichier de la grille existe et contient, dans l'ordre, SOLID/KISS/DRY, « Object calisthenics » points 1 à 9,
  l'alinéa « Script shell », « Texte », « Ne pas signaler » et la ligne de sortie.
- Diff de contenu : hors titre, ligne d'usage et renvoi de R1, le texte de la grille est identique à l'ancien §,
  mot pour mot (`diff` des deux textes, espaces et retours à la ligne ramenés à un espace).
- `feature/SKILL.md` n'a plus de règle de grille : le § « Grille qualité » tient en une phrase.
- Aucune citation de R3 ne reste (`git grep` du § 2, hors `docs/superpowers` et `docs/reste-a-faire.md`).
- Cas combiné : un lecteur qui citait à la fois `feature` pour autre chose et la grille (`sdd-final-reviewer` :
  relance + grille ; `pr/review.md` : Angular + grille) garde son renvoi à `feature` et lit la grille au nouveau
  chemin.
- `~/.claude/grille-qualite.md` est un lien vers le fichier du dépôt avant le commit qui change les
  lecteurs (`bin/claude-config status` ne le signale pas manquant).

## 5. Filet sur l'existant

Rien à caractériser : aucun test ne lit la grille ni le titre « Grille qualité ». Garde ajoutée dans
`tests/test_skills.sh` : aucune citation de R3 sous `global/`, `CLAUDE.md` et `docs/domaine.md`, et le fichier de la
grille existe. Elle échoue si l'on remet une seule des anciennes citations.

## 6. Origine

Demande de l'utilisateur, aucun point du reste à faire.

## 7. Dette du code touché

`global/skills/feature/SKILL.md` : 391 lignes, il en perd environ 88. Texte, pas de seuil de taille dans la grille :
rien à décider.

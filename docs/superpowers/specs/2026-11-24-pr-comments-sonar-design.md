# Issues Sonar dans `/pr comments`

## But

`/pr comments` trie et corrige ce que les relecteurs écrivent sur une PR, mais ignore SonarQube : son seul commentaire
est le résumé de `sonarqubecloud[bot]`, exclu comme tout auteur de type `Bot`, et les issues elles-mêmes ne sont pas
sur GitHub. La feature fait de chaque issue Sonar ouverte un retour, trié et corrigé comme les autres. Termes du
glossaire : **analyse Sonar**, **issue Sonar**, **retour** (`docs/domaine.md`, contexte « Retours de PR »).

## 1. Demande initiale

`/feature` :

> apporte une évolution à l'action /pr comments pour prendre aussi en compte les code smells de SonarQube (notamment
> sur le projet renoshield), ces code smells se présentent sous forme de commentaires

Constat rejoué sur renoshield, PR 318 (24/11/2026) :
- conversation : un commentaire de `sonarqubecloud[bot]` (type `Bot`), « Quality Gate passed », « 3 New issues »,
  lien `sonarcloud.io/project/issues?id=softwarevidal_renoshield&pullRequest=318` ; aucun fil ni review de Sonar ;
- check run du dernier commit : `SonarCloud Code Analysis`, app `sonarqubecloud`, `status` `completed`,
  `details_url` `https://sonarcloud.io/dashboard?id=softwarevidal_renoshield&pullRequest=318`
  (`gh api repos/<o/r>/commits/<sha>/check-runs`) ;
- MCP sonarqube, `search_sonar_issues_in_projects` (`projectKeys` `softwarevidal_renoshield`, `pullRequest` `318`,
  `issueStatuses` `OPEN`, `CONFIRMED`) : 3 issues, chacune avec `key`, `rule`, `component`
  (`<clé>:<chemin>`), `textRange.startLine`, `severity`, `message` ; aucun champ de type (code smell, bug,
  vulnérabilité), `author` vide ;
- le dépôt renoshield n'a ni `.sonarlint/connectedMode.json` ni `sonar.projectKey` : la clé ne se lit que dans le
  lien de l'analyse ;
- le plugin `sonarqube` n'est actif que dans le profil `vidal` (`global/profiles.json`).

## Règles

**R1 — Lecture.** À l'étape 1 de `comments.md`, une troisième source s'ajoute aux fils et aux retours hors fil :
les **issues Sonar**. Le check run `SonarCloud Code Analysis` (app `sonarqubecloud`) du dernier commit de la PR
(`headRefOid` de `gh pr view <n°> --json headRefOid` ;
`gh api 'repos/<o/r>/commits/<headRefOid>/check-runs?check_name=SonarCloud%20Code%20Analysis'`, filtré par nom
car l'API rend 30 check runs par page) donne la clé du projet et le n° de PR (`id=` et
`pullRequest=` de son `details_url`). Puis `search_sonar_issues_in_projects` avec cette clé, ce n° et les statuts
`OPEN`, `CONFIRMED`, toutes sévérités, `pageSize` 500 (100 par défaut lirait une partie sans le dire).

Toutes les issues ouvertes sont lues, sans filtre `impactSoftwareQualities` : code smells, bugs et vulnérabilités,
ce que compte le résumé « N New issues » (réponse dans Plannotator). Les security hotspots passent par une autre API
et restent hors périmètre.

Les issues Sonar ne se lisent que sur sa propre PR : sur celle d'un autre, son auteur les traite, et les lire ferait
corriger et pousser sur sa branche et changer des statuts dans le projet Sonar (review, R1 de `code-review`, tranché
le 2026-11-24). Rien n'est lu, sans mention.

Pas de check run Sonar sur le dernier commit : un commentaire de `sonarqubecloud[bot]` dans la conversation (déjà
lue avec les retours hors fil) → issues non lues, le rapport dit « aucune analyse Sonar sur <sha7> » (en analyse CI,
le check run n'apparaît qu'en fin de scan) ; sinon → rien n'est lu, sans mention (dépôt ou PR non analysés ; la
première analyse d'une PR, avant le commentaire du bot, reste muette). Sonar n'attache un check run qu'au HEAD de
chaque push : l'avant-dernier commit d'un push groupé, d'un rebase ou d'un squash n'en a jamais (review, tranché le
2026-11-24). Check run pas encore `completed` → issues non lues, le rapport dit « analyse Sonar en cours sur <sha7> » :
les issues d'un commit plus ancien seraient périmées. `completed` avec une `conclusion` autre que `success`,
`failure` ou `neutral` (`cancelled`, `skipped`, `timed_out`…) → issues non lues, « analyse Sonar non aboutie sur
<sha7> ». `gh api` en erreur, MCP sonarqube absent (profil `perso`, plugin désactivé) ou en erreur → le rapport dit
« issues Sonar non lues : <cause> », les autres retours sont traités. Aucun retour et issues non lues → « aucun
retour en attente », suivi de la mention Sonar. (Les trois derniers cas ajoutés à la review, tranchés le
2026-11-24.)

**R2 — Rattachement.** Une issue est un retour rattaché à `component` sans le préfixe `<clé>:` et à
`textRange.startLine` ; sans `textRange` (règle sur le fichier entier), au fichier seul. Son texte est
`<rule> (<severity>) : <message>`. La consigne « de alice » exclut les issues
Sonar : elles n'ont pas d'auteur relecteur. Les issues comptent dans le seuil de plus de 3 retours qui fait passer le
tri par `feedback-triager` ; l'agent reçoit pour chacune sa `key`, son rattachement et son texte.

**R3 — Tri et suite.** Tri de `feature` (« Tri des retours »), sans critère propre. La sévérité `BLOCKER` de Sonar
n'est pas le `**[bloquant]**` de `/pr review` : elle ne déclenche ni la boucle de l'étape 6 ni une relecture
redemandée.
- **À corriger** : corrigé, vérifié, poussé avec les autres correctifs. Aucune réponse sur la PR ni dans Sonar :
  l'analyse du commit poussé ferme l'issue.
- **Écarté** : un changement de statut est proposé, comme la réponse d'un fil non corrigé, et appliqué après accord
  par `change_sonar_issue_status` (`key`, `status`, `comment` = la raison de l'écart passée par
  `humanizer:humanizer`) : `falsepositive` quand la règle se trompe sur ce code, `accept` quand l'écart est voulu
  (imposé par le framework, hors règle du projet). Sans accord, rien n'est écrit dans Sonar et l'issue revient au
  `/pr comments` suivant. Échec de l'appel → le rapport cite l'erreur pour cette issue, les autres continuent.
  (Réponse dans Plannotator ; le contrôle YAGNI recommandait de ne rien écrire.)

- **À trancher** : options et recommandation, rien n'est corrigé avant l'accord, comme les autres retours.

**R4 — Rapport.** `final-review.md` et le rapport comptent les issues avec les autres retours, chacune avec sa `key`,
sa règle et son rattachement, le SHA du correctif ou la raison de l'écart, et le cas échéant la mention Sonar de R1
(« aucune analyse Sonar sur <sha7> », « analyse Sonar en cours sur <sha7> », « analyse Sonar non aboutie sur
<sha7> » ou « issues Sonar non lues : <cause> »).

**R5 — Boucle (étape 6).** Inchangée : le `comments` relancé ne traite que les remarques de la review du tour, les
issues Sonar ne se relisent qu'à la prochaine invocation de `/pr comments`.

## 2. Portée

| Endroit | Ce qu'il devient |
|---|---|
| `global/skills/pr/comments.md`, étape 1 | Puce « Issues Sonar » : R1, R2 (rattachement, filtre « de alice ») ; « Aucun retour » compte aussi les issues |
| `global/skills/pr/comments.md`, étape 2 | Les issues entrent dans le seuil de 3 et dans le brief de `feedback-triager` (R2) |
| `global/skills/pr/comments.md`, étape 4 | Issue corrigée : pas de réponse ; issue écartée : statut `falsepositive` ou `accept` proposé, appliqué après accord ; `BLOCKER` n'est pas `**[bloquant]**` (R3) |
| `global/skills/pr/comments.md`, étape 5 | Rapport et `final-review.md` (R4) |
| `global/skills/pr/comments.md`, étape 6 | Inchangée (R5) |
| `global/skills/pr/comments.md`, exclusion « auteur de type `Bot` » (hors fil) | Inchangée : le résumé reste exclu, les issues viennent du MCP, pas du commentaire |
| `global/agents/feedback-triager.md`, mode `retours` | Entrée : une issue Sonar arrive avec `key`, `path`, `line`, texte ; critères inchangés |
| `global/skills/pr/SKILL.md`, ligne d'aide de `comments` | « traite les fils, commentaires et issues Sonar en attente… » |
| `docs/domaine.md`, contexte « Retours de PR » | Termes « Analyse Sonar », « Issue Sonar », « Retour » élargi, invariant (ajoutés par l'analyse `ddd`) ; « Dépend de » cite SonarQube Cloud (MCP) |
| `global/skills/pr/review.md`, étape 0 (remarques déjà faites) | Inchangée : les fils et reviews seuls y comptent |
| `global/skills/pr/review.md`, étape 1 (brief de `pr-reviewer`) | Puce « Issues Sonar » : l'agent ne les lit ni ne les cite ; `comments` s'en charge, sinon elles comptent deux fois (recette, renoshield PR 324, 2026-11-25) |
| `global/statusline-gh.sh` (compteur de fils en attente) | Inchangé : il lit les fils GitHub, une issue Sonar n'en est pas un |
| `global/skills/pr/merge.md` (reliquats) | Inchangé : il lit le reste à faire, pas les retours de PR |

## 3. Données existantes

Sans objet : `final-review.md` déjà écrits ne sont pas repris ; une PR traitée avant la feature verra ses issues Sonar
au prochain `/pr comments`.

## 4. Critères d'acceptation

Story unique (P1) : `/pr comments` sur une PR analysée par Sonar trie ses issues ouvertes avec les autres retours.

- Nominal : renoshield PR 318, aucun fil en attente, 3 issues Sonar → 3 retours rattachés
  (`current-version-pane.component.html:10`, `gpr-record-detail.component.ts:369`,
  `gpr-record.service.spec.ts:106`), triés ; le ternaire imbriqué (S3358) corrigé et poussé, sans réponse publiée.
- Seuil : 2 fils + 2 issues → 4 retours, tri par `feedback-triager`.
- Analyse en cours : check run Sonar `in_progress` sur le dernier commit → issues non lues, rapport « analyse
  Sonar en cours sur <sha7> », les fils sont traités.
- Sans Sonar : dépôt sans check run Sonar → aucune mention de Sonar dans le rapport.
- MCP absent : session en profil `perso` sur un dépôt analysé → « issues Sonar non lues : MCP sonarqube absent »,
  les fils sont traités.
- Filtre : `/pr 318 comments de alice` → aucune issue Sonar.
- PR d'un autre : `/pr <n°> comments` sur la PR d'un collègue, avec des issues Sonar → aucune issue lue, aucune
  mention de Sonar.
- Analyse pas encore publiée : pas de check run sur le dernier commit, un commentaire de `sonarqubecloud[bot]` →
  « aucune analyse Sonar sur <sha7> » ; PR sans ce commentaire ni check run → aucune mention.
- Analyse non aboutie : check run `completed`, `conclusion` `cancelled` → « analyse Sonar non aboutie sur <sha7> ».
- Erreur `gh api` sur les check runs → « issues Sonar non lues : <erreur> », les fils sont traités.
- Combiné : une issue `BLOCKER` corrigée sur sa propre PR, sans remarque `**[bloquant]**` de la review → pas de
  deuxième tour de boucle, pas de relecture redemandée pour elle.
- Écarté : issue S6819 (`role="group"`) jugée voulue → rapport « proposé : `accept`, <raison> » ; rien n'est
  écrit dans Sonar avant l'accord ; après accord, l'issue passe `ACCEPTED` avec la raison en commentaire.
- Combiné : une issue écartée sans accord et un fil corrigé → le fil reçoit sa réponse, l'issue reste ouverte et
  revient au `/pr comments` suivant avec la même proposition.
- Pas de doublon : `/pr review comments` sur sa propre PR analysée par Sonar → la review ne cite aucune issue
  Sonar, chaque issue n'est un retour qu'une fois, dans `comments`.
- Aucun retour : aucun fil, aucun hors fil, 0 issue → « aucun retour en attente ».
- Combiné : aucun fil, aucun hors fil, analyse Sonar en cours → « aucun retour en attente » puis « analyse Sonar en
  cours sur <sha7> ».

## 5. Filet sur l'existant

Sans objet : texte de skill, pas de code. Recette (étape 6 de `feature`) : un agent neuf exécute `/pr comments` à
blanc (lecture et tri, sans push ni publication) sur renoshield PR 318, et rend les retours lus avec leur
rattachement.

## 6. Origine

- Point traité : demande nouvelle, *défaut ancien* (les issues Sonar n'ont jamais été lues par `/pr comments`).
- Hors périmètre : security hotspots ; SonarQube Server (autre que Cloud) ; compteur de la statusline.

## 7. Dette du code touché

`comments.md` a des lignes de plus de 120 colonnes (étapes 1 et 2) : elles ne se réécrivent pas, la prose s'ajoute
sur ses propres lignes (CLAUDE.md du projet). Aucune autre dette.

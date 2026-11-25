# Issues Sonar dans `/pr comments` : plan d'implémentation

> **Pour les agents :** sous-skill requis : `superpowers:subagent-driven-development`. Étapes en cases à cocher.

**But :** `/pr comments` lit les issues Sonar ouvertes de la PR et les trie comme les autres retours.

**Architecture :** trois textes changent. `global/skills/pr/comments.md` gagne la lecture (étape 1), le seuil
(étape 2), la suite d'une issue corrigée ou écartée (étape 4) et le rapport (étape 5). `feedback-triager.md` décrit
l'entrée « issue Sonar », et la ligne d'aide de `SKILL.md` la cite. Aucun script : la lecture passe par `gh api` et
le MCP `sonarqube`.

**Pile :** Markdown lu par des agents ; `tests/run.sh` (shellcheck, 120 colonnes de prose).

**Spec :** `docs/superpowers/specs/2026-11-24-pr-comments-sonar-design.md`

## Découpage en PR

Une seule PR : 3 fichiers touchés hors tests, spec et plan (`docs/domaine.md` est commité avec la spec, a21302c).

## Contraintes globales

- Texte français, édité par Edit, jamais `sed -i` ni `printf` ; prose ajoutée ≤ 120 colonnes
  (`test_branch_respects_rules`) ; une ligne existante plus longue ne se réécrit pas, on écrit dessous.
- Termes du glossaire (`docs/domaine.md`, « Retours de PR ») : « issue Sonar », « analyse Sonar » ; jamais
  « commentaire Sonar », ni « code smell » pour l'ensemble des issues.
- Valeurs de la spec, à recopier telles quelles : check run `SonarCloud Code Analysis`, app `sonarqubecloud`,
  statuts `OPEN`, `CONFIRMED`, `pageSize` 500, statuts Sonar `falsepositive` et `accept`.
- Commits : `Co-Authored-By: <modèle de l'implémenteur>`, remplacé par le modèle réel.

## Review Focus

- Une issue sans `textRange` (règle sur le fichier entier) : rattachée au fichier seul ; Task 1, grep `sans
  \`textRange\``.
- PR à plus de 100 issues : `pageSize` 500, sinon lecture partielle muette ; Task 1, grep `` `pageSize` 500 ``.
- Aucun fil ni hors fil, analyse en cours : la mention Sonar survit au « aucun retour en attente » ; Task 1, grep
  `suivi de la mention Sonar`.
- `BLOCKER` pris pour `**[bloquant]**` relancerait la boucle et redemanderait une relecture ; Task 1, grep
  `` `BLOCKER` n'est pas ``.
- Statut écrit dans Sonar sans accord : Task 1, grep `appliqué après accord par` ; recette.

## Traçabilité

| Exigence (§ spec) | Tâche | Preuve |
|---|---|---|
| R1 : check run du dernier commit, clé et n° depuis `details_url` | 1 | grep `` `SonarCloud Code Analysis` (app `sonarqubecloud`) `` ; recette PR 318 |
| R1 : recherche MCP, `OPEN`/`CONFIRMED`, `pageSize` 500, sans filtre de type | 1 | grep `` `pageSize` 500), toutes sévérités et tous types `` |
| R1 : pas de check run → rien ; en cours → mention ; MCP absent → mention | 1 | grep `Pas de check run Sonar`, `analyse Sonar en cours sur`, `issues Sonar non lues :` |
| R1 : aucun retour et issues non lues → mention après « aucun retour en attente » | 1 | grep `suivi de la mention Sonar` |
| R2 : rattachement `component` sans préfixe, `startLine`, fichier seul sans `textRange`, texte | 1 | grep `` sans le préfixe `<clé>:` ``, `` sans `textRange` `` |
| R2 : « de alice » exclut les issues | 1 | grep `une consigne « de alice » les exclut` |
| R2 : seuil de 3 et entrée de `feedback-triager` | 1, 2 | grep `Les issues Sonar comptent dans ce seuil` ; grep `issue Sonar` dans `feedback-triager.md` |
| R3 : corrigée → aucune réponse, l'analyse la ferme | 1 | grep `l'analyse du commit poussé la ferme` |
| R3 : écartée → statut proposé, humanizer, appliqué après accord, échec cité | 1 | grep `appliqué après accord par`, `un échec est cité` ; recette |
| R3 : `BLOCKER` ≠ `**[bloquant]**` | 1 | grep `` `BLOCKER` n'est pas `` |
| R4 : rapport et `final-review.md` | 1 | grep `Les issues Sonar y figurent` |
| R1 (review, T1) : issues Sonar sur sa propre PR seulement | review | grep `sur sa propre PR seulement` ; grep `n'est un retour que sur sa propre PR` dans `docs/domaine.md` |
| R1 (review, T2) : `conclusion` hors `success`/`failure`/`neutral`, erreur `gh api` | review | grep `analyse Sonar non aboutie sur`, `` `gh api`, MCP `sonarqube` absent `` |
| R1 (review, T3) : pas de check run, commentaire de `sonarqubecloud[bot]` → mention | review | grep `aucune analyse Sonar sur` |
| Pas de doublon review/comments (recette PR 324) : `pr-reviewer` ne lit pas Sonar | — | grep `Issues Sonar` dans `review.md` |
| R5 : boucle inchangée | — | étape 6 de `comments.md` inchangée dans le diff |
| § 2 : ligne d'aide de `SKILL.md` | 2 | grep `fils, commentaires et issues Sonar` |
| § 2 : `docs/domaine.md` | — (a21302c) | grep `Issue Sonar` dans `docs/domaine.md` |
| § 4, critères d'acceptation | 1, 2 | recette (étape 6) : agent neuf, `/pr comments` à blanc sur renoshield PR 318 |

Usages vérifiés à l'étape 1b, inchangés :

| Usage | Ce qu'il devient | Ce qui le fige |
|---|---|---|
| `comments.md` étape 1, exclusion « auteur de type `Bot` » (hors fil) | Inchangée : le résumé Sonar reste exclu, les issues viennent du MCP | ligne inchangée dans le diff |
| `review.md` l. 9-11 (« comme à l'étape 1 de `comments.md` ») | Inchangé : renvoie à la règle d'exclusion, pas à la nouvelle puce | idem |
| `comments.md` étape 6 (boucle) | Inchangée (R5) | idem |
| `merge.md` l. 9 (`feedback-triager` mode `reliquats`) | Inchangé : l'entrée ajoutée vaut pour le mode `retours` | idem |
| `global/statusline-gh.sh` | Inchangé : compte les fils GitHub | idem |

---

### Task 1 : Issues Sonar dans `comments.md`

§ spec : R1, R2, R3, R4.

**Fichiers :**
- Modifier : `global/skills/pr/comments.md`, étapes 1, 2, 4 et 5.

- [ ] **Étape 1 : rouge**

```bash
git grep -nF 'Sonar' -- global/skills/pr/comments.md
```

Attendu : aucune sortie, code 1.

- [ ] **Étape 2 : étape 1 — insérer, après la puce « Hors fil » (qui finit par « sinon il vaut pour toute la
  PR. ») et avant « Aucun retour → », la puce suivante, telle quelle**

```markdown
   - **Issues Sonar** (une consigne « de alice » les exclut : elles n'ont pas d'auteur relecteur) : check run
     `SonarCloud Code Analysis` (app `sonarqubecloud`) du dernier commit (`gh pr view <n°> --json headRefOid`) :
     `gh api 'repos/<o/r>/commits/<headRefOid>/check-runs?check_name=SonarCloud%20Code%20Analysis'` (sans ce
     filtre, 30 check runs par page cacheraient le sien), dont le `details_url` donne la clé du projet (`id=`) et
     le n° de PR (`pullRequest=`) ; puis MCP `search_sonar_issues_in_projects` (`projectKeys` cette clé,
     `pullRequest` ce n°, `issueStatuses` `OPEN`, `CONFIRMED`, `pageSize` 500), toutes sévérités et tous types.
     Chaque issue est un retour : sa `key`, rattachée à `component` sans le préfixe `<clé>:` et à
     `textRange.startLine` (sans `textRange`, au fichier seul), texte `<rule> (<severity>) : <message>`.
     Pas de check run Sonar → rien, sans mention. Check run pas `completed` → non lues, « analyse Sonar en cours
     sur <sha7> » (les issues d'un commit plus ancien seraient périmées). MCP `sonarqube` absent ou en erreur → non
     lues, « issues Sonar non lues : <cause> ».
```

Puis remplacer la ligne `   Aucun retour → « aucun retour en attente » et s'arrêter.` par :

```markdown
   Aucun retour → « aucun retour en attente », suivi de la mention Sonar s'il y en a une, et s'arrêter.
```

- [ ] **Étape 3 : étape 2 — insérer, juste avant la ligne `   Tri :`, la ligne suivante**

```markdown
   Les issues Sonar comptent dans ce seuil ; l'agent reçoit pour chacune sa `key`, l'origine « issue Sonar », son
   rattachement et son texte.
```

- [ ] **Étape 4 : étape 4 — insérer, juste après la ligne qui finit par « les cite, ils restent en attente. », le
  paragraphe suivant**

```markdown
   Issues Sonar : aucune réponse sur la PR. Corrigée → rien d'autre, l'analyse du commit poussé la ferme. Écartée →
   statut proposé, `falsepositive` (la règle se trompe sur ce code) ou `accept` (écart voulu : imposé par le
   framework, hors règle du projet), avec la raison passée par `humanizer:humanizer`, montré dans le rapport et
   appliqué après accord par `change_sonar_issue_status` (`key`, `status`, `comment` : la raison) ; sans accord,
   rien n'est écrit dans Sonar et l'issue revient au `/pr comments` suivant ; un échec est cité dans le rapport pour
   cette issue, les autres continuent. La sévérité `BLOCKER` n'est pas `**[bloquant]**` : elle ne fait ni redemander
   de relecture ni relancer la boucle (étape 6).
```

- [ ] **Étape 5 : étape 5 — insérer, à la fin de l'étape 5 (après la ligne « et « non redemandée à <logins>
  (approuvé, aucun bloquant répondu publié depuis) ». »), la ligne suivante**

```markdown
   Les issues Sonar y figurent avec leur `key`, leur règle, leur rattachement, le SHA du correctif ou le statut
   proposé et sa raison, et la mention « analyse Sonar en cours sur <sha7> » ou « issues Sonar non lues : <cause> »
   le cas échéant.
```

- [ ] **Étape 6 : vert**

```bash
for f in '`SonarCloud Code Analysis` (app `sonarqubecloud`)' '`pageSize` 500), toutes sévérités et tous types' \
  'Pas de check run Sonar' 'analyse Sonar en cours' 'issues Sonar non lues :' 'suivi de la mention Sonar' \
  'sans le préfixe `<clé>:`' 'sans `textRange`' 'une consigne « de alice » les exclut' \
  'Les issues Sonar comptent dans ce seuil' 'l'\''analyse du commit poussé la ferme' 'appliqué après accord par' \
  'un échec est cité' '`BLOCKER` n'\''est pas' 'Les issues Sonar y figurent'; do
  git grep -qF -e "$f" -- global/skills/pr/comments.md || echo "absent : $f"; done
git grep -nF -e 'commentaire Sonar' -e 'code smell' -- global/skills/pr/comments.md
```

Attendu : aucune sortie. Puis `bash tests/run.sh` (timeout 580000), lu par `grep -v '^PASS'` : aucun `FAIL`.

- [ ] **Étape 7 : commit**

```bash
git add global/skills/pr/comments.md
git commit -m "✨ pr: Issues Sonar triées par comments

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 2 : Entrée de `feedback-triager` et aide de `pr`

§ spec : R2, § 2.

**Fichiers :**
- Modifier : `global/agents/feedback-triager.md`, § « Entrée (dans le brief) », puce « Les points » (l. 16-17).
- Modifier : `global/skills/pr/SKILL.md`, ligne d'aide `comments` (l. 84).

**Interfaces :** consomme l'origine « issue Sonar » de la Task 1 (étape 3).

- [ ] **Étape 1 : rouge**

```bash
git grep -nF -e 'issue Sonar' -- global/agents/feedback-triager.md
git grep -nF -e 'issues Sonar' -- global/skills/pr/SKILL.md
```

Attendu : aucune sortie.

- [ ] **Étape 2 : `feedback-triager.md` — insérer, juste après la puce « Les points » (qui finit par « ou toute la
  PR). »), la puce suivante**

```markdown
- Une issue Sonar arrive avec sa `key` pour id, l'origine « issue Sonar », son rattachement (fichier, ligne) et son
  texte `<rule> (<severity>) : <message>`.
```

- [ ] **Étape 3 : `SKILL.md` — remplacer la ligne d'aide**

```text
  comments      traite les fils et commentaires en attente, corrige, pousse, répond, redemande la relecture
```

par :

```text
  comments      traite les fils, commentaires et issues Sonar en attente, corrige, pousse, répond, redemande la relecture
```

(Amendé à l'exécution : une seule ligne, 121 colonnes dans le bloc de code ; sur deux lignes, `pr/SKILL.md` passait
à 201 lignes, au-delà du plafond de `tests/test_skills.sh`.)

- [ ] **Étape 4 : vert**

```bash
git grep -qF -e 'Une issue Sonar arrive avec sa `key`' -- global/agents/feedback-triager.md || echo absent agent
git grep -qF -e 'fils, commentaires et issues Sonar' -- global/skills/pr/SKILL.md || echo absent aide
```

Attendu : aucune sortie. Puis `bash tests/run.sh` (timeout 580000), lu par `grep -v '^PASS'` : aucun `FAIL`.

- [ ] **Étape 5 : commit**

```bash
git add global/agents/feedback-triager.md global/skills/pr/SKILL.md
git commit -m "📝 pr: Issue Sonar en entrée du tri

Co-Authored-By: <modèle de l'implémenteur>"
```

## Recette (étape 6 de `feature`)

Agent neuf, profil `vidal`, depuis `~/IdeaProjects/renoshield` : lit le texte final de `comments.md` et exécute à
blanc l'étape 1 et le tri de l'étape 2 sur la PR 318, sans corriger, pousser, répondre ni écrire dans Sonar. Attendu :
les 3 issues (`current-version-pane.component.html:10`, `gpr-record-detail.component.ts:369`,
`gpr-record.service.spec.ts:106`) lues comme retours avec leur `key` et leur texte, triées ; pour une issue
écartée, le statut proposé et sa raison, « rien n'est écrit dans Sonar avant accord ». Puis, à la lecture du texte,
ce que fait `comments` dans chaque autre cas du § 4 de la spec : analyse en cours sans aucun fil, 2 fils et
2 issues (seuil), MCP absent, `/pr 318 comments de alice`, issue `BLOCKER` corrigée sur sa propre PR sans remarque
`**[bloquant]**`, issue écartée sans accord avec un fil corrigé, aucun retour du tout.

Les chemins qui écrivent (correctif poussé sans réponse, statut `accept` posé dans Sonar) ne sont pas joués : la
recette reste à blanc, et « Limites » de la PR dit qu'ils se vérifient au premier vrai `/pr 318 comments` (réponse
dans Plannotator).

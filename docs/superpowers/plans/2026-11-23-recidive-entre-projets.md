# Récidive d'une règle globale entre projets : plan d'implémentation

> **Pour les agents :** sous-skill requis : `superpowers:subagent-driven-development`. Étapes en cases à cocher.

**But :** `lessons-extractor` compte les citations d'une règle globale dans les `lecons.md` de tous les projets.

**Architecture :** deux textes changent : l'agent `global/agents/lessons-extractor.md` (lecture, tri, récidive,
cible) et l'étape 2 de `global/skills/pr/merge.md`. Aucun script : l'agent lance lui-même `find` et `git grep`.

**Pile :** Markdown lu par des agents ; `tests/run.sh` (shellcheck, 120 colonnes de prose).

**Spec :** `docs/superpowers/specs/2026-11-23-recidive-entre-projets-design.md`

## Découpage en PR

Une seule PR : 2 fichiers touchés hors tests, spec et plan (`docs/domaine.md` est déjà commité avec la spec ;
`docs/reste-a-faire.md` se met à jour à l'étape 5 du cycle).

## Contraintes globales

- Texte français, édité par Edit, jamais `sed -i` ni `printf` ; prose ajoutée ≤ 120 colonnes
  (`test_branch_respects_rules`) ; une commande longue va dans un bloc de code délimité.
- Commandes de la spec, fragment entre apostrophes (entre guillemets doubles, les backticks et `$` d'un fragment
  s'exécutent : rejoué en revue, la recette 2 échouait), chaque `'` du fragment écrit `'\''` :

  ```bash
  find ~ -maxdepth 6 -path '*/.superpowers/sdd/*/lecons.md' -not -path '*.worktrees/*' \
    -exec grep -HnF -e '<fragment>' {} +
  git -C "$(dirname "$(readlink -f ~/.claude/CLAUDE.md)")" grep -lF -e '<fragment>' \
    -- CLAUDE.md RTK.md skills agents
  ```

- Commits : `Co-Authored-By: <modèle de l'implémenteur>`, remplacé par le modèle réel.

## Review Focus

- Fragment avec backticks, `$` ou apostrophe : passé entre apostrophes, `'` écrit `'\''` (Task 1, étape 3) ;
  recette, scénario 2 (backticks et « d'abord »).
- `lecons.md` du dépôt qui merge, rendu aussi par le `find` : pas compté comme autre projet (hors de `<racine>`) ;
  recette, scénario 1.
- `~/.claude/CLAUDE.md` qui n'est pas un lien (installation absente) : `readlink -f` rend le fichier lui-même, et
  `dirname` donne `~/.claude`, où `git grep` échoue. L'agent le dit et ne compte pas entre projets (Task 1, étape
  4) ; relu en review.
- Arbre de la PR dans un worktree de `claude-config` : la règle globale se cherche dans `global/` de cet arbre, pas
  via `~/.claude` (qui pointe vers le dépôt principal) ; recette, scénario 1.

## Traçabilité

| Exigence (§ spec) | Tâche | Preuve |
|---|---|---|
| R1 : lecture des `lecons.md` des autres projets, commande de `find` | 1 | grep `-maxdepth 6` dans l'agent ; recette 1 |
| R1 : définition de « globale » (`global/`, `RTK.md`, skills hors `claude-config` exclus) | 1 | grep `readlink -f` ; recette 3 |
| R1 : ligne sans `(récidive :` non comptée | 1 | grep `porte \`(récidive :\`` |
| R1 : `ponctuel` d'un autre projet compté et signalé | 1 | recette 1 (ligne `ponctuel` d'un autre projet) |
| R1 : fragment absent de `global/` → pas de compte | 1 | recette 3 |
| R1 : « citée deux fois » entre deux projets | 1 | grep `entre deux projets` ; recette 1 et 2 |
| R2 : rien d'un autre projet dans un texte publié | 1, 2 | grep `texte publié` ; recette 1 et 2 |
| R2 : `notify` dit que la colonne Source reste hors de la PR | 1, 2 | grep dans `merge.md` ; recette 2 |
| R2 (review I1) : toute proposition le dit ; `merge.md` le rappelle à la session (commit, description, issue) | correctif I1 | grep `ni les chemins de la colonne` dans `merge.md` ; recette 1 rejouée |
| Portée : `description` de l'agent | 1 | grep `les lecons.md des autres projets` dans le frontmatter |
| Portée : `merge.md` étape 2, `lecons.md` des autres projets | 2 | grep |
| Portée : « Réponse », « Entrée » inchangées | — | `git diff main...HEAD -- global/agents/lessons-extractor.md` relu : aucun hunk dans ces sections |
| Portée : `pr/SKILL.md`, `notify/SKILL.md`, `CLAUDE.md` inchangés | — | `git diff --stat main...HEAD` |
| § 3 : leçons existantes comptées sans migration | 1 | recette 1 (leçons déjà écrites) |
| Combiné : chemin cité sous une autre forme (« CLAUDE.md global ») | 1 | recette 1 |
| Combiné : fragment de `RTK.md` | 1 | `git grep -lF` de la conception (RTK.md trouvé) ; recette 3 bis |

Usages vérifiés à l'étape 1b : « PR précédentes » n'est écrit que dans l'agent (l. 3 et 25) et `merge.md:14` ;
« citée deux fois » seulement dans l'agent (l. 64 et 98) ; le format `(récidive :` dans `pr/SKILL.md:57`, inchangé.
Aucun test du dépôt ne lit ces textes : filet = recette (spec § 5).

### Task 1 : compter entre projets dans `lessons-extractor`

**§ :** 2 (R1, R2), 3, 4. **Fichiers :** Modify `global/agents/lessons-extractor.md`.

- [ ] **Étape 1 : rouge** — les fragments ajoutés sont absents :

```bash
git grep -nF 'les lecons.md des autres projets' -- global/agents/lessons-extractor.md
git grep -nF 'maxdepth 6' -- global/agents/lessons-extractor.md
git grep -nF 'readlink -f' -- global/agents/lessons-extractor.md
git grep -nF 'entre deux projets' -- global/agents/lessons-extractor.md
git grep -nF 'texte publié' -- global/agents/lessons-extractor.md
```

Attendu : aucune sortie, code 1 pour chacune.

- [ ] **Étape 2 : frontmatter** — dans `description`, remplacer
  `du dossier de suivi et des PR précédentes, trie` par
  `du dossier de suivi et des PR précédentes, et, pour une règle globale, les lecons.md des autres projets, trie`.

- [ ] **Étape 3 : « Lire »** — après la puce « Les mêmes fichiers des PR précédentes », insérer :

````markdown
- Pour une règle globale (« Trier ») : les lignes des `lecons.md` hors de `<racine>` qui citent son fragment, par
  la commande ci-dessous (`grep -r` sur un dossier peut ne rien rendre, dans un pipe par exemple). Fragment entre
  apostrophes, chaque `'` écrit `'\''` : entre guillemets doubles, ses backticks s'exécutent. Pas leurs
  `final-review.md`.

  ```bash
  find ~ -maxdepth 6 -path '*/.superpowers/sdd/*/lecons.md' -not -path '*.worktrees/*' \
    -exec grep -HnF -e '<fragment>' {} +
  ```
````

- [ ] **Étape 4 : « Trier »** — après la puce `méca` ou `jugement` (qui finit par « garde (`méca`) ou règle
  (`jugement`) » puis la phrase sur la récidive), insérer la puce :

```markdown
- Règle globale : son fragment est dans le dossier `global/` actuel de `claude-config` (`CLAUDE.md`, `RTK.md` qu'il
  importe, `skills/`, `agents/`) : celui de l'arbre de la PR pour `claude-config`, ailleurs celui que donne
  `dirname "$(readlink -f ~/.claude/CLAUDE.md)"`, cherché par
  `git -C <dossier> grep -lF -e '<fragment>' -- CLAUDE.md RTK.md skills agents`. Un skill de `~/.claude/skills/`
  qui ne pointe pas vers ce dossier n'en est pas. Recherche en échec (installation
  absente, pas de dépôt) → le dire, pas de compte entre projets. Chaque ligne d'un `lecons.md` hors de `<racine>`
  (commande de « Lire ») qui porte `(récidive :` et le fragment compte comme une récidive entre deux PR, même
  étiquetée `ponctuel` : la ranger dans les étiquettes corrigées, avec son chemin, sans modifier le fichier.
  Fragment absent de `global/` (règle du projet, réécrite ou retirée) → pas de compte entre projets.
```

- [ ] **Étape 5 : « Récidive »** — remplacer
  `Règle citée deux fois (deux récidives, dans cette PR ou entre deux PR) : seulement mécaniser ou retirer.` par
  `Règle citée deux fois (deux récidives, dans cette PR, entre deux PR ou entre deux projets pour une règle globale) :`
  `seulement mécaniser ou retirer.` (coupé à 120 colonnes).

- [ ] **Étape 6 : « Cible »** — après le paragraphe « Cible globale hors projet `claude-config` … après accord. »,
  insérer le paragraphe :

```markdown
Aucun texte publié tiré d'une proposition (diff, corps d'issue, description et commit de la PR) ne cite le nom d'un
autre projet ni le texte de ses leçons : leurs chemins restent dans la colonne « Source ». Une proposition `notify`
qui s'appuie sur un autre projet le dit, pour que la session `claude-config` ne les recopie pas dans sa PR.
```

- [ ] **Étape 7 : vert** — les cinq grep de l'étape 1 rendent chacun une ligne ; puis `bash tests/run.sh`
  (`timeout: 580000`), sortie lue par `grep -v '^PASS'` : aucun FAIL.

- [ ] **Étape 8 : commit**

```bash
git add global/agents/lessons-extractor.md
git commit -m "📝 lessons-extractor: Récidive d'une règle globale comptée entre projets

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 2 : étape 2 de `merge.md`

**§ :** 2 (portée `merge.md`, R2). **Fichiers :** Modify `global/skills/pr/merge.md`.

- [ ] **Étape 1 : rouge**

```bash
git grep -nF 'les `lecons.md` des autres projets' -- global/skills/pr/merge.md
git grep -nF 'restent hors de la PR' -- global/skills/pr/merge.md
```

Attendu : aucune sortie.

- [ ] **Étape 2** — remplacer `puis ceux des PR précédentes (`<racine>/.superpowers/sdd/*/`), et trie les` par
  `puis ceux des PR précédentes (`<racine>/.superpowers/sdd/*/`) et, pour une règle globale, les `lecons.md` des`
  `autres projets, et trie les`, en recoupant les lignes à 120 colonnes sans réécrire la suite de la phrase.

- [ ] **Étape 3** — remplacer `après accord, `/notify claude-config` avec le diff proposé (skill `notify`), et la
  session` par `après accord, `/notify claude-config` avec le diff proposé (skill `notify`) et, si la proposition
  s'appuie sur un autre projet, la mention que ses chemins Source restent hors de la PR, et la session`, recoupé à 120 colonnes.

- [ ] **Étape 4 : vert** — les deux grep rendent une ligne ; relire la phrase entière de l'étape 2 ; puis
  `bash tests/run.sh`, sortie par `grep -v '^PASS'` : aucun FAIL.

- [ ] **Étape 5 : commit**

```bash
git add global/skills/pr/merge.md
git commit -m "📝 pr merge: Leçons des autres projets pour une règle globale

Co-Authored-By: <modèle de l'implémenteur>"
```

## Recette (étape 6 du cycle)

Agent neuf (`general-purpose`, Sonnet) qui lit `global/agents/lessons-extractor.md` de la branche et l'exécute, sans
rien écrire. Dossiers de PR fabriqués dans le scratchpad ; les autres projets sont les vrais.

1. Dossier de PR = `.superpowers/sdd/2026-11-23-lecons-sans-regle/` de `claude-config`, projet `claude-config` →
   la leçon `lecons.md:9` (humanizer) sort « citée deux fois » (mécaniser ou retirer), Source avec les deux chemins
   dont celui d'un autre projet, signalé `ponctuel` dans les étiquettes corrigées ; aucun diff ne nomme ce projet.
2. Dossier fabriqué, projet hors `claude-config`, une leçon `[méca]` qui cite
   `~/.claude/skills/pr/comments.md « corps écrit dans un fichier avec Write d'abord, pas `printf`/`echo` »` →
   « citée deux fois » avec un autre projet, marquée `notify`, et la proposition dit que ses chemins restent hors de la
   PR.
3. Dossier fabriqué, une leçon qui cite un fragment du `CLAUDE.md` d'un autre projet (absent de `global/`) → pas de
   compte entre projets.
   3 bis. Une leçon qui cite un fragment de `global/RTK.md` → reconnue globale (aucune autre citation : une seule).

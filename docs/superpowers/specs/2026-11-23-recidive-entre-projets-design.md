# Récidive d'une règle globale entre projets

## 1. Demande initiale

> **Récidive d'une règle globale entre projets** (question en revue de #184, 2026-11-23) : `lessons-extractor` ne
> lit que les dossiers de suivi de son dépôt. Une règle d'un skill ou d'un agent global citée une fois dans [projet A]
> et une fois dans [projet B] n'est jamais vue comme citée deux fois, alors que la deuxième citation impose de mécaniser
> ou de retirer. Piste : pour une règle globale, l'extracteur de `claude-config` lit aussi les `lecons.md` des
> autres dépôts (`~/IdeaProjects/*/.superpowers/sdd/*/`, liste à fixer). Écarté : demander aux sessions des projets
> d'analyser leurs leçons à la main (le merge de chaque projet le fait déjà, réponses à fusionner sans règle).
> À vérifier : que tous les projets vivent sous `~/IdeaProjects`. (docs/reste-a-faire.md, point 9 ; noms de projets
> remplacés par [projet A] et [projet B] : la config sert à tout projet)

## Constats

- **Tous les projets ne vivent pas sous `~/IdeaProjects`.** Des dossiers de suivi existent aussi sous
  `~/AndroidStudioProjects/<projet>` et `~/.config/<outil>`. Une liste fixe de racines vieillirait : la recherche
  part de `~`.
- **Commande jouée** (151 `lecons.md` trouvés, 0,2 s) :

  ```bash
  find ~ -maxdepth 6 -path '*/.superpowers/sdd/*/lecons.md' -not -path '*.worktrees/*' \
    -exec grep -HnF -e '<fragment>' {} +
  ```

  Fragment entre apostrophes, chaque `'` écrit `'\''` : entre guillemets doubles, ses backticks s'exécutent.
  Fragment précédé de `-e` (review M1) : sans lui, un fragment en tête `-` est lu comme une option (code 2 ou 129).

  `grep -r` sur un dossier peut ne rien rendre (`grep` est ici une fonction shell : la ligne seule, rien dans un
  pipe ; review M2, la cause n'est pas le hook rtk) : la commande passe les fichiers à `grep`.
- **Cas réel** : la règle globale `global/CLAUDE.md` « Before publishing the final commit(s) of a PR » est citée en
  récidive dans `claude-config` (`2026-11-23-lecons-sans-regle/lecons.md:9`) et dans un autre projet, le projet B
  (une ligne `[ponctuel]`, écrite « CLAUDE.md global »). Chaque extracteur n'en voit qu'une.
- **Le fichier cité s'écrit de plusieurs façons** (`global/CLAUDE.md`, `CLAUDE.md global`,
  `~/.claude/skills/pr/comments.md`) : le compte se fait sur le fragment, jamais sur le chemin.
- **La piste « seul l'extracteur de `claude-config` lit les autres » ne couvre pas l'exemple de la demande.**
  L'extracteur ne traite que les leçons de la PR qui merge, plus les anciennes qui forment une récidive avec elles.
  Une règle citée dans le projet A puis dans le projet B, jamais dans une PR de `claude-config`, resterait invisible.
- `claude-config` est un dépôt public ; les dossiers de suivi (`.superpowers/`) ne sont versionnés nulle part.

## Approches

| Approche | Pour | Contre |
|---|---|---|
| A. Seul l'extracteur lancé dans `claude-config` lit les autres projets (piste de la demande) | aucune lecture hors projet depuis les projets | rate le cas projet A + projet B (constat ci-dessus) |
| B. Tout extracteur, pour une leçon qui cite une règle globale, cherche son fragment dans les `lecons.md` de tous les projets | le projet qui merge en second voit la deuxième citation ; la proposition part déjà en `notify` vers `claude-config` | lecture de dossiers d'autres projets depuis chaque merge |
| C. Registre partagé des citations (fichier dans `~/.claude/`) | compte direct | un format et un écrivain de plus, pour une recherche de 0,2 s |

Retenue (décision de l'utilisateur) : B. Tout extracteur, pour une leçon qui cite une règle globale, compte entre
projets : le projet qui merge en second voit la récidive.

## 2. Portée de chaque règle

**Règle R1 — compter entre projets.** Une leçon de la PR qui cite une règle (`(récidive : … « <fragment> »)`) ou
dont la règle trouvée par le grep du tri est globale : l'extracteur cherche le fragment dans les `lecons.md` de tous
les projets par la commande des Constats. Est **globale** une règle dont le fragment se trouve dans le dossier
`global/` actuel de `claude-config` (`CLAUDE.md`, `RTK.md` qu'il importe, `skills/`, `agents/`) : celui de l'arbre
de la PR pour `claude-config`, ailleurs celui que donne `dirname "$(readlink -f ~/.claude/CLAUDE.md)"`, cherché par
`git -C <dossier> grep -lF -e '<fragment>' -- CLAUDE.md RTK.md skills agents` (review #185 : `-- .` lisait aussi
les hooks et `profiles.json`). Les skills de `~/.claude/skills/` qui ne pointent pas vers ce dossier
(`angular-developer`, `plannotator`…) n'en sont pas. Une leçon de la PR étiquetée `ponctuel` qui cite une règle
(`(récidive :`) a une étiquette fausse : corrigée, elle suit R1 (review #185).
Chaque ligne d'un autre projet qui porte `(récidive :` et le fragment compte comme une récidive « entre deux PR » :
deux citations au total → seulement mécaniser ou retirer.
Fragment absent de `global/` (règle propre au projet, ou déjà réécrite ou retirée) → pas de compte entre projets.
Une citation d'un autre projet étiquetée `ponctuel` compte quand même ; la réponse la range dans ses étiquettes
corrigées, avec son chemin, sans modifier le fichier.

**Règle R2 — rien d'un autre projet dans un texte publié** (décision de l'utilisateur). Aucun texte publié tiré de
la proposition (diff, corps d'issue, description et commit de la PR) ne cite le nom d'un autre projet ni le texte de
ses leçons. La colonne « Source » de la réponse porte leurs chemins ; elle reste locale (conversation, message
`notify`), et une proposition marquée `notify` qui s'appuie sur un autre projet le dit, pour que la session
`claude-config` ne recopie pas ses chemins dans la PR.
Review I1 : toute proposition qui s'appuie sur un autre projet le dit (pas seulement `notify`), et `merge.md` étape 2
le rappelle à la session qui écrit le commit, la description et l'issue, puisqu'elle ne lit que la réponse de l'agent.

| Endroit | Ce qu'il devient |
|---|---|
| `global/agents/lessons-extractor.md`, frontmatter `description` | cite la lecture des autres projets pour une règle globale (rôle de l'agent changé) |
| `global/agents/lessons-extractor.md`, « Lire » | une puce : pour une règle globale, les `lecons.md` des autres projets, par la commande de R1 |
| `global/agents/lessons-extractor.md`, « Trier », puce du grep de la règle | R1 : règle globale définie, compte entre projets, fragment absent → pas de compte |
| `global/agents/lessons-extractor.md`, « Récidive », « Règle citée deux fois (… entre deux PR) » | « ou entre deux projets pour une règle globale » |
| `global/agents/lessons-extractor.md`, « Cible », paragraphe `notify` | R2 |
| `global/skills/pr/merge.md`, étape 2, phrase « après accord, `/notify claude-config` avec le diff proposé » | R2 : une phrase pour la session, ni nom, ni texte, ni chemins d'un autre projet dans le commit, la description ou une issue ; le message `notify` peut les citer en rappelant qu'ils restent hors de la PR |
| `global/skills/notify/SKILL.md`, « Fait » (chemins absolus des fichiers cités) | inchangé : R2 vit dans le message rédigé à l'étape 2 de `merge.md` |
| `global/agents/lessons-extractor.md`, « Réponse », exemple de la colonne « Source » | inchangé : `../x/lecons.md:4` couvre déjà un chemin hors du dossier |
| `global/agents/lessons-extractor.md`, « Entrée » | inchangé : la recherche part de `~`, rien à donner dans le brief |
| `global/skills/pr/merge.md`, étape 2, « puis ceux des PR précédentes (`<racine>/.superpowers/sdd/*/`) » | ajoute « et, pour une règle globale, les `lecons.md` des autres projets » |
| `global/skills/pr/SKILL.md`, « Dossier de suivi », format `(récidive : <fichier> « <fragment> »)` | inchangé : le compte se fait sur le fragment, le chemin peut garder ses formes |
| `docs/domaine.md`, contexte Leçons | termes « Règle globale » (`RTK.md` compris), « Dossier de suivi » et invariant du compte entre projets (ajoutés par `ddd`) |
| `docs/reste-a-faire.md`, point 9 | rayé, avec ce qui est fait (étape 5 du cycle) |
| `global/CLAUDE.md`, `CLAUDE.md` | inchangés |

N'est plus lu : rien. La règle ajoute une lecture (les `lecons.md` des autres projets) ; les `final-review.md` des
autres projets ne sont pas lus (seules les citations comptent entre projets).

## 3. Données existantes

Les leçons déjà écrites dans les autres projets comptent dès le premier merge qui suit : le cas réel (humanizer)
sort en « citée deux fois » au prochain merge qui cite cette règle. Une étiquette fausse d'un autre projet
(`[ponctuel]` avec une récidive, celle du projet B) n'est pas corrigée dans son fichier : sa citation
compte quand même. Aucune migration.

## 4. Critères d'acceptation

**P1 — une règle globale citée dans deux projets sort en « citée deux fois ».** Une seule story.

- Nominal : la PR de `claude-config` porte une leçon qui cite `global/CLAUDE.md` « Before publishing the final
  commit(s) of a PR » ; le projet B la cite aussi → proposition « mécaniser » ou « retrait », Source avec les deux
  chemins.
- Nominal hors `claude-config` : la PR d'un projet cite une règle globale qu'un autre projet a citée → mécaniser
  ou retirer, marqué `notify`.
- Refus : fragment présent seulement dans le `CLAUDE.md` ou l'`AGENTS.md` d'un autre projet (règle locale) → pas
  de compte entre projets.
- Refus : ligne d'un autre projet qui contient le fragment sans `(récidive :` → pas comptée.
- Nominal : fragment de `global/RTK.md` cité dans deux projets → compté (règle globale).
- Refus : fragment cité ailleurs mais absent des fichiers globaux actuels (règle réécrite depuis) → pas de compte.
- Combiné : citation dans un autre projet sous une autre forme de chemin (« CLAUDE.md global ») → comptée.
- Combiné : citation dans un autre projet étiquetée `[ponctuel]` → comptée, et la réponse le signale.
- Combiné : leçon de la PR étiquetée `[ponctuel]` qui cite une règle globale citée ailleurs → ré-étiquetée, comptée.
- Refus : fragment présent seulement dans un hook ou `profiles.json` de `global/` → pas de compte entre projets.
- Combiné : proposition qui naît d'une citation d'un autre projet → le diff ne nomme pas ce projet (R2).
- Combiné : cette proposition est aussi marquée `notify` → elle dit que ses chemins Source restent hors de la PR.

## 5. Filet sur l'existant

Fichiers modifiés : du texte lu par des agents, sans test de comportement possible. Le comportement actuel se fige par
la recette (agent neuf sur le cas réel, avant et après).

## 6. Origine

- Point traité : *hors périmètre* de la spec `2026-11-23-lecons-sans-regle` (question en revue de #184), reste à
  faire point 9.
- Hors périmètre : dédoublonner deux `notify` reçus pour la même règle ; normaliser le chemin dans le format de
  citation ; lire les `final-review.md` des autres projets.

## 7. Dette du code touché

`lessons-extractor.md` (102 lignes) et l'étape 2 de `merge.md` : pas de seuil pour un texte ; la phrase de l'étape 2
est déjà longue, l'ajout se fait en fin d'incise sans la réécrire. Rien à reporter.

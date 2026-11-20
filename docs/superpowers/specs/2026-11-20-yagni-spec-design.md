# Contrôle YAGNI de la spec

## But

`/feature` ne cherche aujourd'hui le code en trop qu'à l'étape 7, par `ponytail-review`, une fois le code écrit. Une
option que personne n'a demandée, ou un script qui refait ce qu'un autre fait déjà, est donc spécifiée, planifiée,
implémentée et testée avant d'être relevée ; la retirer à ce stade coûte un correctif, une spec amendée et souvent
un « à trancher ». Le contrôle remonte à la spec : avant sa première ouverture dans Plannotator, un agent neuf la lit
contre le code du dépôt, en même temps que `ddd revue spec`, et l'utilisateur tranche ce qui reste dans Plannotator.

## 1. Demande initiale

`/feature`, qui reprend le point 2 des Features de `docs/reste-a-faire.md` :

> **Relecteur YAGNI sur la spec** (EGM, `agents/zoom_out.md`) : à l'étape 1 ou 1b de `feature`, en parallèle de
> `ddd revue`, un agent neuf cherche dans le code un utilitaire qui fait déjà le travail, une option spéculative ou
> une optimisation prématurée. Aujourd'hui, ce contrôle n'existe qu'en fin de feature, sur le code
> (`ponytail-review`). (docs/reste-a-faire.md, point 2)

## Règles

**R1 — Un agent `spec-yagni-checker` contrôle la spec.** Nouvel agent `global/agents/spec-yagni-checker.md`,
lancé avec le modèle **Sonnet** passé explicitement, en lecture seule (`disallowedTools: Edit, Write, NotebookEdit`,
comme `convergence-checker`). Il cherche trois sortes d'écarts, termes du glossaire (`docs/domaine.md`, contexte
« Conception de feature ») :
- **Utilitaire existant** : la spec prévoit d'écrire une fonction, un script, une règle ou un agent que le dépôt
  (ou un outil standard déjà utilisé) fait déjà. Preuve exigée : `fichier:ligne` de l'existant, trouvé par
  `git grep` sur tout le dépôt.
- **Option spéculative** : option, mode, réglage ou cas que la spec ajoute sans que la demande initiale le demande.
- **Optimisation prématurée** : cache, parallélisme ou détour écrit pour la vitesse sans lenteur constatée ni volume
  qui l'exige.

Invariant : un élément cité dans le § « Demande initiale » n'est jamais une option spéculative.

Le contrôle d'EGM (`zoom_out.md`) cherche aussi le contexte insuffisant, le détail d'implémentation dans la spec et
les impasses d'architecture : ces axes ne sont pas repris, la demande n'en cite que trois, et le premier est déjà
couvert par la paraphrase de `ddd revue spec`.

**R2 — Entrée de l'agent.** Le chemin de la spec et la racine du dépôt ; rien d'autre, jamais l'avis de l'auteur ni
la conversation. Il lit la spec entière (§ « Demande initiale » compris : c'est sa référence pour R1), puis cherche
dans le code chaque élément que la spec prévoit d'écrire.

**R3 — Tri des écarts**, avec les catégories de `ddd revue` :
- **À corriger** : une seule correction raisonnable, sans effet sur le comportement ni la portée (réutiliser un
  utilitaire existant qui fait exactement la même chose, retirer une optimisation sans effet visible). L'agent cite
  le passage et le texte corrigé.
- **À trancher** : le correctif change le comportement ou la portée, ou plusieurs options se valent. Une option
  spéculative est toujours « à trancher » : la retirer change la portée. Un utilitaire existant cité par la demande
  aussi : renoncer à l'écrire change la portée. 2-3 lignes : impact, options, recommandation.
- **Écarté** : un écart envisagé qui ne tient pas (élément cité par la demande sans être un utilitaire existant,
  utilitaire voisin qui ne fait pas la même chose), une ligne de raison. Un élément qui n'évoque aucune des trois
  sortes n'y figure pas.

Un écart n'est que dans une partie. Rien à signaler : une ligne.

**R4 — Place dans `feature` : la validation fonctionnelle de la spec, étape 1.**

Le contrôle passe à l'étape 1, avant la première ouverture dans Plannotator : l'utilisateur tranche ses points en
même temps que ceux de `ddd`. L'étape 1b, que la demande permettait aussi, rouvrirait Plannotator pour une seconde
approbation dès qu'il trouve quelque chose. (Décision prise dans Plannotator.)

« En parallèle » se lit ainsi : la session lance l'agent en arrière-plan, seul dans son message (règle de
« Exécution » : chaque appel `Agent` seul), puis invoque `ddd revue spec` au message suivant. Les deux tournent en
même temps. La session attend les deux rapports avant d'appliquer quoi que ce soit : une correction appliquée
pendant que l'autre tourne changerait la spec sous ses yeux.

**R5 — Traitement des écarts, comme ceux de `ddd revue`.** Ses « à corriger » s'appliquent avant l'ouverture, ses
« à trancher » deviennent des blocs `:::question` à l'endroit qu'ils touchent. Un point relevé par les deux
contrôles donne une seule correction ou un seul bloc. Un « à trancher » posé sur un passage qu'un « à corriger » de
l'autre contrôle réécrit porte sur le texte corrigé. Les réouvertures suivantes ne relancent pas l'agent, sauf si
les annotations changent le comportement ou la portée. Son rapport reste dans la conversation, comme celui de
`ddd revue` : pas de fichier dans le dossier de suivi.

**R6 — Le plan n'est pas contrôlé.** La demande vise la spec. Le plan est tenu à la spec (aucun ajout permis), et
`ponytail-review` relit le code à l'étape 7.

## 2. Portée

| Endroit | Ce qu'il devient |
|---|---|
| `global/agents/spec-yagni-checker.md` | Nouveau : R1 à R3, interdits et refus du mode auto sur le modèle de `convergence-checker.md`, réponse attendue |
| `global/skills/feature/SKILL.md`, § « Validation fonctionnelle » (l. 137-147) | Reçoit R4 et R5 pour la spec ; la phrase sur le plan est inchangée (R6) |
| `global/skills/feature/SKILL.md`, § « Exécution » (l. 170) | « Le brief des agents de contrôle, de convergence et de review » : une phrase ajoutée après ce passage dit que `spec-yagni-checker` obéit aux mêmes interdits et rend son rapport dans sa réponse (la ligne de l'énumération dépasse déjà 120 colonnes et ne se réécrit pas) |
| `global/skills/feature/SKILL.md`, étape 1 du cycle (l. 20) | Inchangée : elle renvoie à la validation fonctionnelle sans la détailler |
| `global/skills/feature/SKILL.md`, étape 7 et « Dosage des reviews » | Inchangés : `ponytail-review` relit toujours le code, le contrôle de la spec ne le remplace pas |
| `global/skills/feature/SKILL.md`, « Excuses et réalité » (l. 336) | Inchangé : « `ddd revue` la déroule parcours par parcours » reste vrai |
| `global/skills/ddd/SKILL.md` | Inchangé : la revue métier écarte la qualité du code (l. 105, « hors sujet ») ; le YAGNI n'y entre pas |
| `global/skills/bugfix/SKILL.md` | Inchangé : pas de spec (l. 11) |
| `docs/domaine.md` | Contexte « Conception de feature » ajouté par l'analyse `ddd` : validation fonctionnelle, revue métier, écart, contrôle YAGNI, utilitaire existant, option spéculative, optimisation prématurée, review finale |
| `docs/reste-a-faire.md` | Features point 2 rayé ; le point 3 (« un agent de review, de convergence ou `ddd revue` qui expire ») cite aussi `spec-yagni-checker` |
| `README.md` (l. 32-33), `bin/claude-config install` | Inchangés : les agents de `global/agents/*.md` sont liés un par un, le nouveau l'est sans changement |

Rien n'est retiré de ce que la validation fonctionnelle lisait : `ddd revue spec` reste entière, l'agent s'y ajoute.

## 3. Données existantes

Sans objet : aucune donnée. Les specs déjà approuvées ne repassent pas au contrôle.

## 4. Critères d'acceptation

Une seule story, **P1 — la spec passe au contrôle YAGNI avant Plannotator**.

- Nominal : une spec qui prévoit un script déjà présent dans le dépôt → l'agent rend un « utilitaire existant » avec
  `fichier:ligne` de l'existant.
- Option spéculative : une spec qui ajoute un mode absent de la demande → « à trancher », jamais « à corriger ».
- Invariant : une option citée dans la demande initiale → écartée, avec la raison.
- Optimisation prématurée : un cache sans lenteur constatée → relevé.
- Rien à signaler : une ligne.
- Combiné : un utilitaire existant cité par la demande → « à trancher », dans cette seule partie (ni « à
  corriger » ni « écarté »).
- Combiné : un même point relevé par `ddd revue` et par l'agent → une seule correction ou un seul bloc
  `:::question`.
- Combiné : un « à corriger » de l'agent et un « à trancher » de `ddd` sur le même passage → le bloc `:::question`
  porte sur le texte déjà corrigé.
- Ordre : l'agent part seul dans son message, `ddd revue spec` au suivant ; aucune correction n'est appliquée avant
  le retour des deux.
- Plan : la validation fonctionnelle d'un plan ne lance pas l'agent.
- Lecture seule : l'agent ne modifie ni la spec ni le dépôt, et ne reçoit pas l'avis de l'auteur.

Le dépôt n'a pas de test automatique du comportement des skills ni des agents. Chaque critère se vérifie à la
lecture du texte. La recette (étape 6) lance l'agent neuf sur une spec d'essai qui contient un utilitaire existant,
une option spéculative, une option citée dans sa demande et un cache, et lit son rapport.

## 5. Filet sur l'existant

Aucun test de caractérisation : les fichiers touchés sont du texte de skill et d'agent, sans test automatisé.
`bash tests/run.sh` reste vert (`test_links.sh` lie les agents par motif, sans liste de noms).

## 6. Origine

Point 2 des Features de `docs/reste-a-faire.md`, idée reprise d'EGM (`agents/zoom_out.md` de
google/elephant-goldfish-model). Ni régression ni défaut : une amélioration.

Hors périmètre :
- les axes d'EGM non demandés (contexte insuffisant, détail d'implémentation, impasse d'architecture) : R1 ;
- le contrôle du plan : R6 ;
- l'agent qui expire ou ne rend rien : point 3 du reste à faire (« non lancé »), qui le cite désormais.

## 7. Dette du code touché

Texte de skill et d'agent : la grille de code ne s'applique pas. Contrôles de texte : lignes de 120 colonnes au
plus, mêmes termes dans l'agent, `feature` et le glossaire (utilitaire existant, option spéculative, optimisation
prématurée), énumération d'« Exécution » à jour.

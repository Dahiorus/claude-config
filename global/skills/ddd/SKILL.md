---
name: ddd
description: Use when the user invokes /ddd, asks to analyse the business side of a request or need (« analyse fonctionnelle », « quel vocabulaire métier », « quels contextes bornés », ubiquitous language, bounded context, glossaire), or to check a spec or implementation plan against the business need (« la spec répond-elle au besoin ? », « relis le plan côté métier »). Also called by /feature before writing a spec and before opening a spec or plan in Plannotator.
argument-hint: "[revue <spec|plan>] <demande, ticket ou chemin> [spec du plan] [fichiers clés]"
context: fork
model: opus
---

# DDD : analyse métier

Le besoin métier se dit avec les mots du métier, et le code doit les reprendre. Ce skill établit ces mots et les
contextes où ils valent (`analyse`), puis vérifie qu'une spec ou un plan les respecte et répond au besoin (`revue`).
Il tourne sans la conversation : ce qu'il sait vient de la demande, du glossaire et du code.

## Le glossaire

Un seul fichier par dépôt, `docs/domaine.md`, versionné. S'il existe déjà un glossaire (`CONTEXT.md`, `docs/glossaire*`,
section d'`AGENTS.md`), il sert de fichier et on n'en crée pas d'autre. Forme, un tableau par contexte borné :

```markdown
## Contexte : Facturation
Responsabilité : … · Dans le code : `src/Billing/` · Dépend de : Catalogue (en aval, via `ProductPriceProvider`)

| Terme | Définition métier | Dans le code | À ne pas dire |
|---|---|---|---|
| Avoir | Facture négative qui annule tout ou partie d'une facture émise | `CreditNote` | remboursement, facture d'annulation |

Invariants : une facture émise n'est jamais modifiée, seulement annulée par un avoir.
```

Un même mot dans deux contextes avec deux sens = deux lignes, une par contexte. Jamais de définition technique
(« ligne de la table … ») : ce que le métier entend.

## `analyse` (par défaut)

Entrée : une demande, un ticket (le lire avec l'outil adapté) ou un besoin décrit en prose, et les fichiers clés
que l'appelant a déjà repérés, s'il y en a.

1. Lire le glossaire, puis les fichiers clés reçus et le code là où la demande pointe : noms de modules, classes, tables, routes, libellés
   d'écran. Le code dit quels contextes existent déjà et quels mots ils emploient.
2. Rendre, dans cet ordre :
   - **Besoin** : qui, quel problème, quel résultat attendu, en trois lignes, avec les mots de la demande.
   - **Contextes bornés touchés** : pour chacun, sa responsabilité, son dossier, et la relation avec les autres
     (amont/aval, traduction à la frontière). Une règle qui demanderait à un contexte de connaître le modèle interne
     d'un autre se signale.
   - **Langage** : chaque terme de la demande, défini, rattaché à son contexte, avec son nom dans le code (existant
     ou proposé). Les synonymes et les mots ambigus de la demande sont relevés.
   - **Modèle** : agrégats et leurs invariants, objets valeur, événements métier (au passé : « Facture émise »).
   - **Parcours** : chaque cas d'usage pas à pas, y compris refus, annulation, retour arrière, droits, liste vide,
     données déjà en base.
   - **Questions** : ce que seul le métier peut trancher (sens d'un mot, règle absente, conflit entre deux règles),
     chacune avec sa recommandation.
3. Reporter dans le glossaire les termes et invariants établis, sans les questions ouvertes. Ne pas commiter :
   l'appelant décide.

## `revue <spec|plan>`

Entrée : le chemin du document, la demande initiale (dans la spec, § « Demande initiale », non reprise dans la
paraphrase) et, pour un plan, sa spec.
Ne pas recevoir l'avis de celui qui a écrit le document.

**Spec : d'abord la paraphrase.** Elle s'écrit avant de lire le code (sinon la revue comble les trous de la spec
sans les voir) et sans reprendre son § « Demande initiale », que l'auteur lui compare ensuite. Sources : le § « But »
s'il existe, les règles et la Portée de la spec, et le glossaire. Sans § « But », le pourquoi vient des règles ; si
elles ne le disent pas, c'est un écart « à trancher ». Écrire deux parties de 2 à 5 phrases chacune, avec les mots du
glossaire :
- **Ce que la spec propose** : le changement, pour qui, et pourquoi ;
- **L'existant selon la spec** : comment marche aujourd'hui ce que la spec change, tel que la spec le décrit (le but
  de la spec, et ce que deviennent les endroits de sa « Portée », regroupés par comportement) ; si elle n'en dit
  rien, la seule phrase « la spec ne décrit pas l'existant ».

Pas plus de 5 phrases par partie : avant de rendre, compter les phrases (un point final = une phrase) ; au-delà,
fusionner ou couper.

Un passage que la revue ne parvient pas à enchaîner au reste (deux parties qui ne se relient pas, une étape
manquante entre deux règles) est un écart, trié comme les autres : « à corriger » si une seule réécriture s'impose,
« à trancher » sinon. Un plan n'a pas de paraphrase : il est relu contre une spec déjà approuvée.

Puis dérouler chaque parcours du besoin dans le document et relever :

| Où | Écart |
|---|---|
| Spec | Besoin de la demande sans règle ; parcours qui bloque ou finit dans un état incohérent ; libellé, message ou statut visible mais non écrit ; deux règles contradictoires ; invariant sans critère d'acceptation ; user story qui n'est pas un parcours démontrable seul |
| Spec et plan | Terme absent du glossaire, employé dans un autre sens, ou remplacé par un synonyme ; règle placée dans un contexte qui n'en est pas responsable ; modèle d'un contexte qui fuit dans un autre |
| Plan | Critère d'acceptation sans test qui l'exerce par le comportement visible (route, écran, commande) ; scénario visible sans recette ; nom (classe, champ, méthode, variable, paramètre, test) qui ne reprend pas le terme du glossaire, reprend un mot de sa colonne « À ne pas dire » ou le terme d'une autre notion ; tâche qui change ce que voit l'utilisateur sans que la spec le dise |

Chaque point est vérifié dans le code (sur `main` si la branche l'a déjà modifié), la paraphrase de l'existant
comprise, puis rendu trié. La paraphrase reste telle que la spec la fait comprendre : un existant que le code
contredit est un écart, trié comme les autres, pas une correction de la paraphrase.
- **À corriger** : une seule correction raisonnable, sans effet sur le comportement ni la portée. Citer l'endroit et le texte corrigé.
- **À trancher** : touche le comportement, la portée ou le sens d'un terme. Impact, options, recommandation, prêt à
  devenir un bloc `:::question`.
- **Écarté** : une ligne de raison. Une raison qui s'appuie sur une source (issue, schéma, `origin/main`) la relit
  d'abord et cite ce qu'elle y a lu.

Rapport : la paraphrase en tête pour une spec, puis les trois catégories. Rien à signaler : pour une spec, la
paraphrase puis la ligne `Verdict : rien à signaler` ; pour un plan, cette seule ligne. Sinon, dernière ligne :
`Verdict : <c> à corriger, <t> à trancher, <e> écartés`. Sans elle, l'appelant tient le rapport pour coupé et relance
la revue (`feature`, « Exécution »). Le document lui-même n'est pas modifié : l'appelant applique.

## Erreurs courantes

- Définir un terme par sa table ou sa classe : c'est le nom dans le code, pas la définition.
- Fusionner deux sens d'un même mot parce qu'ils s'écrivent pareil : un contexte chacun.
- Inventer une règle métier pour combler un trou : c'est une question.
- Juger la qualité du code : hors sujet, c'est la review de `/feature`.

# La porte — conception du premier tronçon

Date : 2026-08-22
Statut : conception, écrite en autonomie pendant l'absence de l'auteur

## Intention

Optium change de nature. Il cesse d'être un minuteur Pomodoro pour devenir une
application qui **dit quand arrêter de valider** : elle lit passivement la
clarté cognitive et refuse de laisser fermer une décision quand celle-ci est
basse.

Ce tronçon construit **la porte** — ce refus — et le minimum qui l'entoure.
C'est délibérément le premier : c'est le pari central du produit, le seul
mécanisme qui a de la valeur dès le premier jour, et celui qui doit être
éprouvé avant que quoi que ce soit d'autre ne mérite d'être écrit.

**Source du concept** : le projet Claude Design « Optium », fichier
`Optium - Parcours complet.dc.html`, et son `README.md` de handoff.

**Source du visuel** : le langage établi dans `docs/brief-design.md` et déjà
implémenté dans `ios-native/Optium/Design/`. Les maquettes Claude Design ont
servi à travailler le concept, **pas l'apparence** — leurs choix visuels ne
font pas foi.

## Décisions prises en autonomie

Cinq, annoncées à l'auteur avant de commencer. Toutes réversibles sauf la
première.

1. **Les données existantes sont perdues.** Le modèle change entièrement ;
   écrire une migration pour des données de test coûterait plus que de laisser
   la base se recréer.
2. **Le code Pomodoro mort est supprimé** — cycle 25/5, onglet Statistiques,
   feuille de fin. Maintenir deux produits coûte plus cher que de réécrire.
3. ~~La barre d'onglets disparaît.~~ **Revenu dessus, et c'était une erreur.**
   J'avais lu « le journal n'est pas une destination » comme une contrainte de
   navigation ; c'en est une de produit — n'en fais pas une boucle d'habitude,
   pas « rends-le inatteignable ». Et iOS 26 vient de réinvestir la barre
   d'onglets : elle est en Liquid Glass, elle se minimise au défilement, elle
   ne coûte presque plus rien visuellement. Une app sans barre d'onglets est
   une app à une seule destination — Optium en aura trois ou quatre.
   **La barre reste, avec peu d'onglets.** La barre de navigation reste elle
   aussi, sauf sur la porte : là, le plein cadre est le message.
4. **La clarté est simulée**, derrière un protocole, avec un réglage de
   développeur. HealthKit et CoreMotion viennent au tronçon suivant.
5. **Rien n'est installé sur l'appareil de l'auteur** pendant son absence.

## Le vocabulaire

Il change, et le code doit changer avec lui — un modèle qui garde les anciens
noms fera écrire l'ancien produit par inadvertance.

| Ancien | Nouveau | Ce que c'est |
|---|---|---|
| `Project` | `Project` | inchangé : un projet, à l'échelle de la semaine |
| `ProjectTask` | `WorkThread` (« fil ») | une phrase d'intention, ouverte de quelques heures à plusieurs jours |
| `FocusSession` | `Resumption` (« reprise ») | un moment passé sur un fil |
| `TimerEngine` | `ThreadSession` | l'état de la reprise en cours |
| — | `Clarity` | l'état lu, jamais saisi |

Les identifiants restent en anglais, les textes affichés en français, comme
tout le reste du projet.

**`WorkThread` et non `Thread`** : `Thread` est le type de Foundation, et
l'ombrer rendrait ambiguë toute utilisation du vrai. Même piège que `Task`,
qui avait déjà imposé `ProjectTask`.

## Le modèle

```
Project
  id, title, openedAt, closedAt?
  threads: [WorkThread]              // cascade

WorkThread
  id, phrase                     // l'intention, saisie une fois, jamais reecrite
  nature: .decision | .production | .mechanical
  state: .open | .inProgress | .closed | .held
  createdAt, closedAt?
  heldUntil: Date?               // si passe par la porte
  acceptance: String?            // la ligne ecrite a la porte
  project: Project?
  resumptions: [Resumption]      // cascade

Resumption
  id, startedAt, endedAt?
  clarityAtStart: Int            // instantane 0-100
  inWindow: Bool
  thread: WorkThread?
```

`Resumption` référence son fil **par relation** et non par identifiant —
contrairement aux anciennes `FocusSession`. La raison a changé : une reprise
n'a aucun sens sans son fil, alors qu'une session de concentration avait une
valeur d'historique propre.

### La machine à états

```
open ──▶ inProgress ──▶ open              (pause)
                    │
                    ├──▶ closed           (clarte suffisante, ou nature != decision)
                    │
                    └──▶ [la porte] ──▶ closed   (une ligne ecrite)
                                    └──▶ held    (jusqu'a la prochaine fenetre)

held ──▶ open   (automatique quand heldUntil est passe)
```

**La porte se déclenche si et seulement si** `thread.nature == .decision` **et**
`clarity.level == .low`. Dans tous les autres cas la fermeture est directe.

C'est la seule friction obligatoire de l'application, et **sa rareté est ce qui
la rend acceptable**. Toute tentation d'élargir la condition doit être refusée.

## La clarté

```swift
enum ClarityLevel { case low, medium, high }   // < 42 ≤ moyenne < 70 ≤ haute

struct Clarity {
    let value: Int          // 0-100, jamais affiche
    let level: ClarityLevel // affiche, en un mot
}

protocol ClaritySource {
    func current() -> Clarity
}
```

**La valeur numérique n'est jamais affichée.** L'interface montre un mot. Cette
règle vient du document et elle est réglementaire autant qu'esthétique : un
score chiffré de performance cognitive s'approche d'un diagnostic.

Ce tronçon fournit `SimulatedClaritySource`, pilotée par un réglage de
développeur à trois positions. Le moteur réel — régularité 45 %, durée 30 %,
circadien 25 %, alimenté par HealthKit avec CoreMotion en repli — se branchera à
la place sans que rien d'autre ne bouge.

**La fenêtre** (le créneau où la décision tient) est également simulée ici : une
plage fixe en début de journée. Son calcul circadien viendra avec le moteur.

## Les écrans

Cinq, plus une feuille. **La barre d'onglets est conservée** — voir la
décision 3. Dans ce tronçon elle n'a qu'un onglet peuplé, l'Accueil ; les
autres viendront avec le journal et les projets. La porte est le seul écran
présenté en plein cadre, sans barre.

### Accueil — l'unique écran permanent

Le cerveau, un mot pour la clarté, la fenêtre, et la liste des fils ouverts.
Une tape sur un fil démarre une reprise. Un bouton ouvre un nouveau fil.

Pas de chiffres, pas de graphe, pas de série. Le document est explicite : « les
apps de productivité meurent dans leur onglet Statistiques ».

### La première phrase

Un champ, une phrase, le choix de la nature du fil. Aucune durée à choisir —
c'est le point du produit. Le texte de la maquette : « Le seul texte que
l'utilisateur écrit dans une journée. »

### Reprise en cours

Le cerveau, la phrase du fil, la durée de la reprise, la fenêtre. Deux actions :
mettre en pause, fermer le fil.

« L'app est muette. Elle renseigne, elle ne demande rien. »

### La porte

**Plein cadre, aucune carte.** C'est le seul écran de l'application qui n'est
pas une surface de verre posée sur le noir, et cette rupture est le message.

Le cerveau, « Tu fermes une décision », un champ pour écrire ce qu'on accepte et
pourquoi, et deux issues : **Fermer** (exige la ligne écrite) ou **Retenir
jusqu'à** la prochaine fenêtre.

### Retenu

« Le plus silencieux. Aucune culpabilisation. » Ce qui a été observé, et une
phrase qui désamorce : rien d'autre n'est bloqué, seule la validation attend.

### Fermeture du fil

La phrase de départ remontrée telle quelle, le nombre de reprises, celles dans
la fenêtre, les nuits traversées, les retenues.

## Le cerveau

Il passe de décoration à objet central. Deux paramètres s'ajoutent aux deux
existants :

| Paramètre | Source | Effet |
|---|---|---|
| `fill` | la clarté | niveau du fluide, déjà implémenté |
| `tint` | jour / nuit | déjà implémenté, deux familles |
| `base` | le plafond permis par la nuit | ligne pointillée clippée à la silhouette ; le fluide ne monte jamais au-dessus |
| `agitation` | nombre de fils ouverts | amplitude de la surface |

Les cinq règles de mouvement du document sont reprises : le niveau ne saute
jamais (interpolation 900 ms), la surface respire en continu (périodes 4,1 s et
6,7 s), la base arrive avant le fluide, la teinte croise à l'extinction, et rien
d'autre ne bouge à l'écran.

**Dans ce tronçon**, `base` et `agitation` sont câblés et rendus, mais `base`
est alimentée par la source simulée.

## Ce qui est supprimé

- `TimerEngine` et sa sémantique Pomodoro — le mécanisme d'horodatage est
  conservé dans `ThreadSession`, c'est la seule chose qui valait d'être gardée.
- `StatsScreen`, `StatsBuilder` et leurs tests — refus explicite du document.
- `CompletionSheet` dans sa forme actuelle.
- `TimerMode`, `SessionCompletion`, les durées focus/pause des réglages.
- L'onglet et `RootTab`.

Le langage visuel (`Design/`), le cerveau (`Brain/`), `Project`, et le projet
Xcode sont conservés intacts.

## Vérification

En test d'abord, sur ce qui se teste sans écran :

- **la machine à états** — chaque transition permise, et surtout celles qui ne
  le sont pas ;
- **la condition de la porte** — elle se déclenche pour une décision à clarté
  basse et pour rien d'autre ; les trois autres natures et les deux autres
  niveaux passent en fermeture directe ;
- **la fermeture exige la ligne écrite** — fermer sans acceptation est refusé ;
- **la libération automatique** — un fil retenu dont `heldUntil` est passé
  redevient ouvert, et cela se constate sans intervention ;
- **la durée d'une reprise** — même mécanisme d'horodatage qu'avant, donc même
  garantie de survie à la suspension du processus ;
- **le comptage de fermeture** — reprises, celles dans la fenêtre, nuits
  traversées.

L'interface se vérifie à l'écran, par capture.

## Hors périmètre

Explicitement, et chacun mérite son propre cadrage : le moteur de clarté réel
et ses deux sources, l'appel au cerveau et Foundation Models, la mémoire
markdown par projet, les paliers et les preuves, l'atterrissage, la
calibration, les surfaces système (île, widgets, notifications, App Intents),
et les comparaisons agrégées.

# Optium — application iOS native

Document autonome. Il décrit ce qu'est le produit, ce qui a été construit,
pourquoi les décisions ont été prises, et les pièges qui ont déjà coûté du
temps. Le lire avant toute modification évite de les repayer.

État au 2026-08-22 : 63 fichiers Swift, ~5 700 lignes, 69 tests, 3 cibles.
Branche `claude/optium-app-review-1d7h0u`, poussée sur
`github.com/sabrilab/Optium`.

---

## 1. Ce qu'est le produit

Optium est une application iPhone qui **dit quand arrêter de valider**.

Elle lit passivement la disponibilité cognitive de l'utilisateur — appelée
**la clarté** — et refuse de laisser fermer une décision quand celle-ci est
basse. Ce n'est ni un minuteur, ni un suivi de productivité.

**Deux verbes, et deux seulement** : elle t'arrête (*la porte*), et tu
l'appelles (*le cerveau*).

**Un seul geste déclaratif dans toute l'application** : noter un café. Tout le
reste est lu.

### Le vocabulaire

| Terme | Ce que c'est |
|---|---|
| **Fil** (`WorkThread`) | Une phrase d'intention, ouverte de quelques heures à plusieurs jours. L'unité de travail. |
| **Reprise** (`Resumption`) | Un moment passé sur un fil. |
| **Projet** (`Project`) | Un conteneur de fils, à l'échelle de la semaine. Facultatif. |
| **La clarté** | 0-100, jamais affiché. L'interface montre un mot : basse, moyenne, haute. |
| **La fenêtre** | Le créneau du jour où une décision tient. Calculé, pas choisi. |
| **La porte** | Le refus. Voir §4. |
| **Le palier** | Où l'on se situe en régularité de sommeil, sur cinq niveaux. |

### Ce que l'application refuse de faire

À traiter comme des exigences, pas des préférences. Chacun a été décidé contre
une alternative plus évidente, et les réintroduire ferait revenir en arrière.

- **Pas de minuteur de 25 minutes**, y compris en option. L'application *était*
  un Pomodoro ; elle a pivoté le 2026-08-22 et tout ce code a été supprimé.
- **Pas de tableau de bord.** Les applications de productivité meurent dans
  leur onglet Statistiques.
- **Pas de pourcentage de capacité.** Un « 74 % » n'est pas justifiable, et
  s'approche d'un diagnostic — ce qui a aussi une portée réglementaire.
- **Pas de série à ne pas briser.** Aucun mécanisme de culpabilisation.
- **Pas d'estimation de durée par un modèle.** L'IA découpe et qualifie ;
  les fourchettes viennent de l'historique personnel.
- **Pas de fil d'actualité, pas de noms, pas de profils.** Les comparaisons
  sont des distributions agrégées.
- **Aucune description de travail ne quitte l'appareil.**
- **Le plan se périme, il ne réprimande pas.** Ce qui n'est pas fait glisse en
  silence.

---

## 2. Où sont les choses

```
ios-native/
  Optium.xcodeproj          projet, ecrit a la main (voir §11)
  Optium.entitlements       HealthKit + groupe d'applications
  OptiumWidgets.entitlements
  OptiumWidgets-Info.plist  la cle NSExtension, qui ne peut pas etre generee

  Optium/                   cible application
    OptiumApp.swift         point d'entree
    RootView.swift          TabView, et le rafraichissement de la clarte
    Model/                  SwiftData + les types de domaine
    Clarity/                le moteur : sommeil, regularite, circadien, bareme
    Home/                   accueil, composeur, reprise, porte, retenu, fermeture
    Journal/                palier, preuves, fils fermes
    Call/                   l'appel au cerveau, la calibration, la memoire
    Settings/
    Brain/                  la scene 3D Metal
    Design/                 aura, cartes, afficheur, echelle
    System/                 notifications, raccourcis, conteneur, ponts
    Resources/              brain.bin, chime.wav, Assets.xcassets

  Shared/                   partage entre l'app et l'extension
    Ink.swift               toutes les couleurs
    BrainSilhouette.swift   le cerveau en 2D
    WidgetSnapshot.swift    ce que l'app laisse aux widgets
    OptiumActivity.swift    l'etat de la Live Activity
    WidgetViews.swift       les vues des widgets

  OptiumWidgets/            extension WidgetKit
  OptiumTests/              69 tests, Swift Testing
```

Ailleurs dans le dépôt :

- `mobile/` — l'ancienne application Expo / React Native. **Périmée**, gardée
  comme référence de comparaison pendant le portage. Son `AGENTS.md` décrit un
  produit qui n'existe plus.
- `docs/superpowers/specs/` — les deux specs (portage Swift, puis la porte).
- `docs/brief-design.md` — le langage visuel, avec les arbitrages tranchés.
- Racine — la toute première version web (Vite + React). Historique.

---

## 3. Le modèle de données

SwiftData. Conteneur partagé dans `System/OptiumContainer.swift` : l'application
**et** les raccourcis Siri l'utilisent, sans quoi ils ouvriraient deux bases qui
divergeraient en silence.

```
Project          id, title, openedAt, closedAt?, colorIndex
                 threads: [WorkThread]                 // cascade

WorkThread       id, phrase, nature, state, createdAt, closedAt?
                 heldUntil?, acceptance?, holdCount
                 project?, resumptions: [Resumption]   // cascade

Resumption       id, startedAt, endedAt?, clarityAtStart, inWindow, thread?

RecordedNight    id, asleepAt, wokeAt, measured
CoffeeIntake     id, takenAt
Calibration      id, askedAt, feltClear, measured
```

**`WorkThread` et non `Thread`** : `Thread` est le type de Foundation.
Le même piège avait déjà imposé `ProjectTask` du temps du Pomodoro.

### La machine à états d'un fil

```
open ──▶ inProgress ──▶ open              (pause)
                    │
                    ├──▶ closed           (clarte suffisante, ou nature != decision)
                    │
                    └──▶ [la porte] ──▶ closed   (une ligne ecrite)
                                    └──▶ held    (jusqu'a la prochaine fenetre)

held ──▶ open   (automatique quand heldUntil est passe, constate a l'ouverture)
```

Un fil retenu se libère de lui-même. Rien ne le notifie et rien ne le reproche.

---

## 4. La porte — la règle centrale

```swift
func closingOutcome(clarity: ClarityLevel) -> ClosingOutcome {
    nature == .decision && clarity == .low ? .gate : .direct
}
```

**Elle s'ouvre pour une décision à clarté basse, et pour rien d'autre.**
`clarity` est optionnelle : sans mesure, la porte reste fermée — un refus sans
preuve est pire qu'une absence de refus.

Quand elle s'ouvre, `GateJustification` cite le fait mesuré dont le manque pèse
le plus : `poids × (1 − valeur normalisée)`. Un fait vérifiable dans Santé, pas
un score. Un seul, sauf si le deuxième est à moins de 15 % du premier ; jamais
trois.

### Ce qu'elle défend

Le récit courant veut que le fatigué se croie performant. **Il est faux, et
c'est vérifié** : la revue systématique et méta-analyse de Bermudez et coll.
(*Sleep Medicine Reviews*, 2021 — 28 études retenues, 11 exploitables) trouve
que les participants privés de sommeil donnent typiquement des estimations
**plus conservatrices** de leur performance. Une revue distincte
(*Metacognition and Learning*, 2017) ne trouve pas d'effet sur les jugements de
confiance.

Ce qui se dégrade de façon constante, c'est la **détection de ses propres
erreurs**. La formulation à retenir, et la seule qui soit soutenue :

> **On ne devient pas aveugle à sa fatigue. On devient moins capable
> d'attraper ses propres erreurs.**

**C'est un argument plus fort pour la porte, pas plus faible.** Si l'utilisateur
ignorait simplement qu'il est fatigué, une notification suffirait. Le problème
est qu'il peut parfaitement le savoir et rater l'erreur quand même — savoir ne
suffit pas, il faut une interruption au moment de conclure.

Conséquence à tenir dans tout le texte affiché : aucune formulation du type
« tu ne remarques plus que tu te trompes ». La première est contredite, la
seconde — « tu attrapes moins tes propres erreurs » — est soutenue. Les phrases
de calibration ne désignent d'ailleurs plus aucun des deux sens de l'écart
comme le plus trompeur ; voir `CalibrationSummary`.

Sa rareté est ce qui la rend acceptable. Élargir cette condition la
transformerait en friction ordinaire, et l'application perdrait la seule chose
qu'elle sait faire. Six tests couvrent les trois natures × les trois niveaux —
**ne pas les affaiblir.**

Deux issues, et aucune n'est un abandon : fermer en écrivant ce qu'on accepte
(la ligne est obligatoire, `closeThroughGate` renvoie `false` sans elle), ou
retenir jusqu'à la prochaine fenêtre.

L'écran de la porte est **le seul en plein cadre, sans carte**. Cette rupture
visuelle est le message : tout le reste de l'application renseigne, celui-là
arrête.

---

## 5. Le moteur de clarté

`Clarity/ClarityEngine.swift`.

```
clarte = 0.5 * rang_de_regularite  // rang de population du SRI sur 28 jours
       + 0.3 * duree               // ecart a la cible, penalise DANS LES DEUX SENS
       + 0.2 * circadien           // deux processus, phase apprise des levers reels
```

Seuils : `basse < 42 ≤ moyenne < 70 ≤ haute`.

**Les poids sont ronds, et c'est délibéré.** Ils valaient 0,45 / 0,30 / 0,25 :
ces décimales annonçaient une calibration qui n'existe pas, et la fausse
précision est ce qui décrédibilise une heuristique. Ne pas les « affiner » sans
données pour le justifier.
**La valeur numérique n'est jamais affichée.**

**`ClarityReading.clarity` est optionnelle.** Sous `minimumNights` — trois —
elle vaut `nil`, et non pas « moyenne par défaut » : une valeur inventée se
propagerait dans le cerveau, dans les widgets et jusqu'à la porte, où elle
produirait un refus injustifiable. Le seuil est bas parce que les sources
rendent leur historique dès la première seconde : HealthKit sur des mois,
CoreMotion sur sept jours. Attendre deux semaines rendait l'application muette
alors que la mesure existait.

### Ce qui fonde la pondération

La méta-analyse de Lim & Dinges (2010, *Psychological Bulletin* 136, 375-389 —
70 articles, 147 tests) trouve les tailles d'effet les plus grandes sur les
lapsus d'attention simple, et les plus faibles, non significatives, sur
l'exactitude du raisonnement. **Optium mesure donc un proxy de vigilance, pas
d'intelligence.**

**La formule n'est pas validée.** Elle n'a été calibrée sur personne. À traiter
comme une hypothèse instrumentée.

La pondération d'origine réservait 40 % aux bascules entre applications. Ce
signal a été **abandonné** : voir §10.

### L'indice de régularité (SRI)

`Clarity/Night.swift`. La probabilité, en pourcentage, d'être dans le même état
à deux instants séparés de 24 h. Pas de cinq minutes.

Référence : Windred et al., *Sleep* (2023), doi 10.1093/sleep/zsad253 —
60 977 participants de la UK Biobank, médiane 81, IQR 73,8-86,3. La régularité y
prédit mieux la mortalité que la durée.

**Piège corrigé** : la grille part du premier endormissement, pas de minuit. Les
heures non observées comptaient comme des désaccords, et une personne
parfaitement régulière ne pouvait pas atteindre 100.

**Piège corrigé, et il faussait toute la distribution** : le SRI brut entrait
dans la somme pondérée comme s'il s'agissait d'un pourcentage. Son échelle
utile est bien plus étroite — la moitié de la UK Biobank tient entre 73,8 et
86,3. Un indice de 68, qui désigne le cinquième le moins régulier de la
population, valait donc « 68 sur 100 ». Résultat : un profil se couchant entre
19 h et 3 h avec des nuits de 4 à 7 h ressortait en **clarté haute**.

`SleepRegularity.populationScore` rend à l'indice son rang, en s'appuyant sur
les quartiles publiés — 73,8 / 81 / 86,3 placés à 25, 50 et 75. Seules les
bornes, 60 et 95, sont décidées. `ClarityReading.regularity` continue d'exposer
le SRI brut : c'est la grandeur de la littérature, et l'affichage doit rester
vérifiable.

`OptiumTests/DistributionTests.swift` épingle cette distribution — que les trois
niveaux restent atteignables, et qu'un couchage errant ne ressorte jamais haut.
**C'est le test à lancer avant de toucher à un poids ou à un seuil.**

### La durée

**Pénalisée dans les deux sens** — la relation durée/mortalité est en U.

**Piège corrigé, et c'est le plus important du moteur** : la cible était la
seule médiane personnelle. Quelqu'un qui dort chroniquement cinq heures voyait
sa médiane s'aligner dessus et obtenait toujours un bon score — exactement le
piège que l'application cherche à nommer. La médiane informe désormais une
cible **bornée à 7-9 heures**.

### Le circadien

`Clarity/CircadianModel.swift`. Modèle à deux processus de Borbély réduit :
pression homéostatique saturante plus oscillation sur 24 h.

**Le chronotype est appris des heures de lever réelles**, par moyenne
circulaire — additionner 23 h et 1 h donnerait midi. Jamais supposé.

La fenêtre s'ouvre deux heures après le lever habituel et dure 2 h 40.

**C'est la composante la moins établie des trois, et son poids le dit.** L'effet
de synchronie — mieux performer à l'heure qui correspond à son chronotype — est
largement admis et soutenu par plusieurs travaux sur la fonction exécutive,
**mais il est contesté** : un article de *Collabra: Psychology* (2023) conclut à
l'absence de gain cognitif général et robuste issu du croisement heure du jour ×
chronotype, et évoque la possibilité d'un artéfact méthodologique. C'est la
raison pour laquelle son poids est descendu de 0,25 à 0,2, au profit de la
régularité, qui est la mieux tenue.

### Le café

**Modificateur, pas composante.** Une prise à moins de huit heures du coucher
visé abaisse la nuit projetée, donc la clarté de **demain**. Jamais celle
d'aujourd'hui : c'est ce qui en fait un enseignement plutôt qu'une punition.
Demi-vie de cinq heures, seuil à huit heures.

### Les sources de sommeil

`HealthSleepSource` (principale) et `MotionSleepSource` (repli), combinées par
`CompositeSleepSource`. Le mouvement ne comble que les nuits absentes du
mesuré ; il ne le corrige jamais.

### Reconstituer une nuit depuis Santé

Quatre défauts corrigés ensemble, parce qu'ils se cumulaient et donnaient des
nuits qui n'étaient pas les bonnes.

1. **L'amplitude n'est pas la durée.** `Night.duration` valait `wokeAt −
   asleepAt`. Une nuit arrive de Santé en dizaines de fragments ; se réveiller
   quarante minutes à 3 h laisse un trou que le recollage franchit, et ce trou
   était compté comme du sommeil. `Night` porte désormais `measuredSleep`
   (le sommeil réel, qui alimente le score) à côté de `span` (du coucher au
   lever, qui situe la nuit et alimente la régularité).
2. **Deux sources doublaient la nuit.** Une montre et un iPhone enregistrent la
   même nuit ; leurs échantillons se recouvrent. `HealthSleepSource.union(of:)`
   fusionne les intervalles au lieu de les additionner — le résultat ne dépend
   ni du nombre de sources ni de l'ordre.
3. **Une sieste devenait une nuit.** Un épisode de l'après-midi remonte de
   Santé comme les autres. `longestPerDay(_:)` ne garde que le plus long par
   jour de lever.
4. **Une nuit mal lue l'était pour toujours.** `ClarityStore.record` appliquait
   « la première lecture fait foi ». L'intention était juste — une source qui se
   contredit ne doit pas faire bouger l'historique — mais l'effet était un
   piège. Une nuit mesurée remplace désormais une nuit déduite, et une nuit
   mesurée en remplace une autre si elle diffère. **Une nuit déduite ne
   remplace jamais rien** : le mouvement ne corrige pas la mesure.

Réglages → **« Relire toutes mes nuits »** efface les enregistrements et
redemande tout à Santé. Rien d'irrécupérable n'est détruit : la source est
ailleurs.

### Corriger une nuit — décision renversée

`AGENTS.md` a longtemps porté : « elle ne se corrige pas ici, et c'est
délibéré — laisser modifier une nuit ferait de l'historique une déclaration ».

**Le raisonnement était incomplet et la décision a été renversée.** Une montre
se retire la nuit, se décharge, ou date le lever d'un réveil bref à 5 h ;
l'utilisateur est alors le seul à savoir. Refuser la correction ne protège pas
la mesure — elle construit tout le produit sur une mesure fausse que personne
ne peut rattraper.

Ce qui reste du principe, et qui ne bouge pas : **on ne demande jamais.**
L'application n'ouvre pas l'éditeur d'elle-même, ne relance sur rien, ne
signale aucune nuit « à vérifier ». La saisie reste possible, elle n'est jamais
attendue.

`Night.Origin.corrected` prime sur `.measured` et `.inferred`. **Aucune
relecture n'écrase une correction** — sans cette garantie, corriger puis voir
la valeur fausse revenir découragerait pour de bon. `originalWokeAt` et
`originalAsleepAt` conservent ce que la source annonçait, ce qui permet de
revenir en arrière et surtout d'apprendre.

### Ce que les corrections apprennent

`Clarity/SleepBias.swift`. Corriger une nuit répare cette nuit-là ; corriger
quatre fois dans le même sens dit que la source se trompe **systématiquement**,
et de combien.

**Le biais n'est jamais appliqué en silence.** Il est calculé, montré, et rien
d'autre. Un décalage appliqué automatiquement fabriquerait des nuits que
personne n'a mesurées ni validées — exactement ce que le moteur s'interdit en
rendant la clarté optionnelle plutôt qu'en inventant une valeur par défaut.

Médiane et non moyenne : une nuit oubliée puis rattrapée de six heures
déplacerait une moyenne pour toujours. Seuil de signalement à dix minutes,
soit l'ordre de grandeur de l'imprécision de la mesure elle-même.

### La provenance d'une nuit

`Night.Origin` : `measured` (Santé) ou `inferred` (mouvement du téléphone).

**Ce n'est pas cosmétique, ça décide de ce que l'application a le droit
d'affirmer.** La règle du projet est de n'afficher que des faits vérifiables
par l'utilisateur — « tu as dormi 5 h 10 » se contrôle dans Santé. Une nuit
déduite du mouvement **ne s'y contrôle pas**.

**Défaut corrigé, et c'était le plus grave du produit** : `CompositeSleepSource`
fusionnait les deux sources et `ClarityStore` enregistrait tout avec
`measured: true`. Le champ existait, était écrit, et était **faux** — jamais
affiché nulle part, personne ne pouvait s'en apercevoir. L'application
annonçait donc « clarté basse », et refusait des décisions à la porte, à partir
de nuits déduites de l'accéléromètre que l'utilisateur n'avait aucun moyen de
consulter. Une affirmation sans recours n'est pas une mesure.

Trois conséquences tenues par des tests :

- `ClarityReading.inferredNights` et `restsOnInference` existent pour que
  l'affichage puisse le dire.
- La légende de l'accueil écrit « Nuit déduite » plutôt que « Nuit », et la
  porte ajoute « d'après le mouvement de ton téléphone, faute de sommeil
  enregistré ». **On ne s'excuse pas et on ne relativise pas le refus** — on
  nomme sa source, ce qui le rend contestable, donc acceptable.
- `NightsScreen` liste chaque nuit avec sa provenance. **Elle ne s'y corrige
  pas** : laisser modifier une nuit ferait de l'historique une déclaration, et
  toute la promesse tient à ce qu'Optium mesure au lieu de demander. Ce qui est
  faux se corrige dans Santé.

**Aucune composante du moteur ne doit jamais reposer sur les STADES de
sommeil.** Les validations 2024 contre polysomnographie donnent, pour les
montres grand public : sommeil contre éveil au-dessus de 95 % de sensibilité,
durée totale à ± 12 minutes environ, sommeil paradoxal ≈ 82 % — mais **sommeil
profond entre 50 et 64 % seulement**.

Optium ne lit que `asleepAt` et `wokeAt`, c'est-à-dire précisément ce que ces
appareils mesurent bien. `HealthSleepSource` inspecte bien les quatre valeurs de
stade, mais pour une seule chose : établir que la personne dort. **Leur identité
n'est jamais exploitée.** Introduire une « durée de sommeil profond » ou un
score de qualité fondé sur les stades reviendrait à bâtir sur la seule partie
non fiable de la mesure. Ne pas le faire.

L'erreur de ± 12 minutes sur la durée se propage en revanche dans l'indice de
régularité ; la médiane glissante sur 28 jours l'amortit, et c'est une des
raisons de la conserver.

**Aucune ne tourne en arrière-plan.** iOS suspend l'application, et « observer
l'usage du téléphone » n'est pas un mode autorisé. On interroge l'**historique**
— sept jours pour CoreMotion — à l'ouverture.

`SleepInference` transforme des périodes d'immobilité en nuits : plus long
segment nocturne, endormissement entre 18 h et 6 h, durée entre 3 h et 14 h.
Au-delà de 14 h ce n'est plus quelqu'un qui dort, c'est un téléphone oublié —
**le compter comme une nuit parfaite récompenserait l'absence de données.**

**Les nuits sont conservées** (`RecordedNight`) parce que CoreMotion n'en garde
que sept quand le SRI en demande vingt-huit. Sans accumulation la mesure ne
mûrirait jamais.

**Limite à dire à l'utilisateur** : le téléphone doit passer la nuit près de
lui. Chargé dans une autre pièce, il n'y a pas de signal.

---

## 6. Le barème

`Clarity/Tier.swift` et `Clarity/Proof.swift`.

| Palier | Seuil SRI | Part | Remplissage de l'emblème |
|---|---|---|---|
| Cristallin | > 87 | 14 % | 0,96 |
| Limpide | 82-87 | 23 % | 0,80 |
| Net | 76-82 | 26 % | 0,60 |
| Voilé | 68-76 | 22 % | 0,38 |
| Trouble | < 68 | 15 % | 0,16 |

Ancré sur la UK Biobank tant que la population d'Optium est insuffisante : c'est
ce qui résout le démarrage à froid. Calculé sur une **médiane glissante de
28 jours** — on n'y monte pas par gavage, et on redescend en cas d'arrêt.

**L'emblème est le cerveau lui-même**, à un remplissage croissant. Pas de
médaille.

Six preuves : Retenue, Fenêtre, Traversée, Régulier, Matin, Sobriété.
**Toutes récompensent la retenue, jamais le volume** — un test ferme cinquante
fils à la chaîne sans rien débloquer, et il doit rester vrai.

Les comparaisons sociales obéissent à trois règles absolues : jamais de
personnes, jamais le volume, et seulement les trois mesures réellement
comparables.

---

### Les projets

Un projet groupe des fils. **Il n'a pas d'écran** : « Aujourd'hui » range les
fils ouverts sous un en-tête portant la pastille et le nom du projet, les fils
sans projet fermant la marche. L'application n'a que deux niveaux de
navigation, et un troisième pour ranger des dossiers serait payer cher une
commodité.

L'ordre des groupes suit la première apparition d'un de leurs fils, jamais le
titre ni la date : la liste ne doit pas se réorganiser sous les yeux de
quelqu'un qui ferme un fil.

`Project.closedAt` est déclaré et **n'est ni écrit ni lu** : on ne peut pas
encore fermer un projet. À faire ou à supprimer, pas à laisser en l'état.

**`ProjectMemory` a été en écriture seule pendant tout le développement.** Une
ligne markdown s'écrivait à chaque fil fermé, et `CallScreen` passait `memory:
""` au modèle — le fichier grossissait sans que rien ne l'ouvre. L'appel porte
désormais un sélecteur de périmètre et lit la mémoire correspondante, bornée
aux vingt-quatre dernières lignes : la fenêtre du modèle sur appareil est
étroite, et un fichier de deux ans y chasserait les faits mesurés.

**Piège restant** : la mémoire est indexée sur le slug du titre. Renommer un
projet l'orphelinerait. Il n'y a pas de renommage aujourd'hui ; en ajouter un
oblige à migrer le fichier.

---

## 7. Les écrans

Deux onglets. La barre d'onglets est **conservée** — voir §12 pour pourquoi
elle avait failli sauter.

**Aujourd'hui** — le cerveau 3D, un mot pour la clarté, la fenêtre en
graduations, le café, la calibration, l'atterrissage, les fils ouverts.

**Où tu en es** — le palier avec son emblème, les six preuves, les fils fermés.
Existe, mais n'est pas une destination : rien n'y pousse.

Présentés par-dessus : le composeur de fil, la reprise, la porte, la retenue,
la fermeture, l'appel, les réglages.

---

### La voix du cerveau

**Il parle à la première personne, et ça a demandé plus qu'une consigne.** Les
trois questions proposées sont écrites au « je » de l'utilisateur — « qu'est-ce
que j'ai appris sur ma façon de travailler ». Le pronom étant pris, un modèle à
qui l'on demande par ailleurs de dire « je » pour lui-même tranchait la
collision en se rabattant sur « tu ».

Deux corrections, toutes deux nécessaires :

- Les faits du prompt sont énoncés comme les siens — « ma régularité : 81 » et
  non « régularité du sommeil : 81 ». Formulés au tiers neutre, ils invitaient
  à les rapporter.
- Les instructions lèvent explicitement l'ambiguïté des deux « je » et portent
  des exemples de refus.

`OptiumTests/BrainVoiceTests.swift` fixe la règle. **Ne pas reformuler les faits
au tiers neutre** : c'est le levier qui compte, pas la consigne.

---

### L'appel : outils, scène, voix

`BrainCall.prompt()` empilait tout — douze fils fermés, tous les fils ouverts,
la régularité, la clarté. **Quatre outils l'ont remplacé** (`BrainTools.swift`)
et le prompt tient désormais sous 700 caractères, ce qu'un test vérifie.

Le gain qui compte n'est pas la fenêtre de contexte : c'est que **chaque
affirmation du modèle correspond à une consultation datée**, et que l'outil
publie ce qu'il a trouvé pour que l'écran le montre pendant que la voix en
parle. La première règle des instructions dit qu'un modèle qui rappelle est
vérifiable ; l'afficher transforme la promesse en démonstration.

**Une seule chose à l'écran à la fois** (`CallStage`). Un empilement
reconstituerait le fil de messages que l'appel s'interdit.

`Voice.swift` tient la chaîne, entièrement locale : `SpeechTranscriber` avec
modèle exigé en local — jamais de bascule silencieuse — puis
`AVSpeechSynthesizer`. **Appui maintenu**, pas de détection de silence.

`VoiceTests` interdit la régression sur la confidentialité : aucune entité
SwiftData ni clé de réglages ne peut porter une transcription. **Ne pas
affaiblir ces tests** — c'est la seule chose qui empêche « garder la dernière
réponse » d'arriver un jour par inadvertance.

`CallAura` déborde aux bords via `ConcentricRectangle`. **Ne pas imiter le halo
de Siri** : confusion sur qui parle, et une revue App Store peut le relever.

---

## 8. Le cerveau

Deux représentations du **même objet**, et elles doivent le rester.

**En 3D** (`Brain/`) — Metal, `MTKView` dans `UIViewRepresentable`. Maillage
unique de 76 143 sommets, pré-calculé par `mobile/scripts/bake_brain.py` en
`brain.bin` : signature `OPTB`, bornes, positions, normales, indices. Aucun
décodage au démarrage.

Quatre paramètres pilotent tout : `fill` (la clarté), `base` (le plafond permis
par la nuit, en pointillés), `agitation` (le nombre de fils ouverts), `isDay`.

Trois choix de rendu, **à ne pas annuler sans mesure** :
- **pas de `discard`** — les GPU à tuiles des iPhone désactivent l'élimination
  anticipée de profondeur pour tout le maillage dès qu'un shader peut rejeter
  un fragment ; on module l'alpha ;
- **verre en Fresnel**, pas de transmission — celle-ci imposerait une passe de
  rendu par image et une carte d'environnement ;
- **rendu suspendu hors écran** (`isPaused`), densité plafonnée à 2.

Le niveau s'interpole sur ~900 ms, la surface respire en continu (périodes
4,1 s et 6,7 s), rien d'autre ne bouge à l'écran.

**En 2D** (`Shared/BrainSilhouette.swift`) — 59 points extraits du vrai
maillage. Obligatoire pour les widgets et la Live Activity : **Metal ne tourne
pas dans un widget**, qui ne rend qu'une image fixe.

Variante petite taille en dessous de 40 pt : contour renforcé, pas de ligne de
base.

---

## 9. Les surfaces système

Les widgets d'accueil affichent une **capture du rendu Metal**, produite hors
écran par l'application (`Brain/BrainSnapshot.swift`) et déposée dans le
conteneur du groupe. Les familles `accessory*` gardent la silhouette
vectorielle : elles sont rendues en masque teinté, où une image en couleurs
serait aplatie. La capture se périme au-delà de 0,03 d'écart de remplissage ou
de six heures, et le repli vers la silhouette est silencieux.

**Deux widgets** (`OptiumWidgets/`) — clarté en quatre familles (verrouillé
circulaire et rectangulaire, accueil petit et moyen) et fil en cours.
**Image fixe, jamais animée.** Chronologie d'une heure.

Ils lisent un **instantané** (`WidgetSnapshot`) écrit par l'application dans le
groupe d'applications, pas la base : ils n'ont pas besoin de savoir calculer
une clarté, seulement de l'afficher.

**Live Activity** — écran verrouillé et Dynamic Island, trois états. Démarre à
l'ouverture d'une reprise, se termine à la pause, à la fermeture ou à la
retenue.

**Jamais « Fermer le fil » depuis l'île** : la porte reste dans l'application.

**Trois raccourcis Siri** (`System/Intents.swift`), dont **aucun n'ouvre
l'application** : demander la clarté, ouvrir un fil, retenir une décision.

**Exactement deux notifications**, et il n'y en aura pas d'autres : le matin
30 min avant l'ouverture de la fenêtre, le soir 90 min avant le coucher visé.
Jamais pendant un fil. La porte n'est pas une notification.

---

## 10. Faits de plateforme vérifiés

Chacun a été établi par un vrai build signé, pas supposé.

| Fait | État |
|---|---|
| Habilitation **HealthKit** | ✅ passe avec un compte Apple **gratuit** |
| `com.apple.developer.healthkit.access` (dossiers médicaux) | ❌ refusée — et inutile ici |
| **Groupe d'applications** | ✅ passe avec un compte gratuit |
| **Family Controls / DeviceActivity** | ❌ non utilisé — approbation manuelle d'Apple requise, et le rapport tourne dans une extension murée qui ne peut rien renvoyer à l'app |
| **Metal dans un widget** | ❌ impossible, pas de contexte graphique |
| **Animation continue en Live Activity** | ❌ ActivityKit ne fait pas tourner de boucle ; le contenu se met à jour par envois espacés que le système plafonne |
| `INFOPLIST_KEY_NSExtensionPointIdentifier` | ❌ n'existe pas ; il faut un vrai `Info.plist` partiel |
| Installation sur appareil | ✅ app + extension signent ; **expire au bout de 7 jours** (compte gratuit) |

---

## 11. Le projet Xcode

**Écrit à la main.** Trois cibles : `Optium`, `OptiumWidgets`
(`app-extension`), `OptiumTests`.

Les dossiers sont des **`PBXFileSystemSynchronizedRootGroup`** : un fichier
`.swift` posé sur le disque apparaît dans Xcode sans qu'on touche au
`project.pbxproj`. `Shared/` est référencé par les deux cibles.

**Ne modifier `project.pbxproj` que pour un réglage de compilation ou une
cible.** Jamais pour ajouter un fichier.

Après toute modification : `plutil -lint Optium.xcodeproj/project.pbxproj`.

---

## 12. Décisions qui ont été rouvertes, et leur conclusion

Les noter évite qu'on les rejoue.

**La barre d'onglets.** Elle avait failli être supprimée, sur une lecture
littérale de « le journal n'est pas une destination ». C'est une contrainte de
**produit** — n'en fais pas une boucle d'habitude — pas de navigation. Et
iOS 26 vient de réinvestir la barre d'onglets : Liquid Glass, minimisation au
défilement. **Elle reste.**

**La variété des couleurs.** Une passe l'avait supprimée au motif que
l'arc-en-ciel fait « généré ». C'était à moitié faux : ce n'est pas la variété
qui trahit, ce sont des teintes **sans parenté**. Six teintes au même registre
de saturation et de valeur se lisent comme une famille. **La variété est
revenue.**

**La trame de points sur le fond.** Implémentée d'après une référence, regardée
en fonctionnement, **retirée** : elle salissait le noir. Un document de design
la spécifie ; l'arbitrage sur le rendu réel l'emporte.

**Les chiffres en matrice de points.** Un document de design prévoit des
chiffres fins ; ils sont **conservés** comme signature.

---

## 11 bis. Le chargement, et le régime du cerveau

**Une application qui lit des données doit se voir lire.** Sans état de
chargement, une lecture instantanée et une lecture qui échoue se ressemblent :
dans les deux cas rien ne bouge.

Trois surfaces le portent, et aucune n'est un indicateur système générique :

- **Le cerveau change de régime.** `BrainRenderer.effort` (0…1) accélère la
  rotation, amplifie le flottement et agite le fluide. La rotation de repos est
  passée de 0,3 à 0,52 radian/s — à 0,3 il fallait vingt secondes pour un tour,
  et l'œil lisait un objet fixe.
- **`ReadingBanner`** nomme ce qui est lu. « Chargement… » n'apprend rien.
- **`SkeletonBar`** tient la place du mot de clarté — **jamais un mot inventé**,
  ce serait une valeur affichée qui n'a jamais été mesurée.

Un tirage vers le bas relance la lecture sur l'accueil et sur l'écran des
nuits : rien ne permettait de la relancer après une correction dans Santé.

---

## 11 ter. La barre d'onglets, et l'île

**La barre est dessinée, pas celle du système.** Aucune API ne permet de
l'aligner à gauche : `TabBarPlacement` ne propose que `topBar`, `bottomBar` et
`sidebar` — cette dernière réservée aux dispositions adaptatives de l'iPad. La
barre flottante d'iOS 26 est centrée, sans réglage.

Le `TabView` est conservé pour ce qu'il fait bien : la sélection, l'état de
chaque onglet, la pile de navigation propre à chacun. Seule sa barre est
masquée. **Le masquage se pose sur le contenu de chaque `Tab`, jamais sur le
`TabView`** — appliqué à celui-ci il est ignoré en silence, et la barre système
reste visible derrière la nôtre.

**Ce n'est pas une pratique recommandée.** Les HIG demandent une barre
standard. C'est un écart assumé, à la demande explicite du propriétaire du
produit — pas un choix à reproduire ailleurs sans raison.

Ce qu'on perd : la réduction automatique au défilement d'iOS 26 et le rendu par
défaut des badges.

Une première version ne montrait le libellé que sur l'onglet courant, au motif
que deux libellés reconstituent la largeur d'une barre centrée. **C'était payer
la lisibilité pour un effet** : l'onglet inactif devenait une icône seule à
45 % d'opacité, moins identifiable que dans la barre du système. Les deux
libellés sont revenus, et l'inactif est à 72 %. L'alignement ne vaut pas une
régression d'usage.

### L'île dynamique

**La forme repliée montre le temps écoulé, pas le mot de clarté.** C'est elle
qui s'affiche quand on quitte l'application : y mettre un mot qu'on vient de
lire dans l'app, au lieu de la seule chose qui bouge, la rendait inutile. La
clarté reste présente — c'est le remplissage du cerveau, à gauche.

**Les chiffres de l'app suivent ceux de l'île, jamais l'inverse.** Une activité
en direct ne peut pas exécuter de code à chaque seconde : elle n'a que le style
de minuterie du système, qui rend `7:42` puis `1:07:42`. L'app affichait
`07:42`. C'est `ResumptionFlow.elapsed(at:)` qui s'est aligné.

---

## 12. L'annulation

`System/ActionLog.swift`, `Design/UndoBar.swift`, et une ligne dans
`OptiumContainer`.

**Cette ligne est le mécanisme entier** : SwiftData enregistre insertions,
suppressions et modifications pour l'annulation, mais seulement si le contexte
porte un `UndoManager`, et il n'en a aucun par défaut.

`ActionLog` ne conserve pas l'action — il conserve **la phrase qui la nomme**.
Un mécanisme que rien n'annonce n'existe pas pour l'utilisateur, et « Annuler »
seul oblige à se rappeler ce qu'on vient de faire, ce qui est exactement la
faculté qui manque au moment où l'on se trompe.

La bande s'efface après six secondes : une commande permanente en bas d'écran
devient un élément de décor, donc invisible.

**Aucune confirmation avant une suppression.** Un dialogue punit les mille fois
où l'on ne se trompe pas ; l'annulation après coup ne coûte rien à personne.

Les extensions — widgets, intentions — construisent leur propre `ModelContext`
et n'héritent donc pas de l'annulation. C'est voulu : une action lancée depuis
l'écran verrouillé n'a pas d'écran où offrir de la défaire.

Un fil se modifie par appui long → **le même écran que la création**
(`ThreadComposer(editing:)`). Un formulaire d'édition séparé finirait par
diverger. La date de création ne bouge jamais : elle sert aux preuves et aux
nuits traversées.

---

## 12 bis. Le tactile, le son, le mouvement

Trois fichiers, trois vocabulaires. Le point commun : **on nomme des moments,
jamais des intensités.** Un appelant qui écrit `impact(.medium)` décide d'une
sensation ; un appelant qui écrit `.threadClosed` décide d'un sens, et la
sensation se règle en un seul endroit.

**Les générateurs sont retenus, et c'était le bug.** Ils étaient créés en
variables locales — `UIImpactFeedbackGenerator(style:)`, `prepare()`,
`impactOccurred()` — puis relâchés dans la foulée. Un générateur libéré avant
que le moteur ait joué ne produit rien : la plupart des gestes étaient muets
alors que le code les appelait bien. Ne pas revenir à des générateurs locaux.

- **`Shared/Feedback.swift`** — neuf moments, dont le cerveau qu'on fait
  tourner : des crans, pas une vibration continue. La main lit une molette, et
  un bourdonnement pendant tout le geste fatiguerait en trois secondes. La porte a un motif Core Haptics
  écrit à la main : deux frappes sourdes puis un appui tenu. **Pas le motif
  système `.error`** — il est sec et se lit comme une faute, alors que la porte
  ne reproche rien, elle interrompt.
- **`Shared/Chime.swift`** — deux sons, **synthétisés**, aucun fichier
  embarqué. La session audio est en `.ambient` : elle laisse la musique jouer
  et **respecte l'interrupteur silencieux**. Coupé par défaut.
- **`Optium/Design/Motion.swift`** — trois courbes. Celle de la porte est plus
  lente que les autres : une interruption qui arrive vite se lit comme un refus
  sec.

**Le réglage « Vibrations » a existé pendant tout le développement sans être
branché à quoi que ce soit** : il s'écrivait dans `UserDefaults` et aucun code
ne le lisait. `Feedback.isEnabled` et `Chime.isEnabled` sont renseignés depuis
`RootView` et constituent la seule porte d'entrée.

Tout le mouvement doit pouvoir être coupé sans qu'une seule chose devienne
incompréhensible — c'est ce qui rend `accessibilityReduceMotion` tenable plutôt
qu'un mode dégradé.

---

## 13. Le langage visuel

### Deux représentations du cerveau, et une seule règle

- **En volume, en Metal** : l'écran Session, la porte, la reprise, l'appel, et
  la carte « Ton palier ». Partout où l'organe est le sujet.
- **`BrainMark`**, le symbole `brain` d'Apple masquant un dégradé qui monte du
  bas : l'échelle des paliers, tous les widgets, l'île dynamique, l'écran
  verrouillé. Partout où il est un repère.

`BrainSilhouette`, un contour extrait du maillage, tenait le second rôle. Il
était fidèle mais dessiné pour être vu grand, et à vingt-deux points il se
refermait en tache. **Il a été supprimé, pas gardé en réserve** : deux tracés du
même organe finissent par diverger.

Le niveau se mesure sur les proportions du glyphe, jamais sur le cadre — dans un
carré, `murky` à 0,16 tomberait sous le dessin et n'allumerait rien.

### Une seule couleur par carte

Une teinte, et rien d'autre : elle se diffuse, s'éteint vers le noir, se
rallume sur une arête — **elle ne rencontre jamais une autre couleur.** C'est
ce fondu d'un ton unique qui laisse le texte lisible ; deux tons qui se
croisent produisent au milieu une valeur qu'on ne contrôle plus, et là où passe
une ligne de texte, ça se paye.

Une contre-teinte a été essayée — un ton étranger posé en bas de carte — pour
rendre les cartes plus vives. Elle les rendait surtout multicolores et changeait
la direction artistique. **Retirée.**

**La règle est tenue par construction, pas par discipline** : `CardHue.accent`
n'est pas une seconde couleur qu'on choisit, c'est `tint` éclaircie en
teinte-saturation-luminosité. `HueTests` vérifie que teinte et accent ont la
même teinte à 0,02 près, et que `lightened(by:)` ne dérive jamais.

Une seule couleur *par carte* ne veut pas dire une seule couleur dans
l'application : les six teintes restent sans parenté, et un test le vérifie
aussi.

Même règle pour `BrainMark` : le remplissage montait d'un violet vers un jaune,
soit deux couleurs dans un objet de vingt-six points. C'est désormais le même
ton, assombri en bas.

### Les modules d'analyse

`Clarity/NightInsights.swift` (le calcul, pur et testé) et
`Home/NightModules.swift` (les vues). Assemblés dans `NightsScreen`, au-dessus
de la liste.

**L'application refuse d'être un tableau de bord**, et le garde-fou contre
l'orthosomnie interdit de faire du sommeil une performance à optimiser. Ces
modules existent quand même, parce qu'un verdict sans données consultables
n'est pas une mesure. Trois règles les tiennent, à ne pas relâcher :

1. **Aucune projection.** On ne montre que ce qui a eu lieu.
2. **Aucune note, aucun score global, aucune série à ne pas briser.**
3. **Chaque module dit ce qu'il ne peut pas dire**, et cette phrase est un
   champ obligatoire du type `NightModule` — pas une convention.

Cinq modules :

| Module | Ce qu'il montre | Sa limite déclarée |
|---|---|---|
| L'empreinte | actogramme, une ligne par nuit | ne dit pas si c'est bien |
| Tes levers | dispersion autour de la médiane | la médiane n'est pas une cible |
| Les durées | 28 nuits et la bande 7–9 h | la relation est en U, pas un plancher |
| Décalage social | milieu de nuit semaine / week-end | samedi-dimanche présumés libres |
| Le café | deux médianes côte à côte | une différence n'est pas une cause |

**L'axe de l'actogramme part de 18 h, pas de minuit.** Sur un axe de minuit,
une nuit ordinaire se coupe en deux fragments aux extrémités et l'œil ne voit
plus une nuit mais deux morceaux. Décalée, elle tient d'un seul tenant et c'est
la dérive du bloc qu'on lit — c'est-à-dire exactement ce que le SRI mesure,
rendu visible.

Le module café est le seul qui relie deux choses, et il ne conclut rien : deux
barres, **jamais une flèche**. Une flèche dirait une cause, or les jours à café
tardif sont souvent les jours chargés.

### La bande des nuits

`Home/NightsStrip.swift`, sous le mot de la clarté.

**Le lien entre la clarté et ses nuits était dans le calcul, jamais à
l'écran.** Un mot — « haute », « basse » — apparaissait seul. Un verdict dont
la cause se trouve ailleurs se subit ; posé à côté de sa cause, il s'examine.

Des barres, pas des chiffres : sept durées alignées se comparent d'un coup
d'œil. Ce n'est pas un graphique de statistiques — ni axe, ni échelle chiffrée,
ni moyenne. Les barres sont **étroites et à largeur fixe** : étalées sur toute
la largeur, elles se lisaient comme des pastilles alignées et les différences
de durée disparaissaient.

Ce qui distingue une nuit déduite est son **opacité**, jamais sa teinte : un
second ton casserait la règle ci-dessus et ferait passer la déduction pour une
catégorie de sommeil.

### Les cartes

Détail complet dans `docs/brief-design.md`. L'essentiel :

- **Noir vrai permanent.** L'application ne suit pas l'apparence d'iOS.
- **Liquid Glass partout** : `glassEffect`, `GlassEffectContainer`,
  `buttonStyle(.glass)`. Choix explicite, pas un placeholder.
- **Les contrôles restent ceux du système** — un `Toggle` redessiné perdrait le
  retour haptique, l'accessibilité et les animations d'Apple.
- **Cartes** : remplies bord à bord avec un **cœur sombre** décalé sous le
  centre, arête supérieure rallumée, second foyer décalé, flou 22, clipé.
  La recette exacte est dans `Design/BentoCard.swift`.
- **Hiérarchie par la valeur**, jamais par la teinte : une carte secondaire est
  plus sombre, pas d'une autre couleur.
- **`#D6E85D` est la seule couleur franche** hors cartes. Elle ne signale que le
  présent. Jamais décorative.
- **Commandes en blanc** : `buttonStyle(.glass)` prend sa couleur de libellé
  dans le teint ambiant, qu'un `foregroundStyle` posé sur le contenu n'écrase
  pas. Passer par `.tint(Ink.control)`.
- Textes en français, identifiants en anglais. Cibles tactiles ≥ 44 pt.

---

## 14. Construire, tester, installer

```bash
cd ios-native

# tests — doivent afficher 69 passants, zero avertissement
xcodebuild -project Optium.xcodeproj -scheme Optium \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 \
  | grep -E "swift:[0-9]+:[0-9]+: (error|warning):|✘|✔ Test run|\*\* TEST"

# build appareil signe
xcodebuild -project Optium.xcodeproj -scheme Optium \
  -destination 'id=<UDID>' -allowProvisioningUpdates build

# installation
xcrun devicectl device install app --device <CoreDeviceID> <chemin>/Optium.app
```

`xcodebuild` produit des milliers de lignes : **toujours filtrer.**

**Le simulateur doit être `Booted`** avant `install` ou `launch`. Un `boot`
silencieux qui échoue produit une erreur de lancement incompréhensible — cela
a déjà coûté une session de débogage.

Équipe de développement : `4L8JW7Q5R7` (Personal Team, gratuite).
Bundle : `com.sabrilab.optium.native`.

---

## 14 bis. Ce que l'application apprend à son utilisateur

Trois surfaces, ajoutées après l'analyse *Hooked*. Elles récompensent toutes un
**résultat**, jamais l'usage — c'est la ligne qui sépare le facilitateur de
l'amuseur, et la charte l'exige déjà.

**Le corpus** (`Corpus/CorpusScreen.swift`) — les lignes écrites à la porte et
les restitutions, relisibles et exportables. **C'est le seul véritable
investissement du produit** : tout le reste est lu. Les enregistrer sans jamais
les remontrer revenait à jeter la seule chose qu'on demande.

**L'écart appris** (`Clarity/CalibrationInsight.swift`) — combien de fois le
ressenti a contredit la mesure, et dans quel sens. C'est l'élément le plus
métacognitif du produit : en restriction chronique, la somnolence ressentie
plafonne alors que la performance décline, et voir l'écart s'accumuler est la
seule façon d'apprendre qu'on ne se juge pas bien. La phrase énonce, elle ne
juge ni ne félicite — une félicitation fausserait les réponses suivantes.

**La tenue au palier** (`Clarity/TierHistory.swift`) — « depuis 27 jours ».
**Rétrospectif, jamais prédictif.** Un « tu passes Net dans six jours » serait
un compte à rebours vers un score de sommeil, c'est-à-dire le levier même de
l'orthosomnie (Baron et coll., *J. Clin. Sleep Med.*, 2017). Cette distinction
n'est pas négociable.

Refusés explicitement, et à ne pas réintroduire : les séries de jours, toute
notification conçue pour ramener, le cadrage par la perte, et toute récompense
déclenchée par l'ouverture de l'application.

## 15. Ce qui n'est pas fait

- **La calibration n'ajuste rien.** Elle enregistre l'écart, l'accumule et le
  restitue — mais le moteur ne s'en sert pas pour se corriger.
- **Le désaccord n'est pas appris.** Si l'utilisateur travaille
  systématiquement à 22 h ce que l'application place à 9 h 40, l'appel peut le
  dire mais rien ne le corrige. À concevoir.
- **La restitution n'est pas dictée**, seulement écrite. La saisie vocale
  reste à faire.
- **L'icône de l'application est vide** — héritée du gabarit de départ.
- **La carte partageable** (écran 16 des maquettes) n'existe pas.
- **Pas de complication montre.**
- **Aucune donnée réelle n'a encore été collectée** : la clarté n'a jamais été
  observée sur vingt-huit vraies nuits.

## 16. Ce qui n'est pas résolu, et doit être testé

Honnêteté sur les limites, pour que personne ne présente comme acquis ce qui ne
l'est pas.

1. **La formule de clarté n'est pas validée.** Voir §5.
2. **L'acceptabilité de la porte est un pari.** C'est à la fois la valeur de
   l'application et sa cause probable de désinstallation. À tester sur une
   dizaine de personnes avant d'élargir.
3. **La démonstration de valeur en sept jours.** La valeur apparaît à la
   troisième semaine ; c'est le rôle de la porte, qui fonctionne dès le jour 1.

## 17. Garde-fous réglementaires

Descriptif, **jamais** prescriptif, **jamais** diagnostique.

Ne jamais afficher de score de performance cognitive, de comparaison à un
« optimal », ni rien qui ressemble à un diagnostic. La règle d'écriture du
cerveau — il parle de son état, jamais de l'utilisateur à l'impératif — est
aussi la protection réglementaire.

HealthKit : les données de santé ne peuvent servir la publicité ni être
partagées sans consentement explicite. Politique de confidentialité obligatoire
avant toute publication.

---

## 18. Références

- Windred et al. (2023). *Sleep regularity is a stronger predictor of mortality
  risk than sleep duration.* SLEEP. doi 10.1093/sleep/zsad253
- Lim & Dinges (2010). *A meta-analysis of the impact of short-term sleep
  deprivation on cognitive variables.* Psychological Bulletin, 136, 375-389.
- Bermudez et al. (2021). *Sleep deprivation and metacognition.* Sleep Medicine
  Reviews — revue systématique et méta-analyse, 28 études. PubMed 33894599.
  **La détection d'erreur est dégradée ; l'estimation de sa propre performance
  est plutôt plus conservatrice.** C'est ce qui fonde §4.
- *Metacognition and Learning* (2017), revue systématique — la privation aiguë
  de courte durée n'affecte pas les jugements de confiance.
- *Collabra: Psychology* (2023) — absence de gain cognitif général et robuste
  issu du croisement heure du jour × chronotype. Fonde le poids réduit du
  circadien.
- Smits, Wenzel & de Bruin (2025). *Behavioral Sciences*, 15(7), 861.
  doi 10.3390/bs15070861 — 94 étudiants, trois conditions de pause. Aucune
  différence significative sur l'achèvement (p = 0,854) ni sur le flow
  (p = 0,774) ; fatigue et perte de motivation montent **plus vite** sous
  Pomodoro que sous pauses auto-régulées. Réserve à énoncer systématiquement :
  ces différences de pente n'ont pas produit d'écart sur les moyennes globales.
  C'est un signal, pas une réfutation.
- Borbély (1982). Modèle à deux processus de la régulation du sommeil.
- Dehaene (2018). *Apprendre !* — attention, engagement actif, retour sur
  erreur, consolidation.

**Source souvent citée à tort** : les 3,5 à 4 h quotidiennes de pratique
délibérée d'Ericsson, Krampe & Tesch-Römer (1993) viennent d'estimations
rétrospectives d'une trentaine d'étudiants. Macnamara & Maitra (2019, *Royal
Society Open Science* 6:190327) trouvent que la pratique délibérée n'explique
que 26 % de la variance au lieu de 48 %. À traiter comme un repère de
conception, jamais comme un plafond physiologique.

**Non vérifié, à ne pas inscrire avant contrôle** : les travaux de Walker sur la
déconnexion préfrontal-amygdale, et la référence d'orthosomnie (Baron et coll.,
2017) — le garde-fou reste pertinent, la citation doit être confirmée.

**L'hypothèse centrale n'est testée nulle part.** Aucune donnée ne permet de
dire qu'interrompre une décision à faible clarté améliore la qualité de cette
décision. Voir `docs/etudes-fondements.md` pour la vérification complète.

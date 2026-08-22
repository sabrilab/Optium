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
clarte = 0.45 * regularite     // SRI sur 28 jours
       + 0.30 * duree          // ecart a la cible, penalise DANS LES DEUX SENS
       + 0.25 * circadien      // deux processus, phase apprise des levers reels
```

Seuils : `basse < 42 ≤ moyenne < 70 ≤ haute`.
**La valeur numérique n'est jamais affichée.**

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

### Le café

**Modificateur, pas composante.** Une prise à moins de huit heures du coucher
visé abaisse la nuit projetée, donc la clarté de **demain**. Jamais celle
d'aujourd'hui : c'est ce qui en fait un enseignement plutôt qu'une punition.
Demi-vie de cinq heures, seuil à huit heures.

### Les sources de sommeil

`HealthSleepSource` (principale) et `MotionSleepSource` (repli), combinées par
`CompositeSleepSource`. Le mouvement ne comble que les nuits absentes du
mesuré ; il ne le corrige jamais.

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

## 13. Le langage visuel

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

## 15. Ce qui n'est pas fait

- **La calibration n'apprend rien encore.** Elle enregistre l'écart entre
  ressenti et mesure, et l'affiche. Rien ne s'ajuste.
- **Le désaccord n'est pas appris.** Si l'utilisateur travaille
  systématiquement à 22 h ce que l'application place à 9 h 40, l'appel peut le
  dire mais rien ne le corrige. À concevoir.
- **La mémoire par projet** (`Call/ProjectMemory.swift`) existe mais n'est
  branchée à aucun écran : ni restitution dictée, ni lecture, ni export.
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
- Borbély (1982). Modèle à deux processus de la régulation du sommeil.
- Dehaene (2018). *Apprendre !* — attention, engagement actif, retour sur
  erreur, consolidation.

**Source souvent citée à tort** : les 3,5 à 4 h quotidiennes de pratique
délibérée d'Ericsson, Krampe & Tesch-Römer (1993) viennent d'estimations
rétrospectives d'une trentaine d'étudiants. Macnamara & Maitra (2019, *Royal
Society Open Science* 6:190327) trouvent que la pratique délibérée n'explique
que 26 % de la variance au lieu de 48 %. À traiter comme un repère de
conception, jamais comme un plafond physiologique.

# Portage d'Optium en application Swift native

Date : 2026-08-21
Statut : conception validée, en attente de relecture

## Intention

Réécrire l'application mobile Optium — aujourd'hui en Expo / React Native
(`mobile/`) — en application iOS native SwiftUI, dans un projet Xcode neuf.

Ce n'est pas une adaptation : les deux piles ne partagent aucune ligne de code.
Les trois écrans, le magasin d'état, la persistance et la scène 3D sont tous
réécrits.

### Ce que la réécriture débloque

La contrainte qui structure le projet Expo aujourd'hui — le SDK figé en 54 parce
que l'Expo Go installé sur l'iPhone de test ne va pas plus loin — disparaît. Avec
elle disparaissent la séparation `.ios.tsx` / `.tsx`, la détection
`supportsSwiftUI` (`src/lib/runtime.ts`) et les composants en double qu'elles
imposaient.

## Décisions

| Sujet | Décision |
|---|---|
| Cohabitation | Projet natif neuf ; le code Expo reste intact comme référence pendant le portage |
| Scène 3D | Metal + `MTKView`, portage des deux shaders GLSL en Metal Shading Language |
| Persistance | SwiftData pour les projets, tâches et sessions ; `@AppStorage` pour les réglages |
| Périmètre v1 | Parité avec l'application Expo, **sans** la génération de tâches par IA |
| Cible | iOS 26 |

## Écart assumé : la saisie manuelle de tâche

L'IA sortant du périmètre, un manque apparaît. Dans l'application actuelle, la
seule façon de créer une tâche est le bouton « Découper en tâches avec l'IA »
(`mobile/src/app/(tabs)/(projects)/index.tsx`) : il n'existe aucune saisie
manuelle.

Sans elle, la v1 native aurait des projets définitivement vides — donc aucune
tâche active, aucune carte de tâche sur l'écran Session, aucun compteur de
pomodoros, et des sessions enregistrées avec `taskId` toujours nul. La moitié du
modèle de données serait morte.

La v1 ajoute donc **un formulaire de création de tâche** (titre, nombre de
pomodoros estimés), présenté en feuille modale depuis l'écran Projets. C'est le
seul ajout au périmètre, et il sert à rendre la parité atteignable, non à
l'élargir. La place du bouton IA reste libre pour un chantier ultérieur.

## Emplacement et création du projet

Le projet vit dans `ios-native/`, à la racine du dépôt, à côté de `mobile/`.
Il est créé depuis l'assistant d'Xcode plutôt qu'à la main : application iOS,
interface SwiftUI, stockage SwiftData, système de test Swift Testing, identifiant
d'organisation `com.sabrilab`.

Les fichiers Swift sont ensuite écrits directement sur le disque. Depuis
Xcode 16, un projet créé par l'assistant utilise un
`PBXFileSystemSynchronizedRootGroup` : le dossier de la cible est synchronisé
avec le système de fichiers, et tout fichier ajouté y apparaît sans qu'on ait à
modifier le `project.pbxproj`.

## Ce qui n'a pas à être porté

Une part importante du code actuel existe pour rapprocher React Native du
comportement d'iOS. iOS le fournit nativement.

| Fichier Expo | Équivalent natif |
|---|---|
| `constants/theme.ts` | `Color.primary`, `Color(.systemGroupedBackground)`, `.font(.body)` |
| `components/glass/glass-surface.tsx` | `.glassEffect()` |
| `components/list.tsx` | `List` + `.listStyle(.insetGrouped)` |
| `components/icon.tsx`, `icon.ios.tsx` | `Image(systemName:)` |
| `components/stats-chart*.tsx` (3 fichiers) | Swift Charts |
| `components/brain/parse-glb.ts` | supprimé — voir « Actif 3D » |
| `lib/runtime.ts` et les suffixes `.ios.tsx` | sans objet : une seule plateforme |

Le mode sombre, le réglage « Augmenter le contraste » et Dynamic Type sont
obtenus par construction, comme c'était déjà l'intention derrière `getPalette()`.

## Structure

```
Optium/
  OptiumApp.swift          point d'entrée, ModelContainer, TabView racine
  Model/
    Project.swift          @Model
    Task.swift             @Model
    FocusSession.swift     @Model
    AppSettings.swift      réglages en @AppStorage
  Timer/
    TimerEngine.swift      @Observable — état du minuteur
    TimerNotifications.swift
  Session/
    SessionScreen.swift
    CompletionSheet.swift
  Projects/
    ProjectsScreen.swift
    ProjectComposer.swift
    TaskComposer.swift     nouveau (voir « Écart assumé »)
  Stats/
    StatsScreen.swift
    StatsBuilder.swift     calculs purs, testables
  Settings/
    SettingsScreen.swift
  Brain/
    BrainView.swift        UIViewRepresentable autour de MTKView
    BrainRenderer.swift    MTKViewDelegate
    BrainMesh.swift        chargement de brain.bin
    Shaders.metal
  Resources/
    brain.bin, chime.wav, Assets.xcassets
```

### Éclatement du magasin d'état

`mobile/src/store.ts` réunit aujourd'hui cinq tranches en un seul objet de 384
lignes, persisté en un blob JSON unique. Il se sépare en trois selon la nature
réelle de chaque donnée :

- **SwiftData** — projets, tâches, sessions. Ce sont des données relationnelles
  et durables. Le modèle actuel les recopie intégralement à chaque écriture et
  plafonne les sessions à 1000 pour contenir la taille du blob ; ce plafond
  disparaît.
- **`@AppStorage`** — durées, carillon, vibrations, géolocalisation,
  visualisation 3D, nom d'utilisateur. Une poignée de scalaires : un `@Model`
  serait démesuré.
- **`TimerEngine`** — l'état du minuteur, volatile par nature, qui n'a rien à
  faire en base.

## Le minuteur

Le mécanisme actuel est conservé, car il est correct : on mémorise **l'instant de
départ**, jamais un compteur décrémenté. C'est le seul état qui survit à la
suspension du processus par iOS (`store.ts`, `startTimer`). `TimerEngine`
recalcule le temps restant depuis cette date à chaque battement.

Deux mécanismes cohabitent, comme aujourd'hui :

- un battement d'une seconde met à jour l'affichage tant que l'application est au
  premier plan ;
- une notification locale est programmée à l'avance pour l'instant de fin. C'est
  elle qui prévient l'utilisateur quand l'application est fermée.

Le natif simplifie les deux : `AsyncTimerSequence` dans un `.task` remplace
l'`useEffect` + `setInterval` + écouteur `AppState` de `use-timer-tick.ts`, et
un recalcul immédiat sur `scenePhase == .active` remplace le rattrapage manuel.

À la fin d'une session : carillon si activé, retour haptique si activé,
enregistrement de la `FocusSession` (durée réellement écoulée si l'utilisateur
termine en avance), incrément du pomodoro de la tâche active — qui bascule la
tâche en `done` lorsque l'estimation est atteinte — puis présentation de la
feuille de fin.

## La scène 3D

### Actif

`mobile/scripts/bake_brain.py` gagne une sortie `brain.bin` : bornes minimale et
maximale, positions, normales, indices, en `Float32` et `UInt32` bruts. Le
fichier se charge en un `Data` et trois `MTLBuffer`, ce qui supprime le besoin
d'un lecteur GLB côté Swift (`parse-glb.ts`, 111 lignes).

Le script conserve son rôle et ses étapes : hiérarchie de transformations du
modèle Sketchfab d'origine, fusion des huit meshes en une géométrie unique,
centrage et mise à l'échelle. `brain.glb` reste produit pour l'application Expo
tant qu'elle sert de référence.

### Rendu

Les deux shaders passent en Metal Shading Language. Les trois choix délibérés
documentés dans `mobile/AGENTS.md` sont maintenus, et pour les mêmes raisons :

- **pas de `discard`** — sur les GPU à tuiles des iPhone, un shader capable de
  rejeter un fragment désactive l'élimination anticipée de profondeur pour tout
  le mesh ; on module l'alpha à la place ;
- **verre en Fresnel**, pas de matériau à transmission — la transmission
  imposerait une passe de rendu supplémentaire par image et une carte
  d'environnement ;
- **écriture de profondeur désactivée** sur les deux matériaux, le fluide dessiné
  avant la coque.

`BrainRenderer`, un `MTKViewDelegate`, écrit les uniformes directement dans un
buffer GPU. C'est le pendant exact du choix actuel de lire le magasin
impérativement dans `useFrame` : aucune vue SwiftUI n'est réévaluée pendant la
session, alors que le minuteur change chaque seconde.

Deux plafonds de consommation sont repris : `isPaused` suspend totalement le
rendu hors de l'onglet Session et en arrière-plan (piloté par `scenePhase` et
l'onglet sélectionné), et la taille du drawable est plafonnée à l'échelle 2.

Le geste de rotation est un `DragGesture` SwiftUI qui alimente la vélocité, elle
même lue par la boucle de rendu pour la secousse du liquide.

## Vérification

Les calculs purs sont développés en test d'abord, avec Swift Testing :

- **`TimerEngine`** — démarrage, pause, `addTime`, bascule focus/pause, pause
  longue au quatrième cycle, et la reprise correcte après une suspension
  simulée (l'instant de départ injecté, pas lu de l'horloge système) ;
- **`StatsBuilder`** — la série en cours, dont le cas « le jour courant encore
  vide ne casse pas la série » ; les moyennes calculées sur les seuls jours
  actifs ; le meilleur jour ;
- **le modèle SwiftData** — suppression en cascade d'un projet vers ses tâches,
  incrément de pomodoro qui bascule la tâche en `done` à l'estimation atteinte.

Le rendu des écrans et la scène 3D se vérifient à l'œil, les deux applications
lancées côte à côte. C'est la raison d'être du maintien du code Expo pendant le
portage.

## Hors périmètre

Chacun de ces points mérite son propre cadrage :

- la génération de tâches par IA et la couche Supabase qui la porte ;
- les capacités natives qu'ouvre la réécriture : Live Activity et Dynamic Island
  pour le minuteur, widgets, raccourcis Siri, synchronisation iCloud ;
- la reprise des données existantes depuis l'application Expo ;
- le sort du code Expo une fois la parité atteinte.

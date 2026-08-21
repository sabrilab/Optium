# Portage d'Optium en Swift natif — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Réécrire l'application Pomodoro Optium — aujourd'hui en Expo / React Native dans `mobile/` — en application iOS native SwiftUI, à parité de fonctionnalités, sans la génération de tâches par IA.

**Architecture:** Trois onglets SwiftUI (Session, Projets, Statistiques) plus un écran Réglages. Les données durables vivent dans SwiftData, les réglages dans `UserDefaults` via une classe `@Observable`, et l'état volatile du minuteur dans `TimerEngine`. La scène 3D est rendue par Metal dans un `MTKView` intégré à SwiftUI, alimentée par un maillage pré-calculé chargé depuis un fichier binaire.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Swift Charts, Metal, MetalKit, UserNotifications, AVFoundation, CoreLocation, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-08-21-portage-swift-design.md`

**Référence de portage:** le code Expo dans `mobile/src/` reste en place pendant tout le plan. Chaque tâche cite les fichiers dont elle s'inspire. Lancer les deux applications côte à côte est la méthode de vérification visuelle prévue.

## Global Constraints

- **Cible : iOS 26.2.** Aucun chemin de repli pour des versions antérieures.
- **Projet :** `ios-native/Optium.xcodeproj`, cibles `Optium` et `OptiumTests`. Il existe déjà et compile.
- **Dossiers synchronisés :** les fichiers ajoutés sous `ios-native/Optium/` et `ios-native/OptiumTests/` sont pris en compte sans modifier `project.pbxproj`. **Ne jamais éditer `project.pbxproj` à la main.**
- **Nommage imposé :** le modèle de tâche s'appelle `ProjectTask` — `Task` est le type de Swift Concurrency. Le mode de repos s'appelle `.rest` — `break` est un mot-clé.
- **Aucune couleur en dur pour l'interface.** Les couleurs viennent des rôles sémantiques SwiftUI : `Color.primary`, `.secondary`, `Color(.systemGroupedBackground)`, `.tint`. Seules les huit couleurs de projet et les quatre couleurs du fluide 3D sont des valeurs littérales, car ce sont des données, pas du style.
- **Aucune taille de police en dur.** Utiliser `.font(.body)`, `.headline`, `.largeTitle`, etc., pour que Dynamic Type fonctionne.
- **Langue de l'interface : le français.** Les identifiants de code sont en anglais, les commentaires et les textes affichés en français, comme dans `mobile/src/`.
- **Cibles tactiles :** 44 points minimum.
- **Commandes de vérification**, depuis `ios-native/` :
  ```bash
  xcodebuild -project Optium.xcodeproj -scheme Optium \
    -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD"

  xcodebuild -project Optium.xcodeproj -scheme Optium \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 \
    | grep -E "error:|✘|✔|TEST (SUCCEEDED|FAILED)"
  ```
  `xcodebuild` produit des milliers de lignes : toujours filtrer.
- **Commits :** un par tâche, message en français, sujet à l'infinitif.

## Structure des fichiers

| Fichier | Responsabilité |
|---|---|
| `Optium/OptiumApp.swift` | Point d'entrée, `ModelContainer`, injection de `AppSettings` et `TimerEngine` |
| `Optium/RootView.swift` | `TabView` racine et suivi de l'onglet sélectionné |
| `Optium/Model/Project.swift` | `@Model Project` + les huit couleurs de projet |
| `Optium/Model/ProjectTask.swift` | `@Model ProjectTask` |
| `Optium/Model/FocusSession.swift` | `@Model FocusSession` |
| `Optium/Settings/AppSettings.swift` | Réglages persistés dans `UserDefaults` |
| `Optium/Timer/TimerMode.swift` | `enum TimerMode` |
| `Optium/Timer/TimerEngine.swift` | État et logique du minuteur |
| `Optium/Timer/SessionCompletion.swift` | Fin de session : carillon, haptique, enregistrement |
| `Optium/Timer/TimerNotifications.swift` | Notification locale de fin |
| `Optium/Timer/LocationRecorder.swift` | Capture du lieu quand le réglage est actif |
| `Optium/Session/SessionScreen.swift` | Écran Session |
| `Optium/Session/CompletionSheet.swift` | Feuille de fin de session |
| `Optium/Projects/ProjectsScreen.swift` | Liste des projets et de leurs tâches |
| `Optium/Projects/ProjectComposer.swift` | Création d'un projet |
| `Optium/Projects/TaskComposer.swift` | Création d'une tâche à la main |
| `Optium/Stats/StatsBuilder.swift` | Calculs statistiques purs |
| `Optium/Stats/StatsScreen.swift` | Écran Statistiques |
| `Optium/Settings/SettingsScreen.swift` | Écran Réglages |
| `Optium/Brain/BrainMesh.swift` | Chargement de `brain.bin` |
| `Optium/Brain/BrainRenderer.swift` | `MTKViewDelegate` et uniformes |
| `Optium/Brain/BrainView.swift` | Pont SwiftUI vers `MTKView` |
| `Optium/Brain/Shaders.metal` | Shaders du fluide et de la coque |
| `mobile/scripts/bake_brain.py` | Modifié : sortie supplémentaire `brain.bin` |

---

### Task 1: Modèle SwiftData

**Files:**
- Create: `ios-native/Optium/Model/Project.swift`
- Create: `ios-native/Optium/Model/ProjectTask.swift`
- Create: `ios-native/Optium/Model/FocusSession.swift`
- Modify: `ios-native/Optium/OptiumApp.swift`
- Test: `ios-native/OptiumTests/ModelTests.swift`

**Interfaces:**
- Consumes: rien.
- Produces:
  - `Project(name: String, detail: String)`, propriétés `id: UUID`, `name: String`, `detail: String`, `isCompleted: Bool`, `createdAt: Date`, `colorHex: String`, `tasks: [ProjectTask]`, et `static let palette: [String]`
  - `ProjectTask(title: String, estimatedPomodoros: Int, order: Int)`, propriétés `id: UUID`, `title: String`, `estimatedPomodoros: Int`, `completedPomodoros: Int`, `isDone: Bool`, `order: Int`, `project: Project?`, méthode `incrementPomodoro()`
  - `FocusSession(durationSeconds: Int, isFocus: Bool, projectID: UUID?, taskID: UUID?)`, propriétés `id: UUID`, `createdAt: Date`, `durationSeconds: Int`, `isFocus: Bool`, `projectID: UUID?`, `taskID: UUID?`, `latitude: Double?`, `longitude: Double?`
  - `Optium.modelContainer` configuré sur ces trois modèles

**Contexte de portage :** équivalent des interfaces `Project`, `Task` et `Session` de `mobile/src/store.ts` (lignes 10-45). Deux écarts délibérés :
- `status: 'active' | 'completed'` devient `isCompleted: Bool` — l'énumération à deux cas ne portait aucune information de plus.
- `FocusSession` référence le projet et la tâche **par identifiant**, pas par relation. Supprimer un projet ne doit pas effacer l'historique des sessions déjà menées ; c'est déjà le comportement de `deleteProject` dans `store.ts`.

- [ ] **Step 1: Écrire les tests qui échouent**

Créer `ios-native/OptiumTests/ModelTests.swift` :

```swift
import Foundation
import SwiftData
import Testing

@testable import Optium

/// Conteneur en memoire : chaque test part d'une base vide et ne touche pas au disque.
@MainActor
private func makeContext() throws -> ModelContext {
    let schema = Schema([Project.self, ProjectTask.self, FocusSession.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: config)
    return ModelContext(container)
}

@MainActor
@Test func supprimerUnProjetSupprimeSesTaches() throws {
    let context = try makeContext()
    let project = Project(name: "Memoire", detail: "Rediger le chapitre 2")
    context.insert(project)
    project.tasks.append(ProjectTask(title: "Plan detaille", estimatedPomodoros: 2, order: 0))
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<ProjectTask>()) == 1)

    context.delete(project)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<ProjectTask>()) == 0)
}

@MainActor
@Test func lIncrementBasculeLaTacheEnTermineeAlEstimationAtteinte() throws {
    let context = try makeContext()
    let task = ProjectTask(title: "Relire", estimatedPomodoros: 2, order: 0)
    context.insert(task)

    task.incrementPomodoro()
    #expect(task.completedPomodoros == 1)
    #expect(task.isDone == false)

    task.incrementPomodoro()
    #expect(task.completedPomodoros == 2)
    #expect(task.isDone == true)
}

@MainActor
@Test func lIncrementNeRedescendJamaisUneTacheTerminee() throws {
    let context = try makeContext()
    let task = ProjectTask(title: "Relire", estimatedPomodoros: 1, order: 0)
    context.insert(task)

    task.incrementPomodoro()
    task.incrementPomodoro()

    #expect(task.completedPomodoros == 2)
    #expect(task.isDone == true)
}

@MainActor
@Test func lesSessionsSurviventALaSuppressionDuProjet() throws {
    let context = try makeContext()
    let project = Project(name: "Memoire", detail: "")
    context.insert(project)
    let projectID = project.id
    context.insert(FocusSession(durationSeconds: 1500, isFocus: true, projectID: projectID, taskID: nil))
    try context.save()

    context.delete(project)
    try context.save()

    // L'historique de concentration deja mene ne doit pas disparaitre avec le projet.
    #expect(try context.fetchCount(FetchDescriptor<FocusSession>()) == 1)
}

@Test func laPaletteDeProjetCompteHuitCouleurs() {
    #expect(Project.palette.count == 8)
}
```

- [ ] **Step 2: Lancer les tests et vérifier qu'ils échouent**

```bash
cd ios-native && xcodebuild -project Optium.xcodeproj -scheme Optium \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 \
  | grep -E "error:|TEST (SUCCEEDED|FAILED)"
```

Attendu : échec de compilation, `cannot find 'Project' in scope`.

- [ ] **Step 3: Écrire les trois modèles**

`ios-native/Optium/Model/Project.swift` :

```swift
import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID = UUID()
    var name: String = ""
    /// L'objectif du projet. Nomme `detail` et non `description`, qui est deja
    /// pris par la conformance CustomStringConvertible de toute classe Swift.
    var detail: String = ""
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var colorHex: String = Project.palette[0]

    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.project)
    var tasks: [ProjectTask] = []

    init(name: String, detail: String, createdAt: Date = Date(), colorHex: String? = nil) {
        self.id = UUID()
        self.name = name
        self.detail = detail
        self.createdAt = createdAt
        self.colorHex = colorHex ?? Project.palette[0]
    }

    /// Couleurs d'identification des projets, reprises telles quelles de la
    /// version Expo pour que les deux applications restent comparables a l'oeil.
    static let palette = [
        "#5B9BD5", "#70AD47", "#FFC000", "#ED7D31",
        "#A855F7", "#EC4899", "#14B8A6", "#F97316",
    ]

    /// Les taches dans l'ordre d'ajout : SwiftData ne garantit pas l'ordre d'une relation.
    var orderedTasks: [ProjectTask] {
        tasks.sorted { $0.order < $1.order }
    }
}
```

`ios-native/Optium/Model/ProjectTask.swift` :

```swift
import Foundation
import SwiftData

/// Nomme `ProjectTask` et non `Task` : `Task` est le type de Swift Concurrency,
/// et l'ombrer rendrait toute utilisation de `Task { }` ambigue dans le module.
@Model
final class ProjectTask {
    var id: UUID = UUID()
    var title: String = ""
    var estimatedPomodoros: Int = 1
    var completedPomodoros: Int = 0
    var isDone: Bool = false
    var order: Int = 0
    var project: Project?

    init(title: String, estimatedPomodoros: Int, order: Int) {
        self.id = UUID()
        self.title = title
        self.estimatedPomodoros = max(1, estimatedPomodoros)
        self.order = order
    }

    /// Une session de concentration terminee sur cette tache.
    func incrementPomodoro() {
        completedPomodoros += 1
        if completedPomodoros >= estimatedPomodoros { isDone = true }
    }
}
```

`ios-native/Optium/Model/FocusSession.swift` :

```swift
import Foundation
import SwiftData

/// Une session menee, de concentration ou de repos.
///
/// Le projet et la tache sont references par identifiant plutot que par
/// relation : supprimer un projet ne doit pas effacer l'historique du temps
/// deja passe dessus.
@Model
final class FocusSession {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var durationSeconds: Int = 0
    var isFocus: Bool = true
    var projectID: UUID?
    var taskID: UUID?
    var latitude: Double?
    var longitude: Double?

    init(
        durationSeconds: Int,
        isFocus: Bool,
        projectID: UUID?,
        taskID: UUID?,
        createdAt: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = UUID()
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
        self.isFocus = isFocus
        self.projectID = projectID
        self.taskID = taskID
        self.latitude = latitude
        self.longitude = longitude
    }
}
```

- [ ] **Step 4: Brancher le conteneur**

Remplacer `ios-native/Optium/OptiumApp.swift` :

```swift
import SwiftData
import SwiftUI

@main
struct OptiumApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Project.self, ProjectTask.self, FocusSession.self])
    }
}
```

- [ ] **Step 5: Lancer les tests et vérifier qu'ils passent**

```bash
cd ios-native && xcodebuild -project Optium.xcodeproj -scheme Optium \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 \
  | grep -E "error:|✘|✔|TEST (SUCCEEDED|FAILED)"
```

Attendu : `TEST SUCCEEDED`, cinq tests passants plus `laCibleDeTestsEstBranchee`.

- [ ] **Step 6: Commit**

```bash
cd /Users/svbri/optium-mobile
git add ios-native
git commit -m "Porter le modele de donnees en SwiftData

Project, ProjectTask et FocusSession remplacent les interfaces du store
zustand. Les sessions referencent projet et tache par identifiant : leur
historique doit survivre a la suppression d'un projet."
```

---

### Task 2: Réglages persistés

**Files:**
- Create: `ios-native/Optium/Settings/AppSettings.swift`
- Test: `ios-native/OptiumTests/AppSettingsTests.swift`

**Interfaces:**
- Consumes: rien.
- Produces: `@Observable final class AppSettings`, `init(defaults: UserDefaults = .standard)`, propriétés `var focusMinutes: Int`, `var restMinutes: Int`, `var longRestMinutes: Int`, `let longRestInterval: Int` (valeur 4), `var soundEnabled: Bool`, `var hapticsEnabled: Bool`, `var locationEnabled: Bool`, `var brainEnabled: Bool`, `var sessionCount: Int`.

**Contexte de portage :** équivalent de `SettingsSlice` et des quatre durées du `TimerSlice` de `mobile/src/store.ts`. Ces valeurs ne sont pas relationnelles : un `@Model` SwiftData serait démesuré pour huit scalaires.

`@AppStorage` n'est pas utilisable ici — c'est un `DynamicProperty` réservé aux vues SwiftUI. On écrit dans `UserDefaults` depuis un `didSet`, ce qui rend la source injectable et donc testable.

**`userName` n'est pas porté.** Le réglage existe dans `mobile/src/store.ts`
(lignes 124, 361-362, 375) : il est déclaré, initialisé à `'User'`, doté d'un
accesseur et persisté. Mais `setUserName` n'est appelé nulle part et `userName`
n'est lu par aucun écran — un `grep` sur `mobile/src/` ne trouve que ces quatre
lignes, toutes dans le magasin lui-même. C'est de l'état mort : le porter
reviendrait à recopier un défaut dans une base neuve.

- [ ] **Step 1: Écrire les tests qui échouent**

Créer `ios-native/OptiumTests/AppSettingsTests.swift` :

```swift
import Foundation
import Testing

@testable import Optium

/// Un domaine UserDefaults jetable par test : aucune fuite d'un test a l'autre.
private func makeDefaults() -> UserDefaults {
    let name = "test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

@Test func lesValeursParDefautSuiventLaMethodePomodoro() {
    let settings = AppSettings(defaults: makeDefaults())

    #expect(settings.focusMinutes == 25)
    #expect(settings.restMinutes == 5)
    #expect(settings.longRestMinutes == 15)
    #expect(settings.longRestInterval == 4)
    #expect(settings.soundEnabled == true)
    #expect(settings.hapticsEnabled == true)
    #expect(settings.locationEnabled == false)
    #expect(settings.brainEnabled == true)
}

@Test func uneValeurModifieeSurvitAUneNouvelleInstance() {
    let defaults = makeDefaults()

    let first = AppSettings(defaults: defaults)
    first.focusMinutes = 50
    first.soundEnabled = false

    let second = AppSettings(defaults: defaults)
    #expect(second.focusMinutes == 50)
    #expect(second.soundEnabled == false)
    // Les valeurs non touchees gardent leur defaut.
    #expect(second.restMinutes == 5)
}
```

- [ ] **Step 2: Lancer les tests et vérifier qu'ils échouent**

Même commande de test. Attendu : `cannot find 'AppSettings' in scope`.

- [ ] **Step 3: Écrire la classe**

`ios-native/Optium/Settings/AppSettings.swift` :

```swift
import Foundation
import Observation

/// Reglages de l'application.
///
/// `@AppStorage` n'est pas utilisable en dehors d'une vue SwiftUI : c'est un
/// `DynamicProperty`. On ecrit donc dans `UserDefaults` depuis un `didSet`, ce
/// qui a l'avantage de rendre la source injectable — les tests utilisent un
/// domaine jetable plutot que les reglages reels de l'appareil.
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    var focusMinutes: Int { didSet { defaults.set(focusMinutes, forKey: Key.focusMinutes) } }
    var restMinutes: Int { didSet { defaults.set(restMinutes, forKey: Key.restMinutes) } }
    var longRestMinutes: Int { didSet { defaults.set(longRestMinutes, forKey: Key.longRestMinutes) } }
    var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) } }
    var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: Key.hapticsEnabled) } }
    var locationEnabled: Bool { didSet { defaults.set(locationEnabled, forKey: Key.locationEnabled) } }
    /// Coupe la 3D : economise la batterie et debloque les appareils lents.
    var brainEnabled: Bool { didSet { defaults.set(brainEnabled, forKey: Key.brainEnabled) } }
    /// Nombre de sessions de concentration menees, pour savoir quand offrir une
    /// pause longue. Persiste, sinon fermer l'application reinitialiserait le cycle.
    var sessionCount: Int { didSet { defaults.set(sessionCount, forKey: Key.sessionCount) } }

    /// Une pause longue toutes les quatre sessions. Non reglable, comme dans la
    /// version Expo, ou `longBreakInterval` n'a pas d'accesseur.
    let longRestInterval = 4

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // `object(forKey:)` distingue « absent » de « zero », ce que `integer(forKey:)` ne fait pas.
        focusMinutes = defaults.object(forKey: Key.focusMinutes) as? Int ?? 25
        restMinutes = defaults.object(forKey: Key.restMinutes) as? Int ?? 5
        longRestMinutes = defaults.object(forKey: Key.longRestMinutes) as? Int ?? 15
        soundEnabled = defaults.object(forKey: Key.soundEnabled) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Key.hapticsEnabled) as? Bool ?? true
        locationEnabled = defaults.object(forKey: Key.locationEnabled) as? Bool ?? false
        brainEnabled = defaults.object(forKey: Key.brainEnabled) as? Bool ?? true
        sessionCount = defaults.object(forKey: Key.sessionCount) as? Int ?? 0
    }

    private enum Key {
        static let focusMinutes = "focusMinutes"
        static let restMinutes = "restMinutes"
        static let longRestMinutes = "longRestMinutes"
        static let soundEnabled = "soundEnabled"
        static let hapticsEnabled = "hapticsEnabled"
        static let locationEnabled = "locationEnabled"
        static let brainEnabled = "brainEnabled"
        static let sessionCount = "sessionCount"
    }
}
```

- [ ] **Step 4: Lancer les tests et vérifier qu'ils passent**

Attendu : `TEST SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
cd /Users/svbri/optium-mobile
git add ios-native
git commit -m "Porter les reglages dans UserDefaults

Huit scalaires : un modele SwiftData serait demesure. La source est
injectable, ce qui permet aux tests d'utiliser un domaine jetable."
```

---

### Task 3: TimerEngine

**Files:**
- Create: `ios-native/Optium/Timer/TimerMode.swift`
- Create: `ios-native/Optium/Timer/TimerEngine.swift`
- Test: `ios-native/OptiumTests/TimerEngineTests.swift`

**Interfaces:**
- Consumes: `AppSettings` (Task 2).
- Produces:
  - `enum TimerMode { case focus, rest }`
  - `@Observable @MainActor final class TimerEngine`
  - `init(settings: AppSettings, now: @escaping () -> Date = Date.init)`
  - Propriétés en lecture : `mode: TimerMode`, `remaining: Int`, `total: Int`, `isRunning: Bool`, `elapsed: Int`, `progress: Double`, `isFinished: Bool`, `finishesAt: Date?`
  - Propriétés en écriture : `activeTaskID: UUID?`, `activeProjectID: UUID?`
  - Méthodes : `start()`, `pause()`, `reset(to mode: TimerMode)`, `refresh()`, `addTime(_ seconds: Int)`, `switchToRest()`, `switchToFocus()`

**Contexte de portage :** équivalent du `TimerSlice` de `mobile/src/store.ts` (lignes 130-215).

Le mécanisme central est conservé et c'est le point le plus important de cette tâche : **on mémorise l'instant de départ, jamais un compteur décrémenté.** iOS suspend le processus dès que l'application quitte le premier plan ; seul un horodatage survit à la suspension. `refresh()` recalcule le restant depuis cette date — c'est le `tick()` de la version Expo, renommé parce qu'il ne décrémente rien.

L'injection de `now` n'est pas un ornement : c'est ce qui permet de tester la reprise après suspension sans attendre réellement.

- [ ] **Step 1: Écrire les tests qui échouent**

Créer `ios-native/OptiumTests/TimerEngineTests.swift` :

```swift
import Foundation
import Testing

@testable import Optium

/// Horloge pilotee : les tests avancent le temps au lieu de l'attendre.
private final class FakeClock {
    var now = Date(timeIntervalSince1970: 1_000_000)
    func advance(_ seconds: TimeInterval) { now += seconds }
}

@MainActor
private func makeEngine() -> (TimerEngine, AppSettings, FakeClock) {
    let name = "test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    let settings = AppSettings(defaults: defaults)
    let clock = FakeClock()
    let engine = TimerEngine(settings: settings, now: { clock.now })
    return (engine, settings, clock)
}

@MainActor
@Test func leMinuteurDemarreSurUneSessionDeConcentration() {
    let (engine, _, _) = makeEngine()

    #expect(engine.mode == .focus)
    #expect(engine.total == 25 * 60)
    #expect(engine.remaining == 25 * 60)
    #expect(engine.isRunning == false)
}

@MainActor
@Test func leTempsSEcouleApresLeDemarrage() {
    let (engine, _, clock) = makeEngine()

    engine.start()
    #expect(engine.isRunning == true)

    clock.advance(60)
    engine.refresh()

    #expect(engine.remaining == 24 * 60)
    #expect(engine.elapsed == 60)
}

@MainActor
@Test func laPauseFigeLeTempsRestant() {
    let (engine, _, clock) = makeEngine()

    engine.start()
    clock.advance(60)
    engine.refresh()
    engine.pause()

    // Le temps continue de passer dans le monde reel, mais le minuteur est arrete.
    clock.advance(3600)
    engine.refresh()

    #expect(engine.remaining == 24 * 60)
    #expect(engine.isRunning == false)
}

@MainActor
@Test func laReprisePartDuTempsRestantEtNonDuTotal() {
    let (engine, _, clock) = makeEngine()

    engine.start()
    clock.advance(60)
    engine.refresh()
    engine.pause()
    engine.start()

    clock.advance(60)
    engine.refresh()

    #expect(engine.remaining == 23 * 60)
}

@MainActor
@Test func leRetourAuPremierPlanRattrapeToutLeTempsDeSuspension() {
    let (engine, _, clock) = makeEngine()

    engine.start()
    // iOS a suspendu le processus : aucun battement n'a eu lieu pendant dix minutes.
    clock.advance(600)
    engine.refresh()

    #expect(engine.remaining == 15 * 60)
}

@MainActor
@Test func leTempsRestantNeDescendJamaisSousZero() {
    let (engine, _, clock) = makeEngine()

    engine.start()
    clock.advance(99_999)
    engine.refresh()

    #expect(engine.remaining == 0)
    #expect(engine.isFinished == true)
}

@MainActor
@Test func ajouterDuTempsProlongeLaSessionSansDecalerLEcoule() {
    let (engine, _, clock) = makeEngine()

    engine.start()
    clock.advance(60)
    engine.refresh()

    engine.addTime(300)

    #expect(engine.total == 25 * 60 + 300)
    #expect(engine.remaining == 24 * 60 + 300)
    #expect(engine.elapsed == 60)
}

@MainActor
@Test func laBasculeEnReposDemarreLaPauseImmediatement() {
    let (engine, _, _) = makeEngine()

    engine.start()
    engine.switchToRest()

    #expect(engine.mode == .rest)
    #expect(engine.total == 5 * 60)
    #expect(engine.isRunning == true)
}

@MainActor
@Test func laQuatriemeSessionOuvreUnePauseLongue() {
    let (engine, settings, _) = makeEngine()

    for _ in 0..<3 {
        engine.switchToRest()
        engine.switchToFocus()
    }
    #expect(engine.total == 25 * 60)

    engine.switchToRest()

    #expect(engine.total == 15 * 60)
    #expect(settings.sessionCount == 4)
}

@MainActor
@Test func laBasculeEnConcentrationNeDemarrePasTouteSeule() {
    let (engine, _, _) = makeEngine()

    engine.switchToRest()
    engine.switchToFocus()

    #expect(engine.mode == .focus)
    #expect(engine.total == 25 * 60)
    #expect(engine.isRunning == false)
}

@MainActor
@Test func changerLaDureeReinitialiseUnMinuteurALArret() {
    let (engine, settings, _) = makeEngine()

    settings.focusMinutes = 50
    engine.reset(to: .focus)

    #expect(engine.total == 50 * 60)
    #expect(engine.remaining == 50 * 60)
}

@MainActor
@Test func laProgressionVaDeZeroAUn() {
    let (engine, _, clock) = makeEngine()

    #expect(engine.progress == 0)

    engine.start()
    clock.advance(25 * 60 / 2)
    engine.refresh()

    #expect(abs(engine.progress - 0.5) < 0.001)
}

@MainActor
@Test func lInstantDeFinEstConnuDesLeDemarrage() {
    let (engine, _, clock) = makeEngine()
    let depart = clock.now

    engine.start()

    // C'est cette date qui sert a programmer la notification de fin.
    #expect(engine.finishesAt == depart.addingTimeInterval(25 * 60))
}

@MainActor
@Test func aLArretAucunInstantDeFinNEstAnnonce() {
    let (engine, _, _) = makeEngine()

    #expect(engine.finishesAt == nil)
}
```

- [ ] **Step 2: Lancer les tests et vérifier qu'ils échouent**

Attendu : `cannot find 'TimerEngine' in scope`.

- [ ] **Step 3: Écrire l'énumération et le moteur**

`ios-native/Optium/Timer/TimerMode.swift` :

```swift
import Foundation

/// Le cas de repos s'appelle `.rest` : `break` est un mot-cle Swift, et
/// l'echapper en `` `break` `` alourdirait chaque site d'appel.
enum TimerMode {
    case focus
    case rest

    var label: String {
        switch self {
        case .focus: "Deep Focus"
        case .rest: "Pause"
        }
    }
}
```

`ios-native/Optium/Timer/TimerEngine.swift` :

```swift
import Foundation
import Observation

/// Etat du minuteur.
///
/// Volatile par nature : rien ici n'est persiste, hormis le compteur de
/// sessions qui vit dans `AppSettings`.
///
/// Le principe central : on memorise l'**instant de depart**, jamais un
/// compteur decremente. iOS suspend le processus des que l'application quitte
/// le premier plan ; un compteur cesserait alors d'etre mis a jour et
/// derivedrait, alors qu'un horodatage survit intact. `refresh()` recalcule le
/// restant depuis cette date.
@Observable
@MainActor
final class TimerEngine {
    private(set) var mode: TimerMode = .focus
    private(set) var total: Int
    private(set) var remaining: Int
    private(set) var isRunning = false

    var activeTaskID: UUID?
    var activeProjectID: UUID?

    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let now: () -> Date

    init(settings: AppSettings, now: @escaping () -> Date = Date.init) {
        self.settings = settings
        self.now = now
        let seconds = settings.focusMinutes * 60
        self.total = seconds
        self.remaining = seconds
    }

    // ── Lectures derivees ──

    var elapsed: Int { total - remaining }

    var progress: Double {
        total == 0 ? 0 : Double(elapsed) / Double(total)
    }

    var isFinished: Bool { remaining <= 0 }

    /// L'instant ou la session se terminera, ou `nil` a l'arret. C'est cette
    /// date qui sert a programmer la notification locale de fin.
    var finishesAt: Date? {
        isRunning ? now().addingTimeInterval(TimeInterval(remaining)) : nil
    }

    // ── Commandes ──

    func start() {
        guard !isRunning else { return }
        // On recule l'instant de depart du temps deja ecoule : une reprise
        // apres pause repart du restant, pas du total.
        startedAt = now().addingTimeInterval(-TimeInterval(elapsed))
        isRunning = true
    }

    func pause() {
        isRunning = false
        startedAt = nil
    }

    func reset(to mode: TimerMode) {
        self.mode = mode
        let seconds = duration(for: mode)
        total = seconds
        remaining = seconds
        isRunning = false
        startedAt = nil
    }

    /// Recalcule le temps restant depuis l'instant de depart.
    ///
    /// A appeler a chaque battement d'affichage et au retour au premier plan.
    /// Idempotent : l'appeler deux fois de suite ne change rien.
    func refresh() {
        guard isRunning, let startedAt else { return }
        let spent = Int(now().timeIntervalSince(startedAt))
        remaining = max(0, total - spent)
    }

    func addTime(_ seconds: Int) {
        let previouslyElapsed = elapsed
        total += seconds
        remaining += seconds
        // L'instant de depart suit, sans quoi le prochain `refresh()` annulerait l'ajout.
        if isRunning { startedAt = now().addingTimeInterval(-TimeInterval(previouslyElapsed)) }
    }

    /// Passe en repos et le demarre. Une pause qu'il faut lancer a la main
    /// n'est pas une pause : on la demarre pour l'utilisateur.
    func switchToRest() {
        settings.sessionCount += 1
        let isLong = settings.sessionCount % settings.longRestInterval == 0
        let minutes = isLong ? settings.longRestMinutes : settings.restMinutes

        mode = .rest
        total = minutes * 60
        remaining = total
        startedAt = now()
        isRunning = true
    }

    /// Repasse en concentration, a l'arret : replonger doit rester un choix.
    func switchToFocus() {
        reset(to: .focus)
    }

    private func duration(for mode: TimerMode) -> Int {
        switch mode {
        case .focus: settings.focusMinutes * 60
        case .rest: settings.restMinutes * 60
        }
    }
}
```

- [ ] **Step 4: Lancer les tests et vérifier qu'ils passent**

Attendu : `TEST SUCCEEDED`, quatorze tests de `TimerEngineTests` passants.

- [ ] **Step 5: Commit**

```bash
cd /Users/svbri/optium-mobile
git add ios-native
git commit -m "Porter le moteur du minuteur

On memorise l'instant de depart, jamais un compteur decremente : iOS
suspend le processus hors du premier plan, seul un horodatage survit.
L'horloge est injectee, ce qui rend la reprise apres suspension testable
sans attendre."
```

---

### Task 4: Racine et écran Session

**Files:**
- Create: `ios-native/Optium/RootView.swift`
- Create: `ios-native/Optium/Session/SessionScreen.swift`
- Modify: `ios-native/Optium/OptiumApp.swift`
- Delete: `ios-native/Optium/ContentView.swift`

**Interfaces:**
- Consumes: `TimerEngine`, `AppSettings`, `Project`, `ProjectTask`.
- Produces:
  - `enum RootTab: Hashable { case session, projects, stats }`
  - `struct RootView: View`
  - `struct SessionScreen: View`
  - L'environnement porte `AppSettings` et `TimerEngine` pour toutes les vues.

**Contexte de portage :** équivalent de `mobile/src/app/(tabs)/_layout.tsx` et `mobile/src/app/(tabs)/(session)/index.tsx`.

Cette tâche pose le minuteur **sans la scène 3D** — l'emplacement de la scène reste vide jusqu'à la Task 10. C'est délibéré : la 3D est le morceau le plus long, et l'écran doit être vérifiable avant.

Pas de test automatisé ici : c'est de la mise en page. La vérification est visuelle, contre l'application Expo lancée à côté.

- [ ] **Step 1: Écrire la vue racine**

`ios-native/Optium/RootView.swift` :

```swift
import SwiftUI

enum RootTab: Hashable {
    case session, projects, stats
}

struct RootView: View {
    /// Suivi de l'onglet actif : la scene 3D s'en sert pour suspendre son rendu
    /// des qu'elle n'est plus visible.
    @State private var selection: RootTab = .session

    var body: some View {
        TabView(selection: $selection) {
            Tab("Session", systemImage: "brain", value: RootTab.session) {
                SessionScreen(selectedTab: selection)
            }
            Tab("Projets", systemImage: "folder", value: RootTab.projects) {
                ProjectsScreen()
            }
            Tab("Statistiques", systemImage: "chart.bar", value: RootTab.stats) {
                StatsScreen()
            }
        }
    }
}
```

**Note :** `ProjectsScreen` et `StatsScreen` n'existent qu'aux Tasks 6 et 8. Pour compiler dès maintenant, créer les deux fichiers avec un corps provisoire — ils seront remplacés :

```swift
// ios-native/Optium/Projects/ProjectsScreen.swift — provisoire, remplace en Task 6
import SwiftUI
struct ProjectsScreen: View {
    var body: some View { Text("Projets") }
}
```

```swift
// ios-native/Optium/Stats/StatsScreen.swift — provisoire, remplace en Task 8
import SwiftUI
struct StatsScreen: View {
    var body: some View { Text("Statistiques") }
}
```

- [ ] **Step 2: Écrire l'écran Session**

`ios-native/Optium/Session/SessionScreen.swift` :

```swift
import SwiftData
import SwiftUI

struct SessionScreen: View {
    let selectedTab: RootTab

    @Environment(TimerEngine.self) private var timer
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @Query private var projects: [Project]
    @State private var showSettings = false

    private var activeTask: ProjectTask? {
        guard let id = timer.activeTaskID else { return nil }
        return projects.flatMap(\.tasks).first { $0.id == id }
    }

    var body: some View {
        ZStack {
            // La scene occupe le haut de l'ecran ; les panneaux de verre
            // flottent par dessus, comme les commandes du lecteur de Musique
            // sur la pochette d'album.
            sceneArea
                .frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: 0) {
                header
                Spacer()
                controls
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsScreen() }
        }
        // Un battement par seconde tant que l'ecran est visible. Il ne
        // decremente rien : il demande au moteur de recalculer depuis sa date
        // de depart.
        .task(id: timer.isRunning) {
            guard timer.isRunning else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                timer.refresh()
            }
        }
        // Le retour au premier plan doit rattraper la suspension sans attendre
        // le prochain battement.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { timer.refresh() }
        }
    }

    @ViewBuilder
    private var sceneArea: some View {
        if settings.brainEnabled {
            // Remplace par BrainView en Task 10.
            Color.clear
        } else {
            Text("Visualisation désactivée")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxHeight: .infinity)
        }
    }

    private var header: some View {
        HStack {
            Text(timer.mode.label)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.clear)

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Réglages")
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if let task = activeTask {
                taskCard(task)
            }
            timerCard
        }
        .padding(.bottom, 16)
    }

    private func taskCard(_ task: ProjectTask) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.project?.name ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(task.title)
                .font(.headline)
                .lineLimit(1)

            HStack(spacing: 4) {
                ForEach(0..<task.estimatedPomodoros, id: \.self) { index in
                    Capsule()
                        .fill(index < task.completedPomodoros ? Color.accentColor : Color(.tertiarySystemFill))
                        .frame(height: 4)
                }
            }
            .padding(.top, 4)
            .accessibilityLabel(
                "\(task.completedPomodoros) sur \(task.estimatedPomodoros) sessions terminées"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private var timerCard: some View {
        VStack(spacing: 0) {
            ProgressView(value: min(1, timer.progress))
                .tint(.primary)
                .frame(width: 220)
                .padding(.bottom, 20)

            Text(formatted(timer.remaining))
                .font(.system(size: 64, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("\(timer.remaining / 60) minutes restantes")

            Text(timer.mode == .focus
                 ? "Session · \(settings.focusMinutes) min"
                 : "Pause · \(settings.restMinutes) min")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .padding(.bottom, 20)

            Button {
                if timer.isRunning { timer.pause() } else { timer.start() }
            } label: {
                Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .frame(width: 68, height: 68)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(timer.isRunning ? "Mettre en pause" : "Démarrer")

            if timer.progress > 0 {
                Button("Terminer maintenant") { endEarly() }
                    .font(.callout)
                    .frame(minHeight: 44)
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    /// Une session interrompue compte pour le temps reellement passe, pas pour
    /// sa duree prevue.
    private func endEarly() {
        context.insert(FocusSession(
            durationSeconds: timer.elapsed,
            isFocus: timer.mode == .focus,
            projectID: timer.activeProjectID,
            taskID: timer.activeTaskID
        ))
        if timer.mode == .focus { timer.switchToRest() } else { timer.switchToFocus() }
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
```

- [ ] **Step 3: Brancher la racine et l'environnement**

Remplacer `ios-native/Optium/OptiumApp.swift` :

```swift
import SwiftData
import SwiftUI

@main
struct OptiumApp: App {
    @State private var settings: AppSettings
    @State private var timer: TimerEngine

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _timer = State(initialValue: TimerEngine(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(timer)
        }
        .modelContainer(for: [Project.self, ProjectTask.self, FocusSession.self])
    }
}
```

Supprimer le fichier d'attente :

```bash
rm /Users/svbri/optium-mobile/ios-native/Optium/ContentView.swift
```

- [ ] **Step 4: Compiler**

```bash
cd ios-native && xcodebuild -project Optium.xcodeproj -scheme Optium \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD"
```

Attendu : `BUILD SUCCEEDED`.

- [ ] **Step 5: Vérifier à l'écran**

Lancer sur le simulateur (`⌘R` dans Xcode, ou `xcodebuild` puis `xcrun simctl launch`). Contrôler :
- trois onglets présents, Session au premier plan ;
- le minuteur affiche `25:00` ;
- le bouton lecture démarre le décompte, qui avance d'une seconde par seconde ;
- pause fige le décompte, lecture reprend au bon endroit ;
- « Terminer maintenant » apparaît dès que le temps a avancé, et fait basculer en pause de 5 min qui démarre seule ;
- le bouton réglages ouvre une feuille (vide à ce stade — l'écran arrive en Task 7).

- [ ] **Step 6: Commit**

```bash
cd /Users/svbri/optium-mobile
git add -A ios-native
git commit -m "Porter l'ecran Session et la navigation par onglets

Le battement d'affichage ne decremente rien : il demande au moteur de
recalculer depuis sa date de depart, et le retour au premier plan
declenche un recalcul immediat.

L'emplacement de la scene 3D reste vide jusqu'a son propre chantier."
```

---

### Task 5: Fin de session

**Files:**
- Create: `ios-native/Optium/Timer/TimerNotifications.swift`
- Create: `ios-native/Optium/Timer/LocationRecorder.swift`
- Create: `ios-native/Optium/Timer/SessionCompletion.swift`
- Create: `ios-native/Optium/Session/CompletionSheet.swift`
- Create: `ios-native/Optium/Resources/chime.wav` (copié)
- Modify: `ios-native/Optium/Session/SessionScreen.swift`
- Test: `ios-native/OptiumTests/SessionCompletionTests.swift`

**Interfaces:**
- Consumes: `TimerEngine`, `AppSettings`, `FocusSession`, `ProjectTask`.
- Produces:
  - `struct SessionCompletion` avec `static func record(timer:settings:context:tasks:coordinate:) -> Bool` — renvoie `true` si une session a été enregistrée
  - `enum TimerNotifications { static func schedule(at:mode:) async; static func cancel() }`
  - `@Observable final class LocationRecorder` avec `var coordinate: (lat: Double, lng: Double)?` et `func refresh(enabled: Bool) async`
  - `struct CompletionSheet: View`

**Contexte de portage :** équivalent de `mobile/src/hooks/use-timer-tick.ts` et `mobile/src/components/completion-sheet.tsx`.

Deux mécanismes cohabitent, et il faut les deux : le battement d'affichage ne tourne qu'au premier plan, tandis que la **notification locale programmée à l'avance** est seule capable de prévenir l'utilisateur quand l'application est fermée.

La partie testable est l'enregistrement : ce qu'on écrit en base et l'incrément du pomodoro. Le son, l'haptique et la notification ne se testent pas utilement en unitaire.

- [ ] **Step 1: Copier le carillon**

```bash
mkdir -p /Users/svbri/optium-mobile/ios-native/Optium/Resources
cp /Users/svbri/optium-mobile/mobile/assets/audio/chime.wav \
   /Users/svbri/optium-mobile/ios-native/Optium/Resources/chime.wav
```

- [ ] **Step 2: Écrire les tests qui échouent**

Créer `ios-native/OptiumTests/SessionCompletionTests.swift` :

```swift
import Foundation
import SwiftData
import Testing

@testable import Optium

@MainActor
private func makeWorld() throws -> (TimerEngine, AppSettings, ModelContext) {
    let name = "test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    let settings = AppSettings(defaults: defaults)

    let schema = Schema([Project.self, ProjectTask.self, FocusSession.self])
    let container = try ModelContainer(
        for: schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)

    return (TimerEngine(settings: settings), settings, context)
}

@MainActor
@Test func laSessionTermineeEstEnregistreePourSaDureeTotale() throws {
    let (timer, settings, context) = try makeWorld()
    timer.start()

    let recorded = SessionCompletion.record(
        timer: timer, settings: settings, context: context, tasks: [], coordinate: nil
    )

    #expect(recorded == true)
    let sessions = try context.fetch(FetchDescriptor<FocusSession>())
    #expect(sessions.count == 1)
    #expect(sessions[0].durationSeconds == 25 * 60)
    #expect(sessions[0].isFocus == true)
}

@MainActor
@Test func laSessionTermineeIncrementeLaTacheActive() throws {
    let (timer, settings, context) = try makeWorld()
    let project = Project(name: "Memoire", detail: "")
    context.insert(project)
    let task = ProjectTask(title: "Plan", estimatedPomodoros: 2, order: 0)
    project.tasks.append(task)

    timer.activeProjectID = project.id
    timer.activeTaskID = task.id
    timer.start()

    _ = SessionCompletion.record(
        timer: timer, settings: settings, context: context, tasks: [task], coordinate: nil
    )

    #expect(task.completedPomodoros == 1)
}

@MainActor
@Test func unePauseTermineeNIncrementeAucuneTache() throws {
    let (timer, settings, context) = try makeWorld()
    let task = ProjectTask(title: "Plan", estimatedPomodoros: 2, order: 0)
    context.insert(task)
    timer.activeTaskID = task.id
    timer.switchToRest()

    _ = SessionCompletion.record(
        timer: timer, settings: settings, context: context, tasks: [task], coordinate: nil
    )

    // Se reposer n'est pas travailler.
    #expect(task.completedPomodoros == 0)
    let sessions = try context.fetch(FetchDescriptor<FocusSession>())
    #expect(sessions[0].isFocus == false)
}

@MainActor
@Test func leLieuEstEnregistreQuandIlEstFourni() throws {
    let (timer, settings, context) = try makeWorld()
    timer.start()

    _ = SessionCompletion.record(
        timer: timer, settings: settings, context: context, tasks: [],
        coordinate: (lat: 48.8566, lng: 2.3522)
    )

    let sessions = try context.fetch(FetchDescriptor<FocusSession>())
    #expect(sessions[0].latitude == 48.8566)
    #expect(sessions[0].longitude == 2.3522)
}

@MainActor
@Test func unDeuxiemeAppelNEnregistrePasLaMemeSessionDeuxFois() throws {
    let (timer, settings, context) = try makeWorld()
    timer.start()

    let first = SessionCompletion.record(
        timer: timer, settings: settings, context: context, tasks: [], coordinate: nil
    )
    let second = SessionCompletion.record(
        timer: timer, settings: settings, context: context, tasks: [], coordinate: nil
    )

    // Le minuteur est mis en pause par le premier appel : le second n'a plus rien a enregistrer.
    #expect(first == true)
    #expect(second == false)
    #expect(try context.fetchCount(FetchDescriptor<FocusSession>()) == 1)
}
```

- [ ] **Step 3: Lancer les tests et vérifier qu'ils échouent**

Attendu : `cannot find 'SessionCompletion' in scope`.

- [ ] **Step 4: Écrire l'enregistrement**

`ios-native/Optium/Timer/SessionCompletion.swift` :

```swift
import AVFoundation
import Foundation
import SwiftData
import UIKit

/// Fin de session : carillon, retour haptique, enregistrement en base.
///
/// L'enregistrement est separe des effets sensoriels pour rester testable :
/// `record` ne joue rien et ne vibre pas, `announce` s'en charge.
enum SessionCompletion {

    /// Enregistre la session qui vient de se terminer.
    ///
    /// - Returns: `false` si le minuteur etait deja a l'arret, c'est-a-dire si
    ///   la session a deja ete enregistree. Le garde-fou est necessaire : le
    ///   battement d'affichage et le retour au premier plan peuvent tous deux
    ///   constater la fin dans la meme seconde.
    @MainActor
    @discardableResult
    static func record(
        timer: TimerEngine,
        settings: AppSettings,
        context: ModelContext,
        tasks: [ProjectTask],
        coordinate: (lat: Double, lng: Double)?
    ) -> Bool {
        guard timer.isRunning else { return false }
        let wasFocus = timer.mode == .focus
        let duration = timer.total
        let taskID = timer.activeTaskID

        timer.pause()

        context.insert(FocusSession(
            durationSeconds: duration,
            isFocus: wasFocus,
            projectID: timer.activeProjectID,
            taskID: taskID,
            latitude: coordinate?.lat,
            longitude: coordinate?.lng
        ))

        if wasFocus, let taskID, let task = tasks.first(where: { $0.id == taskID }) {
            task.incrementPomodoro()
        }

        return true
    }

    /// Carillon et vibration, selon les reglages.
    @MainActor
    static func announce(settings: AppSettings) {
        if settings.soundEnabled { playChime() }
        if settings.hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    /// Le lecteur est cree au premier carillon, pas au lancement : rien ne
    /// justifie de reserver une ressource audio tant qu'aucune session n'est finie.
    @MainActor private static var chime: AVAudioPlayer?

    @MainActor
    private static func playChime() {
        if chime == nil {
            guard let url = Bundle.main.url(forResource: "chime", withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { return }
            player.prepareToPlay()
            chime = player
        }
        chime?.currentTime = 0
        chime?.play()
    }
}
```

- [ ] **Step 5: Lancer les tests et vérifier qu'ils passent**

Attendu : `TEST SUCCEEDED`, cinq tests de `SessionCompletionTests` passants.

- [ ] **Step 6: Écrire la notification de fin**

`ios-native/Optium/Timer/TimerNotifications.swift` :

```swift
import Foundation
import UserNotifications

/// Notification locale programmee a l'avance pour l'instant de fin.
///
/// Le battement d'affichage ne tourne qu'au premier plan : quand l'application
/// est fermee, cette notification est le seul mecanisme capable de prevenir
/// l'utilisateur.
enum TimerNotifications {
    private static let identifier = "optium.session.fin"

    static func schedule(at date: Date, mode: TimerMode) async {
        await cancel()

        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        switch mode {
        case .focus:
            content.title = "Session terminée 🎯"
            content.body = "C’est l’heure de la pause."
        case .rest:
            content.title = "Pause terminée ☕"
            content.body = "Prêt à replonger ?"
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        try? await center.add(request)
    }

    static func cancel() async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
```

- [ ] **Step 7: Écrire la capture du lieu**

`ios-native/Optium/Timer/LocationRecorder.swift` :

```swift
import CoreLocation
import Foundation
import Observation

/// Capture la position une fois par activation du reglage, pas a chaque session :
/// on cherche a savoir *ou* l'utilisateur se concentre, pas a le suivre.
@Observable
@MainActor
final class LocationRecorder {
    private(set) var coordinate: (lat: Double, lng: Double)?

    @ObservationIgnored private let manager = CLLocationManager()

    func refresh(enabled: Bool) async {
        guard enabled else {
            coordinate = nil
            return
        }
        manager.requestWhenInUseAuthorization()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        guard let update = try? await CLLocationUpdate.liveUpdates().first(where: { $0.location != nil }),
              let location = update.location else { return }

        coordinate = (lat: location.coordinate.latitude, lng: location.coordinate.longitude)
    }
}
```

**Permission requise.** Ajouter la clé dans les réglages de la cible via Xcode (Build Settings → `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`), ou en ligne de commande sur les deux configurations :

```
INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Optium enregistre le lieu de vos sessions pour vous montrer où vous vous concentrez le mieux.";
```

Texte repris de `mobile/app.json`.

- [ ] **Step 8: Écrire la feuille de fin**

`ios-native/Optium/Session/CompletionSheet.swift` :

```swift
import SwiftUI

struct CompletionSheet: View {
    let mode: TimerMode
    let onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: mode == .focus ? "checkmark.circle.fill" : "cup.and.saucer.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text(mode == .focus ? "Session terminée" : "Pause terminée")
                .font(.title2.weight(.semibold))

            Text(mode == .focus
                 ? "Prenez une pause, vous l’avez méritée."
                 : "Prêt à replonger ?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(mode == .focus ? "Commencer la pause" : "Reprendre") {
                onContinue()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(minHeight: 44)
        }
        .padding(32)
        .presentationDetents([.medium])
    }
}
```

- [ ] **Step 9: Brancher le tout dans l'écran Session**

Dans `ios-native/Optium/Session/SessionScreen.swift`, ajouter aux propriétés :

```swift
    @State private var location = LocationRecorder()
    @State private var finishedMode: TimerMode?
```

Ajouter ces modificateurs à la fin de `body`, après `.onChange(of: scenePhase)` :

```swift
        // Fin de session : detectee des que le restant atteint zero, d'ou que
        // vienne le constat — battement d'affichage ou retour au premier plan.
        .onChange(of: timer.isFinished) { _, finished in
            guard finished else { return }
            let mode = timer.mode
            let recorded = SessionCompletion.record(
                timer: timer,
                settings: settings,
                context: context,
                tasks: projects.flatMap(\.tasks),
                coordinate: location.coordinate
            )
            guard recorded else { return }
            SessionCompletion.announce(settings: settings)
            finishedMode = mode
        }
        // La notification est (re)programmee au demarrage et a l'arret, jamais
        // a chaque seconde : la reprogrammer en boucle l'annulerait sans cesse.
        .task(id: timer.isRunning) {
            if let date = timer.finishesAt {
                await TimerNotifications.schedule(at: date, mode: timer.mode)
            } else {
                await TimerNotifications.cancel()
            }
        }
        .task(id: settings.locationEnabled) {
            await location.refresh(enabled: settings.locationEnabled)
        }
        .sheet(item: $finishedMode) { mode in
            CompletionSheet(mode: mode) {
                if mode == .focus { timer.switchToRest() } else { timer.switchToFocus() }
            }
        }
```

Pour que `finishedMode` soit utilisable avec `.sheet(item:)`, rendre `TimerMode` identifiable. Dans `ios-native/Optium/Timer/TimerMode.swift`, changer la déclaration :

```swift
enum TimerMode: Identifiable {
    case focus
    case rest

    var id: Self { self }

    var label: String {
        switch self {
        case .focus: "Deep Focus"
        case .rest: "Pause"
        }
    }
}
```

- [ ] **Step 10: Lancer les tests et compiler**

Attendu : `TEST SUCCEEDED` et `BUILD SUCCEEDED`.

- [ ] **Step 11: Vérifier à l'écran**

Dans les réglages de la cible, mettre temporairement `focusMinutes` à une valeur courte en modifiant la valeur par défaut, ou utiliser l'écran Réglages une fois la Task 7 faite. Contrôler :
- à zéro, le carillon retentit, l'appareil vibre, la feuille de fin apparaît ;
- le bouton de la feuille lance la pause ;
- en mettant l'application en arrière-plan avant la fin, la notification arrive à l'heure prévue.

- [ ] **Step 12: Commit**

```bash
cd /Users/svbri/optium-mobile
git add -A ios-native
git commit -m "Porter la fin de session

Enregistrement, carillon, haptique, notification locale et feuille de fin.

L'enregistrement est separe des effets sensoriels pour rester testable, et
renvoie false si la session a deja ete enregistree : le battement et le
retour au premier plan peuvent constater la fin dans la meme seconde."
```

---

### Task 6: Écran Projets

**Files:**
- Modify: `ios-native/Optium/Projects/ProjectsScreen.swift` (remplace le fichier provisoire)
- Create: `ios-native/Optium/Projects/ProjectComposer.swift`
- Create: `ios-native/Optium/Projects/TaskComposer.swift`

**Interfaces:**
- Consumes: `Project`, `ProjectTask`, `TimerEngine`.
- Produces: `struct ProjectsScreen: View`, `struct ProjectComposer: View`, `struct TaskComposer: View`.

**Contexte de portage :** équivalent de `mobile/src/app/(tabs)/(projects)/index.tsx`.

**`TaskComposer` n'a pas d'équivalent Expo** — c'est l'ajout au périmètre décidé dans la spec. Dans l'application actuelle, la seule façon de créer une tâche est la génération par IA ; celle-ci étant hors périmètre, sans saisie manuelle les projets resteraient vides et tout le modèle tâche/pomodoro serait inutilisable.

- [ ] **Step 1: Écrire le composeur de projet**

`ios-native/Optium/Projects/ProjectComposer.swift` :

```swift
import SwiftData
import SwiftUI

struct ProjectComposer: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]

    @State private var name = ""
    @State private var detail = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom du projet", text: $name)
                    TextField("Objectif", text: $detail, axis: .vertical)
                        .lineLimit(3...6)
                } footer: {
                    Text("L’objectif décrit ce que le projet doit accomplir.")
                }
            }
            .navigationTitle("Nouveau projet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // La couleur tourne dans la palette selon le nombre de projets, comme
        // dans la version Expo : deux projets voisins ne se ressemblent pas.
        let color = Project.palette[projects.count % Project.palette.count]
        context.insert(Project(name: trimmed, detail: detail.trimmingCharacters(in: .whitespaces), colorHex: color))
        dismiss()
    }
}
```

- [ ] **Step 2: Écrire le composeur de tâche**

`ios-native/Optium/Projects/TaskComposer.swift` :

```swift
import SwiftUI

/// Saisie manuelle d'une tache.
///
/// Sans equivalent dans la version Expo, ou les taches ne naissent que de la
/// generation par IA. Celle-ci etant hors perimetre, cet ecran est ce qui rend
/// le modele tache/pomodoro utilisable.
struct TaskComposer: View {
    let project: Project

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var estimate = 1

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Que faut-il faire ?", text: $title)
                }
                Section {
                    Stepper("\(estimate) session\(estimate > 1 ? "s" : "")", value: $estimate, in: 1...12)
                } header: {
                    Text("Estimation")
                } footer: {
                    Text("Une session dure le temps réglé pour la concentration.")
                }
            }
            .navigationTitle("Nouvelle tâche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { create() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func create() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        project.tasks.append(
            ProjectTask(title: trimmed, estimatedPomodoros: estimate, order: project.tasks.count)
        )
        dismiss()
    }
}
```

- [ ] **Step 3: Écrire l'écran Projets**

Remplacer `ios-native/Optium/Projects/ProjectsScreen.swift` :

```swift
import SwiftData
import SwiftUI

struct ProjectsScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(TimerEngine.self) private var timer

    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    @State private var composingProject = false
    @State private var composingTaskFor: Project?

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    ContentUnavailableView {
                        Label("Aucun projet", systemImage: "folder")
                    } description: {
                        Text("Créez un projet, puis découpez-le en tâches.")
                    } actions: {
                        Button("Nouveau projet") { composingProject = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Projets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        composingProject = true
                    } label: {
                        Label("Nouveau projet", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $composingProject) { ProjectComposer() }
            .sheet(item: $composingTaskFor) { TaskComposer(project: $0) }
        }
    }

    private var list: some View {
        List {
            ForEach(projects) { project in
                Section {
                    ForEach(project.orderedTasks) { task in
                        Button { start(task, in: project) } label: { row(task) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { offsets in delete(offsets, from: project) }

                    Button {
                        composingTaskFor = project
                    } label: {
                        Label("Ajouter une tâche", systemImage: "plus.circle")
                    }
                } header: {
                    Text(project.name)
                } footer: {
                    if !project.tasks.isEmpty {
                        let done = project.tasks.filter(\.isDone).count
                        Text("\(done) sur \(project.tasks.count) tâches terminées")
                    }
                }
            }
            .onDelete(perform: deleteProjects)
        }
    }

    private func row(_ task: ProjectTask) -> some View {
        HStack {
            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.isDone ? Color.accentColor : Color(.tertiaryLabel))
            Text(task.title)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 44)
    }

    /// Demarrer une tache la rend active et lance immediatement une session.
    private func start(_ task: ProjectTask, in project: Project) {
        timer.activeTaskID = task.id
        timer.activeProjectID = project.id
        timer.reset(to: .focus)
        timer.start()
    }

    private func delete(_ offsets: IndexSet, from project: Project) {
        let ordered = project.orderedTasks
        for index in offsets {
            let task = ordered[index]
            // Supprimer la tache en cours doit liberer le minuteur, sinon il
            // pointerait vers un objet disparu.
            if timer.activeTaskID == task.id { timer.activeTaskID = nil }
            context.delete(task)
        }
    }

    private func deleteProjects(_ offsets: IndexSet) {
        for index in offsets {
            let project = projects[index]
            if timer.activeProjectID == project.id {
                timer.activeProjectID = nil
                timer.activeTaskID = nil
            }
            context.delete(project)
        }
    }
}
```

- [ ] **Step 4: Compiler**

Attendu : `BUILD SUCCEEDED`.

- [ ] **Step 5: Vérifier à l'écran**

- l'onglet Projets vide propose la création ;
- « + » crée un projet, qui apparaît en tête de liste ;
- « Ajouter une tâche » crée une tâche avec son estimation ;
- toucher une tâche bascule sur l'onglet Session avec la carte de tâche visible et le minuteur lancé ;
- glisser une tâche vers la gauche la supprime ; glisser un projet supprime le projet et ses tâches ;
- supprimer la tâche active vide la carte de tâche sans planter.

- [ ] **Step 6: Commit**

```bash
cd /Users/svbri/optium-mobile
git add -A ios-native
git commit -m "Porter l'ecran Projets et ajouter la saisie manuelle de tache

TaskComposer n'a pas d'equivalent Expo : la generation par IA etant hors
perimetre, sans lui les projets resteraient vides et tout le modele
tache/pomodoro serait inutilisable."
```

---

### Task 7: Écran Réglages

**Files:**
- Create: `ios-native/Optium/Settings/SettingsScreen.swift`

**Interfaces:**
- Consumes: `AppSettings`, `TimerEngine`.
- Produces: `struct SettingsScreen: View`.

**Contexte de portage :** équivalent de `mobile/src/app/settings.ios.tsx`. C'est l'écran où le natif gagne le plus : le `Form` SwiftUI d'origine était déjà rendu par `@expo/ui` à travers un pont ; ici il n'y a plus de pont.

Changer une durée alors que le minuteur est à l'arrêt doit réinitialiser le temps affiché — sinon le réglage semblerait sans effet jusqu'à la session suivante.

- [ ] **Step 1: Écrire l'écran**

`ios-native/Optium/Settings/SettingsScreen.swift` :

```swift
import SwiftUI

struct SettingsScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TimerEngine.self) private var timer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Durées") {
                Stepper("Session · \(settings.focusMinutes) min",
                        value: $settings.focusMinutes, in: 5...90, step: 5)
                Stepper("Pause · \(settings.restMinutes) min",
                        value: $settings.restMinutes, in: 1...30, step: 1)
                Stepper("Pause longue · \(settings.longRestMinutes) min",
                        value: $settings.longRestMinutes, in: 5...45, step: 5)
            }

            Section("Retours") {
                Toggle("Carillon de fin", isOn: $settings.soundEnabled)
                Toggle("Vibrations", isOn: $settings.hapticsEnabled)
            }

            Section {
                Toggle("Enregistrer le lieu", isOn: $settings.locationEnabled)
                Toggle("Visualisation 3D", isOn: $settings.brainEnabled)
            } header: {
                Text("Session")
            } footer: {
                Text("Couper la visualisation économise la batterie.")
            }
        }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Terminé") { dismiss() }
            }
        }
        // Une duree changee doit se voir tout de suite. On ne touche pas a un
        // minuteur en cours : ce serait perdre la session de l'utilisateur.
        .onChange(of: settings.focusMinutes) { _, _ in
            if !timer.isRunning && timer.mode == .focus { timer.reset(to: .focus) }
        }
        .onChange(of: settings.restMinutes) { _, _ in
            if !timer.isRunning && timer.mode == .rest { timer.reset(to: .rest) }
        }
    }
}
```

- [ ] **Step 2: Compiler**

Attendu : `BUILD SUCCEEDED`.

- [ ] **Step 3: Vérifier à l'écran**

- l'engrenage de l'écran Session ouvre les réglages ;
- changer la durée de session met à jour le `25:00` affiché derrière, minuteur à l'arrêt ;
- changer une durée pendant qu'une session tourne ne perturbe pas le décompte ;
- couper « Visualisation 3D » remplace la zone de scène par le texte prévu ;
- fermer et rouvrir l'application conserve tous les réglages.

- [ ] **Step 4: Commit**

```bash
cd /Users/svbri/optium-mobile
git add -A ios-native
git commit -m "Porter l'ecran Reglages

Form SwiftUI direct, sans le pont @expo/ui. Changer une duree reinitialise
le minuteur a l'arret, jamais celui en cours."
```

---

### Task 8: Statistiques

**Files:**
- Create: `ios-native/Optium/Stats/StatsBuilder.swift`
- Modify: `ios-native/Optium/Stats/StatsScreen.swift` (remplace le fichier provisoire)
- Test: `ios-native/OptiumTests/StatsBuilderTests.swift`

**Interfaces:**
- Consumes: `FocusSession`.
- Produces:
  - `struct DayStat: Identifiable { let date: Date; let seconds: Int; let count: Int; var id: Date }`
  - `struct Stats { let days: [DayStat]; let todaySeconds: Int; let todayCount: Int; let streak: Int; let averageSeconds: Int; let averageCount: Double; let best: DayStat? }`
  - `enum StatsBuilder { static func build(sessions: [FocusSession], today: Date, calendar: Calendar = .current) -> Stats }`
  - `static let windowDays = 14`
  - `struct StatsScreen: View`

**Contexte de portage :** équivalent de `buildStats` dans `mobile/src/app/(tabs)/(stats)/index.tsx` (lignes 27-73).

Deux règles à ne pas perdre, toutes deux déjà présentes dans la version Expo :
- **la série en cours ne casse pas sur un jour courant encore vide** — sinon la série de tout le monde tomberait à zéro chaque matin ;
- **les moyennes se calculent sur les jours actifs seulement** — inclure les jours sans session ferait mentir la moyenne.

- [ ] **Step 1: Écrire les tests qui échouent**

Créer `ios-native/OptiumTests/StatsBuilderTests.swift` :

```swift
import Foundation
import Testing

@testable import Optium

private let reference = Date(timeIntervalSince1970: 1_760_000_000)

private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    return calendar
}

/// Une session de concentration placee il y a `daysAgo` jours.
@MainActor
private func session(daysAgo: Int, minutes: Int, isFocus: Bool = true) -> FocusSession {
    let day = calendar.date(byAdding: .day, value: -daysAgo, to: reference)!
    return FocusSession(
        durationSeconds: minutes * 60,
        isFocus: isFocus,
        projectID: nil,
        taskID: nil,
        createdAt: day
    )
}

@MainActor
@Test func laFenetreCouvreQuatorzeJours() {
    let stats = StatsBuilder.build(sessions: [], today: reference, calendar: calendar)
    #expect(stats.days.count == 14)
}

@MainActor
@Test func lesSessionsDuJourSontComptees() {
    let stats = StatsBuilder.build(
        sessions: [session(daysAgo: 0, minutes: 25), session(daysAgo: 0, minutes: 25)],
        today: reference, calendar: calendar
    )

    #expect(stats.todayCount == 2)
    #expect(stats.todaySeconds == 50 * 60)
}

@MainActor
@Test func lesPausesNeComptentPasCommeDuTravail() {
    let stats = StatsBuilder.build(
        sessions: [session(daysAgo: 0, minutes: 25), session(daysAgo: 0, minutes: 5, isFocus: false)],
        today: reference, calendar: calendar
    )

    #expect(stats.todayCount == 1)
    #expect(stats.todaySeconds == 25 * 60)
}

@MainActor
@Test func laSerieCompteLesJoursConsecutifs() {
    let stats = StatsBuilder.build(
        sessions: [session(daysAgo: 0, minutes: 25),
                   session(daysAgo: 1, minutes: 25),
                   session(daysAgo: 2, minutes: 25)],
        today: reference, calendar: calendar
    )

    #expect(stats.streak == 3)
}

@MainActor
@Test func unJourCourantVideNeCassePasLaSerie() {
    // Rien aujourd'hui, mais trois jours d'affilee avant : la serie tient.
    // Sans cette regle, la serie de chacun tomberait a zero chaque matin.
    let stats = StatsBuilder.build(
        sessions: [session(daysAgo: 1, minutes: 25),
                   session(daysAgo: 2, minutes: 25),
                   session(daysAgo: 3, minutes: 25)],
        today: reference, calendar: calendar
    )

    #expect(stats.streak == 3)
}

@MainActor
@Test func unTrouCasseLaSerie() {
    let stats = StatsBuilder.build(
        sessions: [session(daysAgo: 0, minutes: 25), session(daysAgo: 2, minutes: 25)],
        today: reference, calendar: calendar
    )

    #expect(stats.streak == 1)
}

@MainActor
@Test func lesMoyennesIgnorentLesJoursSansSession() {
    // Deux jours actifs a 30 min : la moyenne est 30, pas 60/14.
    let stats = StatsBuilder.build(
        sessions: [session(daysAgo: 0, minutes: 30), session(daysAgo: 5, minutes: 30)],
        today: reference, calendar: calendar
    )

    #expect(stats.averageSeconds == 30 * 60)
    #expect(abs(stats.averageCount - 1.0) < 0.001)
}

@MainActor
@Test func leMeilleurJourEstCeluiDuPlusLongTemps() {
    let stats = StatsBuilder.build(
        sessions: [session(daysAgo: 0, minutes: 25), session(daysAgo: 3, minutes: 90)],
        today: reference, calendar: calendar
    )

    #expect(stats.best?.seconds == 90 * 60)
}

@MainActor
@Test func sansAucuneSessionToutEstNeutre() {
    let stats = StatsBuilder.build(sessions: [], today: reference, calendar: calendar)

    #expect(stats.streak == 0)
    #expect(stats.todaySeconds == 0)
    #expect(stats.averageSeconds == 0)
    #expect(stats.best == nil)
}

@MainActor
@Test func lesSessionsHorsFenetreSontIgnorees() {
    let stats = StatsBuilder.build(
        sessions: [session(daysAgo: 30, minutes: 60)],
        today: reference, calendar: calendar
    )

    #expect(stats.days.allSatisfy { $0.seconds == 0 })
    #expect(stats.best == nil)
}
```

- [ ] **Step 2: Lancer les tests et vérifier qu'ils échouent**

Attendu : `cannot find 'StatsBuilder' in scope`.

- [ ] **Step 3: Écrire le calculateur**

`ios-native/Optium/Stats/StatsBuilder.swift` :

```swift
import Foundation

struct DayStat: Identifiable, Equatable {
    let date: Date
    let seconds: Int
    let count: Int

    var id: Date { date }
}

struct Stats {
    let days: [DayStat]
    let todaySeconds: Int
    let todayCount: Int
    let streak: Int
    let averageSeconds: Int
    let averageCount: Double
    let best: DayStat?
}

/// Calculs statistiques, sans dependance a SwiftUI ni a SwiftData : c'est ce
/// qui les rend testables sans lancer d'interface.
enum StatsBuilder {
    static let windowDays = 14

    static func build(
        sessions: [FocusSession],
        today: Date,
        calendar: Calendar = .current
    ) -> Stats {
        let focus = sessions.filter(\.isFocus)
        let startOfToday = calendar.startOfDay(for: today)

        let days: [DayStat] = (0..<windowDays).map { offset in
            let date = calendar.date(byAdding: .day, value: offset - (windowDays - 1), to: startOfToday)!
            let sameDay = focus.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            return DayStat(
                date: date,
                seconds: sameDay.reduce(0) { $0 + $1.durationSeconds },
                count: sameDay.count
            )
        }

        // Serie en cours : on remonte jour par jour tant qu'une session existe.
        // Le jour courant ne casse pas la serie s'il est encore vide — sinon
        // la serie de chacun tomberait a zero chaque matin.
        var streak = 0
        for index in stride(from: days.count - 1, through: 0, by: -1) {
            if days[index].count > 0 {
                streak += 1
            } else if index != days.count - 1 {
                break
            }
        }

        let activeDays = days.filter { $0.count > 0 }
        let totalSeconds = days.reduce(0) { $0 + $1.seconds }
        let totalCount = days.reduce(0) { $0 + $1.count }
        let best = days.max { $0.seconds < $1.seconds }

        return Stats(
            days: days,
            todaySeconds: days.last?.seconds ?? 0,
            todayCount: days.last?.count ?? 0,
            streak: streak,
            // Moyennes sur les seuls jours actifs : inclure les jours vides
            // ferait mentir le chiffre.
            averageSeconds: activeDays.isEmpty ? 0 : totalSeconds / activeDays.count,
            averageCount: activeDays.isEmpty ? 0 : Double(totalCount) / Double(activeDays.count),
            best: (best?.seconds ?? 0) > 0 ? best : nil
        )
    }
}
```

- [ ] **Step 4: Lancer les tests et vérifier qu'ils passent**

Attendu : `TEST SUCCEEDED`, dix tests de `StatsBuilderTests` passants.

- [ ] **Step 5: Écrire l'écran**

Remplacer `ios-native/Optium/Stats/StatsScreen.swift` :

```swift
import Charts
import SwiftData
import SwiftUI

struct StatsScreen: View {
    @Query private var sessions: [FocusSession]

    private var stats: Stats {
        StatsBuilder.build(sessions: sessions, today: Date())
    }

    var body: some View {
        NavigationStack {
            List {
                let stats = stats

                Section("Aujourd’hui") {
                    row("Sessions terminées", "\(stats.todayCount)")
                    row("Temps de concentration", duration(stats.todaySeconds))
                    row("Série en cours", stats.streak <= 1 ? "\(stats.streak) jour" : "\(stats.streak) jours")
                }

                Section {
                    chart(stats.days)
                        .frame(height: 180)
                        .padding(.vertical, 8)
                } header: {
                    Text("14 derniers jours")
                } footer: {
                    Text("Minutes de concentration par jour.")
                }

                Section {
                    row("Concentration par jour", duration(stats.averageSeconds))
                    row("Sessions par jour", String(format: "%.1f", stats.averageCount))
                    row("Meilleur jour", stats.best.map { "\(duration($0.seconds)) · \(dayLabel($0.date))" } ?? "—")
                } header: {
                    Text("Moyennes")
                } footer: {
                    Text("Calculées sur les jours où au moins une session a été menée.")
                }
            }
            .navigationTitle("Statistiques")
        }
    }

    private func chart(_ days: [DayStat]) -> some View {
        Chart(days) { day in
            BarMark(
                x: .value("Jour", day.date, unit: .day),
                y: .value("Minutes", day.seconds / 60)
            )
            // Le jour courant se distingue des autres.
            .foregroundStyle(
                Calendar.current.isDateInToday(day.date) ? Color.accentColor : Color(.tertiaryLabel)
            )
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 3)) { value in
                AxisValueLabel(format: .dateTime.day())
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 44)
    }

    private func duration(_ seconds: Int) -> String {
        let minutes = Int((Double(seconds) / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest)"
    }

    private func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day())
    }
}
```

- [ ] **Step 6: Compiler et vérifier à l'écran**

Mener deux ou trois sessions courtes, puis contrôler que les compteurs du jour, l'histogramme et les moyennes bougent, et que la barre du jour courant se distingue.

- [ ] **Step 7: Commit**

```bash
cd /Users/svbri/optium-mobile
git add -A ios-native
git commit -m "Porter les statistiques

Les calculs sont separes de la vue et testes : la serie en cours ne casse
pas sur un jour courant vide, et les moyennes ne portent que sur les jours
actifs."
```

---

### Task 9: Maillage du cerveau

**Files:**
- Modify: `mobile/scripts/bake_brain.py`
- Create: `ios-native/Optium/Brain/BrainMesh.swift`
- Create: `ios-native/Optium/Resources/brain.bin` (généré)
- Test: `ios-native/OptiumTests/BrainMeshTests.swift`

**Interfaces:**
- Consumes: rien.
- Produces: `struct BrainMesh` avec `let positions: [Float]`, `let normals: [Float]`, `let indices: [UInt32]`, `let boundsMin: SIMD3<Float>`, `let boundsMax: SIMD3<Float>`, et `static func load(from data: Data) throws -> BrainMesh`, `static func loadFromBundle() throws -> BrainMesh`.

**Contexte de portage :** remplace `mobile/src/components/brain/parse-glb.ts` et `use-brain-model.ts`.

Le GLB était un format de transport que l'application devait décoder au démarrage. Puisqu'on regénère l'actif de toute façon, autant qu'il sorte dans la disposition mémoire exacte que Metal attend : le chargement se réduit à lire des octets.

**`brain.glb` continue d'être produit** pour l'application Expo, qui reste la référence de comparaison.

**Format de `brain.bin`**, petit-boutiste :

| Décalage | Type | Contenu |
|---|---|---|
| 0 | `char[4]` | Signature `OPTB` |
| 4 | `uint32` | Version, valeur 1 |
| 8 | `uint32` | Nombre de sommets |
| 12 | `uint32` | Nombre d'indices |
| 16 | `float32[3]` | Borne minimale |
| 28 | `float32[3]` | Borne maximale |
| 40 | `float32[3 × n]` | Positions |
| … | `float32[3 × n]` | Normales |
| … | `uint32[m]` | Indices |

- [ ] **Step 1: Lire le script existant**

```bash
sed -n '1,200p' /Users/svbri/optium-mobile/mobile/scripts/bake_brain.py
```

Repérer la structure finale qui contient positions, normales, indices et bornes — c'est le point d'insertion.

- [ ] **Step 2: Ajouter la sortie binaire au script**

Le script expose déjà tout ce qu'il faut dans `main` : `positions` et `normals` sont des **listes de triplets** (et non des listes plates), `indices` une liste plate d'entiers, `lo` et `hi` les bornes.

Ajouter cette fonction dans `mobile/scripts/bake_brain.py`, juste avant `def main(`, à la ligne 79 :

```python
def write_bin(path, positions, normals, indices, lo, hi):
    """Ecrit le maillage dans la disposition memoire attendue par Metal.

    Le GLB reste produit pour l'application Expo. Ce format-ci existe pour que
    l'application native n'ait aucun decodage a faire au demarrage : elle lit
    le fichier et le passe tel quel au GPU.
    """
    with open(path, "wb") as handle:
        handle.write(b"OPTB")
        handle.write(struct.pack("<III", 1, len(positions), len(indices)))
        handle.write(struct.pack("<3f", *lo))
        handle.write(struct.pack("<3f", *hi))
        for p in positions:
            handle.write(struct.pack("<3f", *p))
        for n in normals:
            handle.write(struct.pack("<3f", *n))
        for i in indices:
            handle.write(struct.pack("<I", i))
```

`struct` et `Path` sont déjà importés en tête du fichier.

Puis, à la toute fin de `main`, après la ligne `print(f"sortie    : {out_path} ...")`, ajouter :

```python
    bin_path = Path(out_path).with_suffix(".bin")
    write_bin(bin_path, positions, normals, indices, lo, hi)
    print(f"sortie    : {bin_path} ({bin_path.stat().st_size / 1024 / 1024:.2f} Mo)")
```

- [ ] **Step 3: Générer l'actif**

```bash
cd /Users/svbri/optium-mobile/mobile
python3 scripts/bake_brain.py ../public/scene.gltf assets/models/brain.glb
cp assets/models/brain.bin /Users/svbri/optium-mobile/ios-native/Optium/Resources/brain.bin
ls -la /Users/svbri/optium-mobile/ios-native/Optium/Resources/brain.bin
```

Vérifier que le fichier fait plusieurs centaines de kilooctets. Un fichier de quelques octets signale un échec silencieux.

- [ ] **Step 4: Écrire les tests qui échouent**

Créer `ios-native/OptiumTests/BrainMeshTests.swift` :

```swift
import Foundation
import Testing

@testable import Optium

/// Construit un fichier minimal au format attendu : un seul triangle.
private func makeData() -> Data {
    var data = Data("OPTB".utf8)
    for value in [UInt32(1), UInt32(3), UInt32(3)] {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    let floats: [Float] = [
        -1, -1, -1,   1, 1, 1,                    // bornes
        0, 0, 0,   1, 0, 0,   0, 1, 0,            // positions
        0, 0, 1,   0, 0, 1,   0, 0, 1,            // normales
    ]
    for value in floats {
        withUnsafeBytes(of: value.bitPattern.littleEndian) { data.append(contentsOf: $0) }
    }
    for value in [UInt32(0), UInt32(1), UInt32(2)] {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    return data
}

@Test func leMaillageSeLitDepuisSesOctets() throws {
    let mesh = try BrainMesh.load(from: makeData())

    #expect(mesh.positions.count == 9)
    #expect(mesh.normals.count == 9)
    #expect(mesh.indices == [0, 1, 2])
    #expect(mesh.boundsMin == SIMD3<Float>(-1, -1, -1))
    #expect(mesh.boundsMax == SIMD3<Float>(1, 1, 1))
}

@Test func uneSignatureInvalideEstRefusee() {
    var data = makeData()
    data.replaceSubrange(0..<4, with: Data("XXXX".utf8))

    #expect(throws: BrainMesh.LoadError.self) {
        try BrainMesh.load(from: data)
    }
}

@Test func unFichierTronqueEstRefuse() {
    let data = makeData().prefix(30)

    #expect(throws: BrainMesh.LoadError.self) {
        try BrainMesh.load(from: Data(data))
    }
}

@Test func leMaillageDuPaquetSeChargeEtNEstPasVide() throws {
    let mesh = try BrainMesh.loadFromBundle()

    #expect(mesh.positions.count > 0)
    #expect(mesh.positions.count == mesh.normals.count)
    #expect(mesh.indices.count % 3 == 0)
    // Le script centre et met a l'echelle : les bornes encadrent l'origine.
    #expect(mesh.boundsMin.y < 0)
    #expect(mesh.boundsMax.y > 0)
}
```

- [ ] **Step 5: Lancer les tests et vérifier qu'ils échouent**

Attendu : `cannot find 'BrainMesh' in scope`.

- [ ] **Step 6: Écrire le chargeur**

`ios-native/Optium/Brain/BrainMesh.swift` :

```swift
import Foundation
import simd

/// Maillage du cerveau, pre-calcule par `mobile/scripts/bake_brain.py`.
///
/// Le fichier est ecrit dans la disposition memoire que Metal attend : le
/// chargement se reduit a lire des octets, sans decodage ni recalcul au
/// demarrage. La coque et le fluide partagent cette geometrie unique et
/// tiennent chacun en un seul appel de dessin.
struct BrainMesh {
    let positions: [Float]
    let normals: [Float]
    let indices: [UInt32]
    let boundsMin: SIMD3<Float>
    let boundsMax: SIMD3<Float>

    enum LoadError: Error {
        case introuvable
        case signatureInvalide
        case versionInconnue(UInt32)
        case fichierTronque
    }

    private static let headerSize = 40

    static func load(from data: Data) throws -> BrainMesh {
        guard data.count >= headerSize else { throw LoadError.fichierTronque }
        guard data.prefix(4) == Data("OPTB".utf8) else { throw LoadError.signatureInvalide }

        let version: UInt32 = read(data, at: 4)
        guard version == 1 else { throw LoadError.versionInconnue(version) }

        let vertexCount = Int(read(data, at: 8) as UInt32)
        let indexCount = Int(read(data, at: 12) as UInt32)

        let floatCount = vertexCount * 3
        let expected = headerSize + (floatCount * 2) * 4 + indexCount * 4
        guard data.count >= expected else { throw LoadError.fichierTronque }

        let boundsMin = SIMD3<Float>(read(data, at: 16), read(data, at: 20), read(data, at: 24))
        let boundsMax = SIMD3<Float>(read(data, at: 28), read(data, at: 32), read(data, at: 36))

        var offset = headerSize
        let positions = readArray(data, at: &offset, count: floatCount) as [Float]
        let normals = readArray(data, at: &offset, count: floatCount) as [Float]
        let indices = readArray(data, at: &offset, count: indexCount) as [UInt32]

        return BrainMesh(
            positions: positions, normals: normals, indices: indices,
            boundsMin: boundsMin, boundsMax: boundsMax
        )
    }

    static func loadFromBundle() throws -> BrainMesh {
        guard let url = Bundle.main.url(forResource: "brain", withExtension: "bin") else {
            throw LoadError.introuvable
        }
        return try load(from: Data(contentsOf: url))
    }

    private static func read<T>(_ data: Data, at offset: Int) -> T {
        data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: T.self) }
    }

    private static func readArray<T>(_ data: Data, at offset: inout Int, count: Int) -> [T] {
        let size = MemoryLayout<T>.size
        let start = offset
        offset += count * size
        return data.withUnsafeBytes { raw in
            (0..<count).map { raw.loadUnaligned(fromByteOffset: start + $0 * size, as: T.self) }
        }
    }
}
```

- [ ] **Step 7: Lancer les tests et vérifier qu'ils passent**

Attendu : `TEST SUCCEEDED`, quatre tests de `BrainMeshTests` passants.

Si `leMaillageDuPaquetSeChargeEtNEstPasVide` échoue avec `introuvable`, c'est que `brain.bin` n'est pas embarqué : vérifier qu'il se trouve bien sous `ios-native/Optium/Resources/`.

- [ ] **Step 8: Commit**

```bash
cd /Users/svbri/optium-mobile
git add -A ios-native mobile/scripts/bake_brain.py mobile/assets/models
git commit -m "Faire sortir le maillage du cerveau en binaire

bake_brain.py produit desormais brain.bin en plus du GLB, dans la
disposition memoire attendue par Metal : l'application native n'a aucun
decodage a faire au demarrage.

Le GLB reste produit pour l'app Expo, qui sert de reference de comparaison."
```

---

### Task 10: Scène 3D

**Files:**
- Create: `ios-native/Optium/Brain/Shaders.metal`
- Create: `ios-native/Optium/Brain/BrainRenderer.swift`
- Create: `ios-native/Optium/Brain/BrainView.swift`
- Modify: `ios-native/Optium/Session/SessionScreen.swift`

**Interfaces:**
- Consumes: `BrainMesh` (Task 9), `TimerEngine`, `RootTab`.
- Produces: `struct BrainView: View`, `final class BrainRenderer: NSObject, MTKViewDelegate`.

**Contexte de portage :** équivalent de `mobile/src/components/brain/fluid-material.ts` et `brain-scene.tsx`.

**Les trois choix de rendu documentés dans `mobile/AGENTS.md` sont maintenus, et ce ne sont pas des préférences esthétiques :**

1. **Pas de `discard`.** Les GPU des iPhone rendent par tuiles : un shader capable de rejeter un fragment désactive l'élimination anticipée de profondeur pour tout le maillage. On module l'alpha à la place.
2. **Verre en Fresnel**, pas de matériau à transmission. La transmission imposerait une passe de rendu supplémentaire par image et une carte d'environnement téléchargée depuis un CDN, dont l'échec faisait disparaître toute la scène en silence.
3. **Rendu suspendu hors écran**, densité de pixels plafonnée à 2.

Le renderer lit `TimerEngine` **sans s'y abonner** : le minuteur change chaque seconde, et un abonnement provoquerait une réévaluation de vue à chaque fois alors que seule une valeur uniforme doit bouger.

- [ ] **Step 1: Écrire les shaders**

`ios-native/Optium/Brain/Shaders.metal` :

```metal
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4x4 modelViewProjection;
    float3x3 normalMatrix;
    float3 boundsMin;
    float3 boundsMax;
    float3 colorA;
    float3 colorB;
    float fillLevel;
    float time;
    float wobble;
};

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
};

struct FluidOut {
    float4 position [[position]];
    float3 localPosition;
    float3 normal;
    float  normalizedY;
};

vertex FluidOut fluid_vertex(VertexIn in [[stage_in]],
                             constant Uniforms &u [[buffer(1)]]) {
    FluidOut out;
    out.position = u.modelViewProjection * float4(in.position, 1.0);
    out.localPosition = in.position;
    out.normal = normalize(u.normalMatrix * in.normal);
    out.normalizedY = (in.position.y - u.boundsMin.y) / (u.boundsMax.y - u.boundsMin.y);
    return out;
}

static float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

fragment float4 fluid_fragment(FluidOut in [[stage_in]],
                               constant Uniforms &u [[buffer(1)]]) {
    float3 p = in.localPosition;

    // Surface du liquide : trois ondes de periodes differentes, un bruit
    // organique, et une secousse quand l'utilisateur fait tourner le modele.
    float wave = sin(p.x * 4.0 + u.time * 1.2) * 0.025
               + sin(p.z * 3.5 + u.time * 0.9) * 0.02
               + sin((p.x + p.z) * 2.5 + u.time * 0.6) * 0.015
               + noise(p.xz * 2.0 + u.time * 0.5) * 0.03
               + u.wobble * sin(p.x * 5.0 + u.time * 4.0) * 0.04;

    float fillEdge = u.fillLevel + wave;

    // Pas de `discard` : les GPU a tuiles des iPhone desactivent l'elimination
    // anticipee de profondeur pour tout le maillage des qu'un shader peut
    // rejeter un fragment. On module l'alpha a la place.
    float fill = 1.0 - smoothstep(fillEdge - 0.04, fillEdge + 0.04, in.normalizedY);

    float3 color = mix(u.colorA, u.colorB, in.normalizedY * 0.6 + 0.2);
    color *= 1.0 - in.normalizedY * 0.3;

    // Menisque : lisere clair a la surface du liquide.
    color += smoothstep(0.06, 0.0, abs(in.normalizedY - fillEdge)) * 0.4 * float3(0.6, 0.7, 1.0);

    float rim = pow(1.0 - abs(dot(in.normal, float3(0.0, 0.0, 1.0))), 2.5);
    color += rim * u.colorA * 0.3;

    return float4(color, fill * (0.55 + rim * 0.15));
}

struct ShellOut {
    float4 position [[position]];
    float3 normal;
    float3 viewDir;
};

vertex ShellOut shell_vertex(VertexIn in [[stage_in]],
                             constant Uniforms &u [[buffer(1)]]) {
    ShellOut out;
    float4 clip = u.modelViewProjection * float4(in.position, 1.0);
    out.position = clip;
    out.normal = normalize(u.normalMatrix * in.normal);
    out.viewDir = normalize(-in.position);
    return out;
}

/// Coque en verre.
///
/// Effet de Fresnel plutot qu'un materiau a transmission : celle-ci imposerait
/// une passe de rendu supplementaire par image et une carte d'environnement
/// telechargee, pour une lecture de verre equivalente a cette taille d'affichage.
fragment float4 shell_fragment(ShellOut in [[stage_in]],
                               constant Uniforms &u [[buffer(1)]]) {
    float fresnel = pow(1.0 - abs(dot(normalize(in.normal), normalize(in.viewDir))), 2.5);
    float3 tint = float3(0.812, 0.878, 1.0);
    float3 color = tint * (0.3 + fresnel * 1.7);
    return float4(color, 0.10 + fresnel * 0.7);
}
```

**Piege a surveiller : l'alignement de `Uniforms`.** La structure est declaree
deux fois, une fois en Swift et une fois en Metal, et rien ne verifie a la
compilation qu'elles concordent. Une divergence ne provoque pas d'erreur : elle
donne une scene deformee ou noire. L'ordre des champs adopte ici est deja aligne
(`float4x4` 64 octets, `float3x3` 48, `SIMD3<Float>` 16, `Float` 4, les trois
scalaires groupes en fin de structure). **Ne pas reordonner les champs d'un cote
sans l'autre.**

- [ ] **Step 2: Écrire le renderer**

`ios-native/Optium/Brain/BrainRenderer.swift` :

```swift
import MetalKit
import simd

/// Rendu de la scene.
///
/// Le renderer lit `TimerEngine` **sans s'y abonner** : le minuteur change
/// chaque seconde, et un abonnement provoquerait une reevaluation de vue a
/// chaque fois alors que seule une valeur uniforme doit bouger.
final class BrainRenderer: NSObject, MTKViewDelegate {

    private struct Uniforms {
        var modelViewProjection: float4x4
        var normalMatrix: float3x3
        var boundsMin: SIMD3<Float>
        var boundsMax: SIMD3<Float>
        var colorA: SIMD3<Float>
        var colorB: SIMD3<Float>
        var fillLevel: Float
        var time: Float
        var wobble: Float
    }

    /// Le fluide ne remplit jamais entierement la coque : un cerveau plein a ras
    /// bord se lit moins bien qu'un niveau qui laisse voir le verre.
    private static let maxFill: Float = 0.8

    private static let focusColorA = SIMD3<Float>(0.290, 0.565, 0.851)  // #4A90D9
    private static let focusColorB = SIMD3<Float>(0.424, 0.361, 0.906)  // #6C5CE7
    private static let restColorA  = SIMD3<Float>(0.180, 0.800, 0.443)  // #2ECC71
    private static let restColorB  = SIMD3<Float>(0.153, 0.682, 0.376)  // #27AE60

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let fluidPipeline: MTLRenderPipelineState
    private let shellPipeline: MTLRenderPipelineState
    private let positionBuffer: MTLBuffer
    private let normalBuffer: MTLBuffer
    private let indexBuffer: MTLBuffer
    private let indexCount: Int
    private let mesh: BrainMesh

    /// Etat anime, entretenu image par image.
    private var fillLevel: Float = Self.maxFill
    private var colorA = Self.focusColorA
    private var colorB = Self.focusColorB
    private var rotation: Float = 0
    private var elapsed: Float = 0
    private var wobble: Float = 0
    private var aspect: Float = 1

    /// Vitesse imprimee par le geste de rotation, decroissante.
    var dragVelocity: Float = 0
    /// Progression restante de la session, 0…1, poussee par la vue.
    var progress: Float = 1
    /// Vrai en concentration, faux en repos.
    var isFocus = true

    init?(view: MTKView, mesh: BrainMesh) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else { return nil }

        self.device = device
        self.queue = queue
        self.mesh = mesh
        self.indexCount = mesh.indices.count

        guard let positionBuffer = device.makeBuffer(
                bytes: mesh.positions,
                length: mesh.positions.count * MemoryLayout<Float>.size),
              let normalBuffer = device.makeBuffer(
                bytes: mesh.normals,
                length: mesh.normals.count * MemoryLayout<Float>.size),
              let indexBuffer = device.makeBuffer(
                bytes: mesh.indices,
                length: mesh.indices.count * MemoryLayout<UInt32>.size)
        else { return nil }

        self.positionBuffer = positionBuffer
        self.normalBuffer = normalBuffer
        self.indexBuffer = indexBuffer

        let descriptor = MTLVertexDescriptor()
        descriptor.attributes[0].format = .float3
        descriptor.attributes[0].bufferIndex = 0
        descriptor.attributes[0].offset = 0
        descriptor.attributes[1].format = .float3
        descriptor.attributes[1].bufferIndex = 2
        descriptor.attributes[1].offset = 0
        descriptor.layouts[0].stride = MemoryLayout<Float>.size * 3
        descriptor.layouts[2].stride = MemoryLayout<Float>.size * 3

        func pipeline(_ vertexName: String, _ fragmentName: String) -> MTLRenderPipelineState? {
            let pipe = MTLRenderPipelineDescriptor()
            pipe.vertexFunction = library.makeFunction(name: vertexName)
            pipe.fragmentFunction = library.makeFunction(name: fragmentName)
            pipe.vertexDescriptor = descriptor
            pipe.colorAttachments[0].pixelFormat = view.colorPixelFormat
            pipe.colorAttachments[0].isBlendingEnabled = true
            pipe.colorAttachments[0].rgbBlendOperation = .add
            pipe.colorAttachments[0].alphaBlendOperation = .add
            pipe.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipe.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipe.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipe.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try? device.makeRenderPipelineState(descriptor: pipe)
        }

        guard let fluid = pipeline("fluid_vertex", "fluid_fragment"),
              let shell = pipeline("shell_vertex", "shell_fragment") else { return nil }

        self.fluidPipeline = fluid
        self.shellPipeline = shell
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        aspect = size.height == 0 ? 1 : Float(size.width / size.height)
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let buffer = queue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        let delta: Float = 1.0 / Float(max(1, view.preferredFramesPerSecond))
        elapsed += delta

        // En concentration, le fluide se vide au fil de la session ; en repos,
        // il se remplit. Le niveau glisse vers sa cible plutot que d'y sauter.
        let target = (isFocus ? progress : 1 - progress) * Self.maxFill
        fillLevel += (target - fillLevel) * 0.05

        wobble = min(1, wobble * 0.95 + abs(dragVelocity) * 0.6)
        dragVelocity *= 0.9

        colorA = mix(colorA, isFocus ? Self.focusColorA : Self.restColorA, t: 0.02)
        colorB = mix(colorB, isFocus ? Self.focusColorB : Self.restColorB, t: 0.02)

        rotation += delta * 0.3 + dragVelocity
        // Leger flottement vertical et roulis, pour que la scene ne paraisse
        // jamais figee.
        let bob = sin(elapsed * 1.0) * 0.06
        let tilt = sin(elapsed * 0.6) * 0.04

        var uniforms = makeUniforms(rotation: rotation, bob: bob, tilt: tilt)

        encoder.setVertexBuffer(positionBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(normalBuffer, offset: 0, index: 2)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

        // Le fluide d'abord, la coque par dessus : le verre doit se composer
        // sur le liquide. Aucun des deux n'ecrit dans le tampon de profondeur.
        encoder.setRenderPipelineState(fluidPipeline)
        encoder.setCullMode(.none)
        encoder.drawIndexedPrimitives(
            type: .triangle, indexCount: indexCount,
            indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0
        )

        encoder.setRenderPipelineState(shellPipeline)
        // Face avant uniquement : moitie moins de fragments, pour une
        // difference invisible sur une coque translucide.
        encoder.setCullMode(.back)
        encoder.drawIndexedPrimitives(
            type: .triangle, indexCount: indexCount,
            indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0
        )

        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()
    }

    private func makeUniforms(rotation: Float, bob: Float, tilt: Float) -> Uniforms {
        let model = translation(0, bob, 0) * rotationY(rotation) * rotationX(tilt)
        let view = translation(0, 0, -5.5)
        let projection = perspective(fovRadians: 40 * .pi / 180, aspect: aspect, near: 0.1, far: 100)

        let modelView = view * model
        let normal = float3x3(
            SIMD3(modelView.columns.0.x, modelView.columns.0.y, modelView.columns.0.z),
            SIMD3(modelView.columns.1.x, modelView.columns.1.y, modelView.columns.1.z),
            SIMD3(modelView.columns.2.x, modelView.columns.2.y, modelView.columns.2.z)
        )

        return Uniforms(
            modelViewProjection: projection * modelView,
            normalMatrix: normal,
            boundsMin: mesh.boundsMin,
            boundsMax: mesh.boundsMax,
            colorA: colorA,
            colorB: colorB,
            fillLevel: fillLevel,
            time: elapsed,
            wobble: wobble
        )
    }

    private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        a + (b - a) * t
    }
}

// ── Matrices ──

private func translation(_ x: Float, _ y: Float, _ z: Float) -> float4x4 {
    var m = matrix_identity_float4x4
    m.columns.3 = SIMD4(x, y, z, 1)
    return m
}

private func rotationY(_ angle: Float) -> float4x4 {
    let c = cos(angle), s = sin(angle)
    return float4x4(
        SIMD4(c, 0, -s, 0), SIMD4(0, 1, 0, 0), SIMD4(s, 0, c, 0), SIMD4(0, 0, 0, 1)
    )
}

private func rotationX(_ angle: Float) -> float4x4 {
    let c = cos(angle), s = sin(angle)
    return float4x4(
        SIMD4(1, 0, 0, 0), SIMD4(0, c, s, 0), SIMD4(0, -s, c, 0), SIMD4(0, 0, 0, 1)
    )
}

private func perspective(fovRadians: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
    let y = 1 / tan(fovRadians * 0.5)
    let x = y / aspect
    let z = far / (near - far)
    return float4x4(
        SIMD4(x, 0, 0, 0), SIMD4(0, y, 0, 0), SIMD4(0, 0, z, -1), SIMD4(0, 0, z * near, 0)
    )
}
```

- [ ] **Step 3: Écrire le pont SwiftUI**

`ios-native/Optium/Brain/BrainView.swift` :

```swift
import MetalKit
import SwiftUI

struct BrainView: UIViewRepresentable {
    /// Progression restante de la session, 0…1.
    let progress: Double
    let isFocus: Bool
    /// Le rendu est totalement suspendu quand la scene n'est pas visible :
    /// sans cela, la boucle continuerait a 60 images par seconde et viderait
    /// la batterie pendant qu'on consulte ses statistiques.
    let isVisible: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm
        view.isOpaque = false
        view.backgroundColor = .clear
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 60
        // Les ecrans d'iPhone sont en densite 3. Rendre a cette densite triple
        // le nombre de fragments pour un gain invisible sur un contenu aussi
        // diffus : on plafonne a 2.
        view.contentScaleFactor = min(view.traitCollection.displayScale, 2)

        guard let mesh = try? BrainMesh.loadFromBundle(),
              let renderer = BrainRenderer(view: view, mesh: mesh) else {
            // Sans maillage ni GPU, la vue reste transparente : l'ecran Session
            // demeure parfaitement utilisable sans sa decoration.
            return view
        }

        context.coordinator.renderer = renderer
        view.delegate = renderer

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        view.addGestureRecognizer(pan)

        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.renderer?.progress = Float(progress)
        context.coordinator.renderer?.isFocus = isFocus
        view.isPaused = !isVisible
    }

    final class Coordinator {
        var renderer: BrainRenderer?

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let velocity = gesture.velocity(in: gesture.view).x
            renderer?.dragVelocity = Float(velocity) / 12_000
        }
    }
}
```

- [ ] **Step 4: Brancher la scène dans l'écran Session**

Dans `ios-native/Optium/Session/SessionScreen.swift`, remplacer le corps de `sceneArea` :

```swift
    @ViewBuilder
    private var sceneArea: some View {
        if settings.brainEnabled {
            BrainView(
                // Le fluide suit le temps restant, pas le temps ecoule.
                progress: timer.total == 0 ? 1 : Double(timer.remaining) / Double(timer.total),
                isFocus: timer.mode == .focus,
                isVisible: selectedTab == .session && scenePhase == .active
            )
            .frame(maxHeight: .infinity)
            .padding(.bottom, 260)
        } else {
            Text("Visualisation désactivée")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxHeight: .infinity)
        }
    }
```

- [ ] **Step 5: Compiler**

```bash
cd ios-native && xcodebuild -project Optium.xcodeproj -scheme Optium \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD"
```

Attendu : `BUILD SUCCEEDED`. Les erreurs de compilation Metal apparaissent aussi sous `error:`.

- [ ] **Step 6: Vérifier à l'écran, contre l'application Expo**

Lancer les deux applications côte à côte — le simulateur pour la native, Expo Go pour la référence. Contrôler :
- le cerveau apparaît, tourne lentement, flotte légèrement ;
- le fluide bleu-violet occupe environ 80 % de la hauteur au départ ;
- pendant une session, le niveau **descend** ; en pause, il **monte** ;
- les couleurs glissent vers le vert au passage en pause, sans à-coup ;
- glisser horizontalement fait tourner le cerveau et secoue le liquide ;
- le liséré clair suit la surface du liquide ;
- passer sur l'onglet Statistiques puis revenir : le rendu reprend là où il en était.

Vérifier enfin la consommation : dans Xcode, ouvrir le navigateur de debug pendant que l'onglet Statistiques est affiché. L'usage GPU doit tomber à zéro — c'est la preuve que `isPaused` fonctionne.

- [ ] **Step 7: Commit**

```bash
cd /Users/svbri/optium-mobile
git add -A ios-native
git commit -m "Porter la scene 3D en Metal

Les deux shaders passent en Metal Shading Language, et les trois choix de
rendu documentes dans AGENTS.md sont maintenus : pas de discard, qui
desactiverait l'elimination anticipee de profondeur sur les GPU a tuiles
des iPhone ; verre en Fresnel plutot qu'a transmission ; rendu suspendu
hors ecran et densite de pixels plafonnee a 2.

Le renderer lit le minuteur sans s'y abonner : seule une valeur uniforme
doit bouger chaque seconde, pas une vue."
```

---

## Après le plan

À la fin de la Task 10, l'application native est à parité de périmètre avec l'application Expo, sans la génération de tâches par IA.

Restent hors périmètre, chacun méritant son propre cadrage : l'IA et la couche Supabase, la Live Activity et le Dynamic Island, les widgets, les raccourcis Siri, la synchronisation iCloud, la reprise des données existantes depuis l'application Expo, et le sort du code Expo une fois la parité constatée.

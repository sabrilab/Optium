import Foundation
import Observation

/// Reglages de l'application.
///
/// Ils tiennent en une poignee de scalaires : un `@Model` SwiftData serait
/// demesure. `@AppStorage` n'est pas utilisable hors d'une vue SwiftUI, on
/// ecrit donc dans `UserDefaults` depuis un `didSet` — ce qui a l'avantage de
/// rendre la source injectable en test.
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: Key.haptics) } }
    /// Coupe la 3D : economise la batterie et debloque les appareils lents.
    var brainEnabled: Bool { didSet { defaults.set(brainEnabled, forKey: Key.brain) } }

    /// Vrai une fois que le message de franchissement a ete montre.
    ///
    /// Une seule fois : le repeter le transformerait en rappel, et
    /// l'application n'en a que deux, toutes deux programmees.
    var hasSeenThreshold: Bool { didSet { defaults.set(hasSeenThreshold, forKey: Key.threshold) } }

    /// Clarte forcee, ou `nil` pour la mesure reelle.
    ///
    /// Outil de developpement, et il le restera : la porte ne se declenche
    /// qu'a clarte basse, et attendre une mauvaise nuit pour l'eprouver
    /// rendrait toute verification impraticable.
    var clarityOverride: ClarityLevel? {
        didSet { defaults.set(clarityOverride?.rawValue ?? "", forKey: Key.clarity) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        brainEnabled = defaults.object(forKey: Key.brain) as? Bool ?? true
        hasSeenThreshold = defaults.object(forKey: Key.threshold) as? Bool ?? false
        clarityOverride = (defaults.object(forKey: Key.clarity) as? String)
            .flatMap(ClarityLevel.init(rawValue:))
    }

    private enum Key {
        static let haptics = "hapticsEnabled"
        static let brain = "brainEnabled"
        static let threshold = "hasSeenThreshold"
        static let clarity = "simulatedClarity"
    }
}

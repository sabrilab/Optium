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
        clarityOverride = (defaults.object(forKey: Key.clarity) as? String)
            .flatMap(ClarityLevel.init(rawValue:))
    }

    private enum Key {
        static let haptics = "hapticsEnabled"
        static let brain = "brainEnabled"
        static let clarity = "simulatedClarity"
    }
}

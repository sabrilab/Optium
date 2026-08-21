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

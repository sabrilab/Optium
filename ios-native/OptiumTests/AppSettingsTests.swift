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

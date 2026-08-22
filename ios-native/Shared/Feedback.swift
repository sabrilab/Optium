import CoreHaptics
import UIKit

/// Le vocabulaire tactile de l'application.
///
/// **Des moments, jamais des intensites.** Un appelant qui ecrit
/// `impact(.medium)` decide d'une sensation ; un appelant qui ecrit
/// `.threadClosed` decide d'un sens, et la sensation se regle ici, une fois,
/// pour toute l'application. C'est la seule facon de garder une main coherente
/// quand les gestes se multiplient.
///
/// **Le reglage « Vibrations » existait et ne coupait rien** : il s'ecrivait
/// dans `UserDefaults` et aucun code ne le lisait. Il est desormais la seule
/// porte d'entree.
@MainActor
enum Feedback {
    /// Renseigne depuis `RootView`. Faux coupe tout, sans exception.
    static var isEnabled = true

    /// Ce qui peut arriver, et ce que ca doit faire au poignet.
    enum Moment {
        /// Un fil s'ouvre. Le geste le plus frequent : il doit rester discret.
        case threadOpened
        /// Un fil se ferme sans passer par la porte.
        case threadClosed
        /// Un fil se ferme en ayant traverse la porte. Plus appuye : ce n'est
        /// pas la meme chose, et la main doit le savoir.
        case threadClosedThroughGate
        /// La porte s'ouvre.
        case gate
        /// Retenu jusqu'a la prochaine fenetre. Descendant, jamais punitif.
        case held
        /// Un cafe est note.
        case coffee
        /// Une reponse de calibration.
        case answered
        /// Le palier change. Rare, et c'est ce qui lui donne son poids.
        case tierChanged
    }

    static func play(_ moment: Moment) {
        guard isEnabled else { return }

        switch moment {
        case .threadOpened, .coffee:
            impact(.light)
        case .answered:
            selection.selectionChanged()
            selection.prepare()
        case .threadClosed:
            notification.notificationOccurred(.success)
        case .threadClosedThroughGate, .tierChanged:
            // Deux frappes montantes : quelque chose s'est acheve, et il a
            // fallu passer par quelque part.
            sequence([(0, 0.6, 0.4), (0.11, 1.0, 0.7)])
        case .gate:
            // **Un arret, pas une erreur.** Le motif systeme `.error` est
            // sec et se lit comme une faute alors que la porte ne reproche
            // rien : elle interrompt. D'ou deux frappes sourdes puis un appui
            // tenu — la sensation d'une main posee, pas d'un rejet.
            sequence([(0, 0.5, 0.2), (0.13, 0.5, 0.2)], sustain: (0.30, 0.55, 0.9, 0.35))
        case .held:
            // Descendante : ce qui vient d'arriver, c'est que quelque chose
            // s'eloigne.
            sequence([(0, 0.9, 0.6), (0.10, 0.45, 0.25)])
        }
    }

    /// Le cerveau qu'on fait tourner.
    ///
    /// Des crans, pas une vibration continue : la main lit une molette, et un
    /// bourdonnement pendant tout le geste fatiguerait au bout de trois
    /// secondes. L'intensite suit la vitesse — tourner lentement doit se
    /// sentir moins que lancer la scene.
    static func brainTurned(by radians: Double, speed: Double) {
        guard isEnabled else { return }
        turned += abs(radians)
        guard turned >= 0.30 else { return }
        turned = 0
        soft.impactOccurred(intensity: min(0.85, max(0.18, speed)))
    }

    private static var turned = 0.0

    // ── Details ──

    // **Les generateurs sont retenus, et c'est la tout le sujet.**
    //
    // Ils etaient crees en variables locales : `UIImpactFeedbackGenerator(...)`,
    // `prepare()`, `impactOccurred()`, puis l'objet etait relache dans la
    // foulee. Un generateur libere avant que le moteur ait joue ne produit
    // rien — la plupart des gestes etaient muets alors que le code les
    // appelait bien. Retenus, ils restent en outre prepares, et le retour
    // arrive avec le geste au lieu d'arriver apres.
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    /// A appeler des qu'un geste devient probable : le moteur monte en
    /// puissance et le retour suivant est immediat.
    static func prepare() {
        guard isEnabled else { return }
        light.prepare()
        soft.prepare()
        selection.prepare()
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = style == .light ? light : medium
        generator.impactOccurred()
        generator.prepare()
    }

    /// Le moteur, cree paresseusement et garde.
    ///
    /// Le recreer a chaque motif coute quelques dizaines de millisecondes et
    /// se sent : le retour arrive apres le geste au lieu de l'accompagner.
    private static let engine: CHHapticEngine? = {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        let engine = try? CHHapticEngine()
        // iOS arrete le moteur quand l'application passe en fond ; sans cette
        // reprise, tous les retours suivants sont muets et rien ne le signale.
        engine?.resetHandler = { try? engine?.start() }
        engine?.stoppedHandler = { _ in }
        try? engine?.start()
        return engine
    }()

    /// - Parameters:
    ///   - taps: `(instant, intensite, nettete)`.
    ///   - sustain: `(instant, duree, intensite, nettete)`, optionnel.
    private static func sequence(
        _ taps: [(TimeInterval, Float, Float)],
        sustain: (TimeInterval, TimeInterval, Float, Float)? = nil
    ) {
        guard let engine else {
            // Sans moteur — iPhone ancien, simulateur — on retombe sur le
            // retour standard plutot que de ne rien produire.
            impact(.medium)
            return
        }

        var events = taps.map { tap in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: tap.1),
                    .init(parameterID: .hapticSharpness, value: tap.2),
                ],
                relativeTime: tap.0
            )
        }
        if let sustain {
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: sustain.2),
                    .init(parameterID: .hapticSharpness, value: sustain.3),
                ],
                relativeTime: sustain.0,
                duration: sustain.1
            ))
        }

        guard let pattern = try? CHHapticPattern(events: events, parameters: []),
              let player = try? engine.makePlayer(with: pattern) else {
            impact(.medium)
            return
        }
        try? player.start(atTime: CHHapticTimeImmediate)
    }
}

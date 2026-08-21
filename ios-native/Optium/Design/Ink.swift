import SwiftUI

/// Vocabulaire chromatique de l'application.
///
/// Optium ne suit plus l'apparence d'iOS : le noir est permanent et decide.
/// C'est un choix de direction artistique, pas un oubli — la scene 3D, les
/// auras et les cartes ne fonctionnent que sur un noir vrai, et un fond qui
/// blanchirait en mode clair les effacerait toutes.
///
/// Les valeurs sont donc litterales par necessite. Les seules couleurs encore
/// semantiques sont celles du texte, qui restent `.primary` et `.secondary` :
/// elles suivent le mode sombre force au niveau de la racine, et gardent les
/// rapports de contraste d'Apple.
enum Ink {
    /// Noir vrai. Pas un bleu nuit : le fond doit disparaitre, pas participer.
    static let canvas = Color.black

    /// Surface d'une carte posee sur le noir. Assez claire pour se detacher,
    /// assez sombre pour ne pas rivaliser avec son contenu.
    static let surface = Color(red: 0.075, green: 0.075, blue: 0.082)
    static let surfaceRaised = Color(red: 0.114, green: 0.114, blue: 0.125)

    static let hairline = Color.white.opacity(0.08)

    // ── Teintes d'ambiance ──
    // Une paire par mode : l'aura les melange en degrade radial.

    static let focusGlow = Color(red: 0.298, green: 0.373, blue: 0.965)
    static let focusGlowFar = Color(red: 0.541, green: 0.259, blue: 0.898)

    static let restGlow = Color(red: 0.086, green: 0.741, blue: 0.573)
    static let restGlowFar = Color(red: 0.024, green: 0.541, blue: 0.510)

    /// Accent des graduations et des reperes. Le jaune-vert ne rappelle aucune
    /// des deux ambiances, ce qui le rend lisible dans les deux.
    static let marker = Color(red: 0.851, green: 0.918, blue: 0.353)

    static func glow(isFocus: Bool) -> Color { isFocus ? focusGlow : restGlow }
    static func glowFar(isFocus: Bool) -> Color { isFocus ? focusGlowFar : restGlowFar }
}

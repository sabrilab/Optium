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
    //
    // Une seule famille par mode, deux nuances chacune. La tentation est de
    // varier les teintes d'une carte a l'autre pour « animer » un ecran ;
    // c'est ce qui le fait paraitre bricole. La hierarchie se fait par la
    // valeur — une carte plus importante est plus lumineuse, pas d'une autre
    // couleur.

    static let focusGlow = Color(red: 0.322, green: 0.325, blue: 0.941)
    static let focusGlowFar = Color(red: 0.541, green: 0.290, blue: 0.867)

    static let restGlow = Color(red: 0.086, green: 0.647, blue: 0.588)
    static let restGlowFar = Color(red: 0.157, green: 0.463, blue: 0.612)

    /// Accent des graduations et du jour courant. Unique couleur franche de
    /// l'application, et c'est ce qui lui donne sa valeur : elle ne signale
    /// qu'une chose, le present.
    static let marker = Color(red: 0.839, green: 0.910, blue: 0.365)

    static func glow(isFocus: Bool) -> Color { isFocus ? focusGlow : restGlow }
    static func glowFar(isFocus: Bool) -> Color { isFocus ? focusGlowFar : restGlowFar }
}

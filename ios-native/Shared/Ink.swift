import Foundation
import SwiftUI
import UIKit

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
    // Deux teintes par mode pour la scene 3D et la surface active.

    static let focusGlow = Color(red: 0.322, green: 0.325, blue: 0.941)
    static let focusGlowFar = Color(red: 0.541, green: 0.290, blue: 0.867)

    static let restGlow = Color(red: 0.086, green: 0.647, blue: 0.588)
    static let restGlowFar = Color(red: 0.157, green: 0.463, blue: 0.612)

    /// Accent des graduations et du present. Unique couleur franche hors
    /// cartes, et c'est ce qui lui donne sa valeur : elle ne signale qu'une
    /// chose, l'instant courant ou la position de l'utilisateur.
    static let marker = Color(red: 0.839, green: 0.910, blue: 0.365)

    // ── Teintes de carte ──
    //
    // Six teintes, et non une seule famille. La variete n'est pas ce qui fait
    // paraitre un ecran bricole — ce sont des teintes *sans parente*. Un bleu
    // de tableur a cote d'un vert pomme et d'un olive n'appartiennent a rien
    // ensemble.
    //
    // Celles-ci sont choisies au meme registre : meme saturation, meme valeur,
    // aucune plus claire ni plus criarde que les autres. Traitees au lavis a
    // coeur sombre, elles se lisent comme une famille d'egales. C'est ce que
    // font les references qui ont nourri cette direction, qui melangent
    // librement rose, bleu, vert et ambre sur un meme ecran.
    //
    // **Chaque carte est d'une seule couleur.**
    //
    // Une teinte, et rien d'autre : elle se diffuse, elle s'eteint vers le
    // noir, elle se rallume sur une arete — mais elle ne rencontre jamais une
    // autre couleur. C'est ce fondu d'un ton unique qui laisse le texte
    // lisible ; deux tons qui se croisent produisent au milieu une valeur
    // qu'on ne controle plus, et la ou passe une ligne de texte, ca se paye.
    //
    // Une contre-teinte a ete essayee — un ton etranger pose en bas de carte —
    // pour rendre les cartes plus vives. Elle les rendait surtout multicolores,
    // et changeait la direction artistique. Retiree.
    //
    // **La regle est tenue par construction, pas par discipline.** `accent`
    // n'est pas une seconde couleur qu'on choisit : c'est `tint` eclaircie,
    // calculee. On ne peut donc pas en glisser une autre sans reecrire le
    // type, ce qui est exactement l'intention.

    struct CardHue {
        let tint: Color

        /// Le meme ton, eclairci. **Jamais une autre couleur.**
        ///
        /// Sert a rallumer l'arete haute et le second foyer : sans ecart de
        /// valeur, la carte serait un aplat. L'ecart est de clarte, pas de
        /// teinte.
        var accent: Color { tint.lightened(by: 0.26) }
    }

    static let indigo = CardHue(tint: Color(red: 0.322, green: 0.325, blue: 0.941))
    static let violet = CardHue(tint: Color(red: 0.541, green: 0.290, blue: 0.867))
    static let rose = CardHue(tint: Color(red: 0.820, green: 0.278, blue: 0.561))
    static let teal = CardHue(tint: Color(red: 0.086, green: 0.647, blue: 0.588))
    static let amber = CardHue(tint: Color(red: 0.851, green: 0.565, blue: 0.235))
    static let coral = CardHue(tint: Color(red: 0.878, green: 0.341, blue: 0.310))

    /// Les six, dans l'ordre ou elles se suivent le mieux.
    static let cardHues = [indigo, violet, rose, teal, amber, coral]

    /// Teint des commandes.
    ///
    /// `buttonStyle(.glass)` prend sa couleur de libelle dans le teint ambiant,
    /// pas dans un `foregroundStyle` pose sur le contenu — celui-ci est
    /// ecrase. Les commandes sont donc mises au blanc a la source : le verre
    /// suffit a les designer, et une teinte de plus sur chaque bouton dilue
    /// l'unique couleur franche de l'application.
    static let control = Color.white

    static func glow(isFocus: Bool) -> Color { isFocus ? focusGlow : restGlow }
    static func glowFar(isFocus: Bool) -> Color { isFocus ? focusGlowFar : restGlowFar }
}

/// Le format d'heure de l'application.
///
/// Un seul, partout. Le format court du systeme rend « 5:36 » quand la
/// justification de la porte ecrit « 8 h 16 » : deux graphies cote a cote sur
/// le meme ecran se remarquent immediatement.
enum Clock {
    // `nonisolated` : un formatage de date n'a aucune raison d'exiger le fil
    // principal, et les outils de l'appel le consultent hors de celui-ci.
    nonisolated static func hhmm(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%d h %02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}


extension Color {
    /// Le meme ton, plus clair.
    ///
    /// On passe par la teinte-saturation-luminosite pour ne toucher qu'a la
    /// luminosite : eclaircir en poussant les composantes rouge, verte et
    /// bleue vers le blanc derive la teinte, et c'est precisement ce que la
    /// regle d'une seule couleur par carte interdit.
    func lightened(by amount: Double) -> Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getHue(&hue, saturation: &saturation,
                                   brightness: &brightness, alpha: &alpha) else { return self }
        return Color(
            hue: Double(hue),
            // La saturation baisse un peu avec la montee en luminosite : une
            // couleur claire et pleinement saturee se lit comme fluorescente.
            saturation: Double(saturation) * (1 - amount * 0.35),
            brightness: min(1, Double(brightness) + amount)
        )
    }
}

import SwiftUI

/// Le sceau de la porte.
///
/// **Il transforme un refus subi en refus annonce, sans ecrire une phrase.**
/// Choisir « Decision » est le seul geste qui arme le refus de l'application,
/// et il etait traite comme les deux autres natures : un bouton radio et une
/// legende. La porte arrivait donc toujours par surprise — le contraire de ce
/// qu'on veut d'un mecanisme qu'on demande aux gens d'accepter.
///
/// Il porte trois faits a lui seul, selon l'endroit ou il apparait :
///
/// - dans le compositeur, des que « Decision » est choisie → *ce fil peut
///   m'arreter* ;
/// - sur la ligne du fil, dans la liste → *lequel de mes fils peut m'arreter* ;
/// - **vif quand la clarte est basse, eteint sinon** → *maintenant, il
///   m'arreterait*.
///
/// **Le troisieme etat vaut bien plus depuis que la clarte vit dans la
/// journee.** Le sceau ne dit plus « ce fil est une decision » : il s'allume
/// au creux de l'apres-midi et s'eteint au rebond du soir. C'est une propriete
/// du monde qui change, pas un retour a une action — d'ou l'absence
/// d'animation d'entree, et l'hysteresis du moteur qui l'empeche de clignoter.
struct GateSeal: View {
    /// Vrai quand la porte s'ouvrirait a cet instant.
    let isArmed: Bool
    var size: CGFloat = 13

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "door.left.hand.closed")
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(isArmed ? Ink.marker : Color.white.opacity(0.30))
            // Le battement ne se declenche que quand la porte est armee, et
            // seulement si le mouvement est autorise. Il n'ajoute aucune
            // information : il rattrape l'attention sur un signe de treize
            // points.
            .symbolEffect(.pulse, options: .repeating, isActive: isArmed && !reduceMotion)
            .animation(Motion.state, value: isArmed)
            .accessibilityLabel(isArmed
                ? "Décision — Optium t’arrêterait maintenant"
                : "Décision — Optium ne t’arrêterait pas maintenant")
    }
}

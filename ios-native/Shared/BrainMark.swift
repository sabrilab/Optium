import SwiftUI
import UIKit

/// Le reperage d'un palier : le symbole `brain` d'Apple, rempli par le bas.
///
/// **Un symbole systeme plutot qu'un trace invente.** Ce role etait tenu par
/// `BrainSilhouette`, un contour extrait du maillage 3D : fidele, mais dessine
/// pour etre vu grand, et aux tailles ou il servait vraiment — vingt-six
/// points dans l'echelle, vingt-deux dans l'ile dynamique — il se refermait en
/// tache. Il a ete supprime plutot que garde en reserve : deux representations
/// du meme organe finissent toujours par diverger. Le
/// symbole d'Apple est hinte pour ces tailles, il porte les memes graisses que
/// le reste de l'interface, et c'est deja lui qui designe l'onglet
/// « Aujourd'hui » : le meme signe pour la meme chose, de la barre d'onglets
/// jusqu'a l'ecran verrouille.
///
/// Il n'est pas repris tel quel : il sert de masque a un degrade qui monte
/// depuis le bas, de sorte que le palier se lise comme un niveau et non comme
/// une icone allumee ou eteinte.
struct BrainMark: View {
    /// Niveau atteint, 0…1.
    let fill: Double
    /// Plafond permis par la nuit, 0…1.
    var base: Double = 1
    var tint: Color = Ink.marker
    /// Le second ton du degrade. C'est lui qui empeche le remplissage de se
    /// lire comme un aplat.
    var far: Color = Ink.focusGlowFar
    /// Montre le plafond. Faux la ou la place manque pour deux informations.
    var showsBase = false

    /// Les proportions du glyphe, mesurees une fois.
    ///
    /// **Le niveau se mesure sur le dessin, pas sur le cadre.** `brain` est
    /// plus large que haut ; dans un cadre carre, un palier bas — `murky` est
    /// a 0,16 — tomberait sous le dessin et n'allumerait rien du tout.
    /// Contraindre le conteneur aux proportions du glyphe fait coincider les
    /// deux, et laisse les appelants poser le `frame` qu'ils veulent.
    private static let aspect: CGFloat = {
        guard let size = UIImage(systemName: "brain")?.size, size.height > 0 else { return 1 }
        return size.width / size.height
    }()

    private var symbol: some View {
        Image(systemName: "brain")
            .resizable()
            .scaledToFit()
    }

    private var level: Double { min(1, max(0, fill)) }
    private var ceiling: Double { min(1, max(0, base)) }

    var body: some View {
        ZStack {
            // Le contour reste visible sous le niveau : sans lui, un palier bas
            // ne serait qu'un fragment flottant, sans forme a completer.
            symbol.foregroundStyle(tint.opacity(0.20))

            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: [far, tint],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: proxy.size.height * level)

                    // Le plafond : un trait, pas un remplissage. Il dit
                    // jusqu'ou la nuit permet de monter, ce qui n'a de sens
                    // que comme limite.
                    if showsBase && ceiling < 1 {
                        Rectangle()
                            .fill(tint.opacity(0.55))
                            .frame(height: 1.5)
                            .offset(y: -proxy.size.height * ceiling)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .mask { symbol }
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
    }
}

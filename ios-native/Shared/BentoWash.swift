import SwiftUI

/// Le lavis d'une carte : **la couleur, sans le verre**.
///
/// Il vivait dans `BentoSurface`, cote application seulement, et les widgets
/// se contentaient d'un noir plat. Ils ne se ressemblaient donc pas, alors
/// qu'ils montrent la meme chose — c'est le meme objet, pose ailleurs.
///
/// **Le verre ne peut pas les suivre.** `glassEffect` demande un rendu en
/// temps reel ; un widget est une image calculee a l'avance par le systeme, et
/// une activite en direct l'est presque autant. Le lavis, lui, se calcule une
/// fois et se transporte partout. C'est de toute facon lui qui porte
/// l'identite : le verre n'est qu'une matiere posee dessus.
///
/// Voir `BentoSurface` pour le raisonnement complet sur la forme du lavis —
/// remplissage bord a bord, coeur sombre decale, arete haute rallumee.
struct BentoWash: View {
    var tint: Color = Ink.indigo.tint
    /// Le meme ton, eclairci. **Jamais une autre couleur** : une carte est
    /// d'une seule teinte, et l'ecart est de clarte.
    var accent: Color?
    var intensity: Double = 1

    private var second: Color { accent ?? tint.lightened(by: 0.26) }

    var body: some View {
        GeometryReader { proxy in
            let radius = max(proxy.size.width, proxy.size.height)

            ZStack {
                tint.opacity(0.94 * intensity)

                // Le coeur sombre est decale sous le centre : centre, il
                // partage la carte en deux moities egales et la lumiere n'a
                // plus d'origine.
                RadialGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black.opacity(0.92), location: 0.24),
                        .init(color: .black.opacity(0.58), location: 0.46),
                        .init(color: .black.opacity(0.20), location: 0.70),
                        .init(color: .clear, location: 1.0),
                    ],
                    center: UnitPoint(x: 0.50, y: 0.62),
                    startRadius: 0,
                    endRadius: radius * 0.54
                )

                LinearGradient(
                    stops: [
                        .init(color: second.opacity(0.60 * intensity), location: 0),
                        .init(color: second.opacity(0.22 * intensity), location: 0.22),
                        .init(color: .clear, location: 0.52),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.plusLighter)

                RadialGradient(
                    colors: [second.opacity(0.40 * intensity), .clear],
                    center: UnitPoint(x: 0.82, y: 0.14),
                    startRadius: 0,
                    endRadius: radius * 0.50
                )
                .blendMode(.plusLighter)
            }
            .blur(radius: 22)
            // Agrandir avant le clip : le flou attaquerait sinon les bords et
            // laisserait un lisere sombre le long de l'arrondi.
            .scaleEffect(1.3)
        }
    }
}

import SwiftUI

/// Le reperage d'un palier : le symbole `brain` d'Apple, rempli par le bas.
///
/// **Un symbole systeme plutot qu'un trace invente.** `BrainSilhouette` est un
/// contour extrait du maillage 3D : il est fidele, mais il a ete dessine pour
/// etre vu grand, et a vingt-six points il se referme en tache. Le symbole
/// d'Apple est hinte pour les petites tailles, il porte les memes graisses que
/// le reste de l'interface, et c'est deja lui qui designe l'onglet
/// « Aujourd'hui » — le meme signe pour la meme chose.
///
/// Il n'est pas repris tel quel : il sert de masque a un degrade qui monte
/// depuis le bas, de sorte que le palier se lise comme un niveau et non comme
/// une icone allumee ou eteinte.
///
/// **La hauteur vient du glyphe, pas du cadre.** Le glyphe `brain` est plus
/// large que haut ; mesurer le niveau sur un cadre carre laisserait les
/// paliers bas — `murky` est a 0,16 — sous le dessin, et ils n'allumeraient
/// rien du tout. Seule la largeur est donc imposee.
struct BrainMark: View {
    let fill: Double
    var tint: Color = Ink.marker
    /// Le second ton du degrade. C'est lui qui empeche le remplissage de se
    /// lire comme un aplat.
    var far: Color = Ink.focusGlowFar
    var width: CGFloat

    private var symbol: some View {
        Image(systemName: "brain")
            .resizable()
            .scaledToFit()
            .frame(width: width)
    }

    var body: some View {
        symbol
            // Le contour reste visible sous le niveau : sans lui, un palier
            // bas ne serait qu'un fragment flottant, sans forme a completer.
            .foregroundStyle(tint.opacity(0.20))
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [far, tint],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: proxy.size.height * min(1, max(0, fill)))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .mask { symbol }
            }
    }
}

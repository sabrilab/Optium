import SwiftUI

/// Carte d'une grille bento.
///
/// La carte est remplie de couleur bord a bord, avec un coeur sombre au centre
/// et un second foyer decale. Voir `BentoSurface` pour le detail du pourquoi.
struct BentoCard<Content: View>: View {
    var tint: Color = Ink.focusGlow
    var accent: Color?
    var corner: CGFloat = 24
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .bentoSurface(tint: tint, accent: accent, corner: corner)
    }
}

/// Ligne d'etiquette et de valeur, reprise dans toutes les cartes.
struct BentoStat: View {
    let label: String
    let value: String
    var unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 30, weight: .medium))
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

extension View {
    /// Surface d'une carte : maillage colore diffus, puis verre d'Apple.
    ///
    /// L'ordre importe et il est contre-intuitif — chaque fond se dessine
    /// *derriere* le precedent. Le maillage est donc pose avant `glassEffect`,
    /// faute de quoi le verre passerait devant lui.
    func bentoSurface(tint: Color, accent: Color? = nil, corner: CGFloat = 24) -> some View {
        modifier(BentoSurface(tint: tint, accent: accent ?? tint, corner: corner))
    }
}

private struct BentoSurface: ViewModifier {
    let tint: Color
    let accent: Color
    let corner: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    wash(in: proxy.size)
                        .clipShape(.rect(cornerRadius: corner))
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: corner))
    }

    /// La carte est **remplie de couleur bord a bord**, et c'est son centre qui
    /// est sombre.
    ///
    /// C'est l'inverse d'une vignette, et c'est ce qui fait lire un panneau
    /// retro-eclaire plutot qu'un aplat degrade. Un fondu lineaire, ou une
    /// masse de couleur logee dans un coin, donnent tous deux une direction a
    /// l'oeil : la carte se lit alors comme un remplissage. Un coeur sombre
    /// centre n'a pas de direction — la lumiere semble venir de derriere la
    /// surface.
    private func wash(in size: CGSize) -> some View {
        let radius = max(size.width, size.height)

        return ZStack {
            // Le remplissage monte en meme temps que le coeur s'assombrit :
            // c'est l'ecart entre les deux qui fait la lecture, pas leurs
            // valeurs absolues.
            tint.opacity(0.72)

            RadialGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0.96), location: 0.26),
                    .init(color: .black.opacity(0.74), location: 0.48),
                    .init(color: .black.opacity(0.34), location: 0.72),
                    .init(color: .clear, location: 1.0),
                ],
                center: .center,
                startRadius: 0,
                endRadius: radius * 0.68
            )

            // Un second foyer, decale et d'une autre teinte : sans lui les
            // deux moities de la carte sont symetriques et l'ensemble parait
            // fabrique.
            RadialGradient(
                colors: [accent.opacity(0.50), .clear],
                center: UnitPoint(x: 0.80, y: 0.18),
                startRadius: 0,
                endRadius: radius * 0.55
            )
            .blendMode(.plusLighter)
        }
        // Le flou acheve la diffusion et efface les raccords entre les foyers.
        .blur(radius: 22)
        // Agrandir avant le clip : le flou attaquerait sinon les bords et
        // laisserait un lisere sombre le long de l'arrondi.
        .scaleEffect(1.3)
    }
}

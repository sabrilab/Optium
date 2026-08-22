import SwiftUI

/// Carte d'une grille bento.
///
/// La carte est remplie de couleur bord a bord, avec un coeur sombre au centre
/// et un second foyer decale. Voir `BentoSurface` pour le detail du pourquoi.
struct BentoCard<Content: View>: View {
    var hue: Ink.CardHue = Ink.indigo
    var tint: Color { hue.tint }
    var accent: Color? { hue.accent }
    var corner: CGFloat = 28
    /// Hierarchie : une carte secondaire est plus sombre, pas d'une autre
    /// teinte. Varier les couleurs pour hierarchiser produit un arc-en-ciel.
    var intensity: Double = 1
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .bentoSurface(tint: tint, accent: accent, corner: corner, intensity: intensity)
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
    /// Variante prenant une teinte de carte complete.
    func bentoSurface(_ hue: Ink.CardHue, corner: CGFloat = 28, intensity: Double = 1) -> some View {
        bentoSurface(tint: hue.tint, accent: hue.accent, corner: corner, intensity: intensity)
    }

    /// Surface d'une carte : maillage colore diffus, puis verre d'Apple.
    ///
    /// L'ordre importe et il est contre-intuitif — chaque fond se dessine
    /// *derriere* le precedent. Le maillage est donc pose avant `glassEffect`,
    /// faute de quoi le verre passerait devant lui.
    func bentoSurface(
        tint: Color,
        accent: Color? = nil,
        corner: CGFloat = 28,
        intensity: Double = 1
    ) -> some View {
        modifier(BentoSurface(tint: tint, accent: accent ?? tint, corner: corner, intensity: intensity))
    }
}

private struct BentoSurface: ViewModifier {
    let tint: Color
    let accent: Color
    let corner: CGFloat
    let intensity: Double

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
            tint.opacity(0.72 * intensity)

            // Le coeur sombre est decale sous le centre. Centre, il partage la
            // carte en deux moities egales et la lumiere n'a plus d'origine ;
            // pousse vers le bas, il laisse le bord haut s'allumer, et c'est de
            // la que la lumiere parait venir.
            RadialGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0.96), location: 0.26),
                    .init(color: .black.opacity(0.74), location: 0.48),
                    .init(color: .black.opacity(0.34), location: 0.72),
                    .init(color: .clear, location: 1.0),
                ],
                center: UnitPoint(x: 0.50, y: 0.62),
                startRadius: 0,
                endRadius: radius * 0.68
            )

            // Arete superieure rallumee, dans la seconde teinte.
            LinearGradient(
                stops: [
                    .init(color: accent.opacity(0.60 * intensity), location: 0),
                    .init(color: accent.opacity(0.22 * intensity), location: 0.22),
                    .init(color: .clear, location: 0.52),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.plusLighter)

            // Un second foyer, decale : sans lui les deux moities de la carte
            // sont symetriques et l'ensemble parait fabrique.
            RadialGradient(
                colors: [accent.opacity(0.40 * intensity), .clear],
                center: UnitPoint(x: 0.82, y: 0.14),
                startRadius: 0,
                endRadius: radius * 0.50
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

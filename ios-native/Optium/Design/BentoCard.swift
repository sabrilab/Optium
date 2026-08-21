import SwiftUI

/// Carte d'une grille bento.
///
/// Le degrade est **vertical et clipe a la forme** : couleur saturee en haut,
/// fondu vers le noir en bas, sur toute la largeur.
///
/// Deux erreurs ont ete faites avant d'arriver la, et elles valent d'etre
/// notees. Un degrade radial dessine une tache au centre de la carte au lieu
/// de la traverser — il se lit comme un fond pose derriere, pas comme une
/// teinte. Et un `.background` sans forme n'est clipe par rien : la couleur
/// deborde des coins arrondis en aretes droites. D'ou `background(_:in:)`,
/// qui clipe, pose par-dessus le verre dont il laisse voir la refraction dans
/// la partie fondue.
struct BentoCard<Content: View>: View {
    var tint: Color = Ink.focusGlow
    var corner: CGFloat = 24
    /// Ou le degrade a fini de s'effacer, en fraction de la hauteur.
    var fade: Double = 0.85
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .bentoSurface(tint: tint, corner: corner, fade: fade)
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

/// Meme traitement, applique a n'importe quelle vue.
extension View {
    func bentoSurface(tint: Color, corner: CGFloat = 24, fade: Double = 0.85) -> some View {
        // L'ordre compte, et il est contre-intuitif : chaque `.background` se
        // dessine *derriere* le precedent. Le degrade doit donc etre pose
        // avant `glassEffect`, sinon le verre passerait devant lui — et un
        // fond opaque pose en premier le masquerait tout a fait.
        self
            .background {
                LinearGradient(
                    stops: [
                        .init(color: tint.opacity(0.62), location: 0),
                        .init(color: tint.opacity(0.22), location: 0.45),
                        .init(color: .clear, location: fade),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // Sans clip, la couleur deborde des coins arrondis en aretes
                // droites : `.background { }` n'est clipe par aucune forme.
                .clipShape(.rect(cornerRadius: corner))
            }
            .glassEffect(.regular, in: .rect(cornerRadius: corner))
    }
}

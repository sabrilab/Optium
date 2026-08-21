import SwiftUI

/// Carte d'une grille bento.
///
/// Le fond est un vrai Liquid Glass : la teinte n'est qu'un voile pose dessous,
/// pour que chaque carte ait son identite sans perdre la refraction, la
/// reactivite au contenu ni les animations d'Apple.
struct BentoCard<Content: View>: View {
    var tint: Color = Ink.focusGlow
    var corner: CGFloat = 24
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background {
                RadialGradient(
                    colors: [tint.opacity(0.42), tint.opacity(0.06)],
                    center: .topLeading,
                    startRadius: 4,
                    endRadius: 220
                )
            }
            .glassEffect(.regular, in: .rect(cornerRadius: corner))
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

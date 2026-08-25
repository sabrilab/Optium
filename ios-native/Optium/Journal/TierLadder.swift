import SwiftUI

/// L'échelle des paliers : cinq barreaux, trois bandes.
///
/// **Le lexique n'a aucun ordre intuitif.** *Cristallin, Limpide, Net, Voilé,
/// Trouble* : sans le tableau sous les yeux, personne ne sait si *Net* est
/// au-dessus ou en dessous de *Limpide*. C'est un vocabulaire, pas une
/// échelle — et le montrer coûte cinq barreaux.
///
/// **Les bandes ne portent pas de nom, et ne doivent pas en porter.** C'est
/// tout leur intérêt : elles donnent l'ordre par la position. Les nommer
/// « basse / moyenne / haute » créerait une seconde échelle à trois crans à
/// côté de celle de la clarté, qui ne mesure pas la même chose.
///
/// **C'est le seul écart qui fait lire les trois groupes** — pas un trait, pas
/// une étiquette : l'espace entre deux bandes est simplement plus large que
/// l'espace entre deux barreaux d'une même bande.
///
/// **Aucune teinte n'est plus « bonne » qu'une autre.** Pas de vert en haut,
/// pas de rouge en bas : ce serait noter, et l'indice ne note pas.
struct TierLadder: View {
    let current: Tier?
    /// Vrai quand l'échelle sert de légende sous un emblème déjà présent.
    var showsMark = true

    private var descending: [Tier] { Tier.allCases.sorted().reversed() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(descending.enumerated()), id: \.element) { index, tier in
                rung(tier)
                if index < descending.count - 1 {
                    // L'écart entre bandes est plus large que l'écart entre
                    // barreaux : c'est lui, et lui seul, qui fait lire les
                    // trois groupes.
                    Color.clear.frame(height: tier.band != descending[index + 1].band ? 11 : 4)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(current.map { "Ton palier : \($0.word)" } ?? "Palier pas encore attribuable")
    }

    private func rung(_ tier: Tier) -> some View {
        let occupied = tier == current

        return HStack(spacing: 10) {
            if showsMark {
                BrainMark(fill: tier.fill, tint: occupied ? Ink.marker : .white)
                    .frame(width: 18, height: 18)
                    .opacity(occupied ? 1 : 0.28)
            }

            // Le barreau : plein et teinté quand il est occupé, creux sinon —
            // comme les graduations non franchies de `TickScale`.
            Capsule()
                .fill(occupied ? Ink.marker : Color.white.opacity(0.16))
                .frame(width: barWidth(tier), height: occupied ? 5 : 3)
                .shadow(color: occupied ? Ink.marker.opacity(0.5) : .clear, radius: 5)

            Text(tier.word)
                .font(.system(size: 11, weight: occupied ? .semibold : .regular))
                .foregroundStyle(occupied ? Ink.marker : Color.white.opacity(0.42))

            Spacer(minLength: 0)
        }
        .frame(minHeight: 20)
    }

    /// La largeur suit le palier : l'échelle se lit comme une échelle même
    /// sans les mots.
    private func barWidth(_ tier: Tier) -> CGFloat {
        let rank = Tier.allCases.sorted().firstIndex(of: tier) ?? 0
        return 26 + CGFloat(rank) * 13
    }
}

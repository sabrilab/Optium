import SwiftUI

/// Ce que l'outil vient de consulter, montre pendant qu'on en parle.
///
/// **Une carte, jamais une liste.** Ce qui apparait remplace ce qui precedait.
/// Empiler les consultations reconstituerait le fil de messages que l'appel
/// s'interdit, sous une autre forme.
struct ExhibitCard: View {
    let exhibit: CallExhibit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(heading)
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .bentoSurface(hue, corner: 28, intensity: 0.55)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(y: 12)),
            removal: .opacity
        ))
    }

    private var heading: String {
        switch exhibit {
        case .clarity: "CE QUE JE MESURE"
        case .thread: "CE QUE J’AI FERMÉ"
        case .openThreads: "CE QUE JE PORTE"
        case .tier: "MON PALIER"
        }
    }

    /// Une teinte par nature de fait : on reconnait de quoi on parle avant
    /// d'avoir lu.
    private var hue: Ink.CardHue {
        switch exhibit {
        case .clarity: Ink.indigo
        case .thread: Ink.violet
        case .openThreads: Ink.teal
        case .tier: Ink.rose
        }
    }

    @ViewBuilder
    private var content: some View {
        switch exhibit {
        case let .clarity(word, nights, window):
            VStack(alignment: .leading, spacing: 8) {
                Text(word ?? "pas encore mesurable")
                    .font(.system(size: 30, weight: .light))
                Text("\(nights) nuits observées · fenêtre \(Clock.hhmm(window.start)) → \(Clock.hhmm(window.end))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        case let .thread(phrase, resumptions, nights, held):
            VStack(alignment: .leading, spacing: 10) {
                Text(phrase)
                    .font(.system(size: 20, weight: .light))
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 18) {
                    tally("\(resumptions)", "reprises")
                    tally("\(nights)", "nuits")
                    tally("\(held)", "retenues")
                }
            }

        case let .openThreads(phrases):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(phrases.prefix(4), id: \.self) { phrase in
                    Text("• \(phrase)")
                        .font(.system(size: 16, weight: .light))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if phrases.count > 4 {
                    Text("et \(phrases.count - 4) de plus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        case let .tier(tier, share, days):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    BrainMark(fill: tier.fill, tint: Ink.marker)
                        .frame(width: 34, height: 34)
                    Text(tier.word)
                        .font(.system(size: 26, weight: .light))
                }
                Text(share)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let days {
                    Text("Depuis \(days) jours.")
                        .font(.footnote)
                        .foregroundStyle(Ink.marker)
                }
            }
        }
    }

    private func tally(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .medium))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

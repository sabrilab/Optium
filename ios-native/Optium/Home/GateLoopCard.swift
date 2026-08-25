import SwiftUI

/// La boucle refermée, montrée au moment où elle se referme.
///
/// **Le moment juste est la fermeture d'une décision passée par la porte** :
/// ce que tu avais écrit, quand tu l'as retenue, et dans quel état tu l'as
/// finalement tranchée.
///
/// **Elle ne se félicite de rien.** Elle repose les faits côte à côte et
/// s'arrête là. « Bravo, tu as bien fait d'attendre » transformerait une
/// constatation en récompense, et une récompense se met à être recherchée pour
/// elle-même — c'est exactement ce que le garde-fou contre l'orthosomnie
/// interdit ailleurs dans le produit.
///
/// Elle n'apparaît **que** si la boucle a réellement eu lieu : retenue en
/// clarté basse, tranchée plus haut. Voir `GateLoop.isMeaningful`.
struct GateLoopCard: View {
    let loop: GateLoop

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CE QUE LA PORTE A CHANGÉ")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary)

            // La ligne écrite à la porte, telle quelle. C'est elle le sujet :
            // on la relit dans un autre état que celui où on l'a écrite.
            Text("« \(loop.acceptance) »")
                .font(.system(size: 17, weight: .light))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                moment("retenue", loop.clarityWhenHeld)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 14)
                moment("tranchée", loop.clarityWhenClosed)
                Spacer(minLength: 0)
            }

            Text(sentence)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .bentoSurface(Ink.violet, corner: 30, intensity: 0.5)
    }

    private func moment(_ label: String, _ level: ClarityLevel) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(level.word)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(level == .low ? Color.white.opacity(0.55) : Ink.marker)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Un constat, jamais un compliment.
    private var sentence: String {
        let days = Int((loop.span / 86_400).rounded())
        let held = loop.holdCount == 1 ? "une fois" : "\(loop.holdCount) fois"
        if days <= 0 {
            return "Retenue \(held), tranchée le jour même dans un autre état."
        }
        return "Retenue \(held), tranchée \(days) jour\(days > 1 ? "s" : "") plus tard dans un autre état."
    }
}

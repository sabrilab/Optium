import SwiftUI

/// La trace des reprises : une marque par reprise, de gauche à droite.
///
/// **« 3 reprises » ne dit rien.** Trois reprises en un après-midi et trois
/// reprises étalées sur quatre nuits sont deux histoires opposées, et le
/// nombre les confond.
///
/// **C'est ici, et seulement ici, que `Resumption.clarityAtStart` reprend
/// vie.** Le champ était écrit à chaque reprise depuis le début et n'alimentait
/// aucune surface : ni le journal, ni les preuves, ni les outils de l'appel.
/// Une donnée enregistrée et jamais relue est une promesse en l'air.
///
/// Trois choses se lisent d'un coup d'œil, sans une phrase :
///
/// - la **hauteur** de chaque marque encode la clarté au démarrage — haute et
///   pleine, moyenne, ou courte et creuse ;
/// - un **écart plus large** là où une nuit a été traversée ;
/// - la reprise en cours, s'il y en a une, est la seule en `Ink.marker`.
///
/// **La trace ne juge pas, elle décrit** — et c'est précisément pour ça
/// qu'elle est lisible sans légende. Une ligne de marques courtes et creuses
/// se comprend seule. **Ne rien écrire à côté**, surtout pas « tu travailles
/// souvent en clarté basse ».
struct ResumptionTrace: View {
    let resumptions: [Resumption]
    var calendar: Calendar = .current

    private var ordered: [Resumption] {
        resumptions.sorted { $0.startedAt < $1.startedAt }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(ordered.enumerated()), id: \.element.id) { index, resumption in
                if index > 0 {
                    Color.clear.frame(width: gap(before: index), height: 1)
                }
                mark(resumption)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    // ── Une marque ──

    private func mark(_ resumption: Resumption) -> some View {
        let running = resumption.endedAt == nil
        let height: CGFloat = switch resumption.clarityAtStart {
        case .high: 14
        case .medium: 9
        case .low: 5
        }

        return Capsule()
            .fill(running ? Ink.marker : Color.white.opacity(fill(resumption.clarityAtStart)))
            .frame(width: 3, height: height)
    }

    /// Creuse en clarté basse, pleine en haute. **L'opacité, jamais une autre
    /// teinte** : `Ink.marker` ne désigne que le présent.
    private func fill(_ level: ClarityLevel) -> Double {
        switch level {
        case .high: 0.85
        case .medium: 0.55
        case .low: 0.28
        }
    }

    /// L'écart avant une marque : large si une nuit sépare les deux reprises.
    ///
    /// C'est ce qui distingue trois reprises d'un même après-midi de trois
    /// reprises étalées sur trois jours.
    private func gap(before index: Int) -> CGFloat {
        let previous = ordered[index - 1]
        let current = ordered[index]
        let crossed = !calendar.isDate(previous.startedAt, inSameDayAs: current.startedAt)
        return crossed ? 11 : 4
    }

    private var spoken: String {
        let count = ordered.count
        guard count > 0 else { return "Aucune reprise" }
        let days = Set(ordered.map { calendar.startOfDay(for: $0.startedAt) }).count
        let low = ordered.count { $0.clarityAtStart == .low }
        var phrase = "\(count) reprise\(count > 1 ? "s" : "") sur \(days) jour\(days > 1 ? "s" : "")"
        if low > 0 { phrase += ", dont \(low) en clarté basse" }
        return phrase
    }
}

import SwiftData
import SwiftUI

/// Le détail de la journée : ce sur quoi la règle se fonde.
///
/// **La règle est devenue l'élément le plus utile de l'application au
/// quotidien** — c'est par elle qu'on décide de sa journée, y compris et
/// surtout quand la clarté est basse. Elle n'avait aucun geste. Cet écran est
/// son recours, sur le modèle de celui des nuits.
///
/// Il montre trois choses, et rien d'autre : les deux forces séparées, ce qui
/// décide de la largeur de la fenêtre aujourd'hui, et de quoi chaque partie de
/// la journée est capable.
///
/// **Le troisième point est de l'orientation, pas du conseil, et la nuance est
/// absolue** : on décrit ce dont un moment est CAPABLE, jamais quoi y faire.
/// Aucun impératif, et aucune heure de pic nommée — le modèle à deux processus
/// est solide, la prédiction d'un pic personnel à l'heure près ne l'est pas.
struct DayScreen: View {
    let reading: ClarityReading

    @Query(sort: \Calibration.askedAt, order: .reverse) private var calibrations: [Calibration]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                forces
                windowCard
                capabilities
                accuracy
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .background(InkBackground())
        .navigationTitle("Ta journée")
        .navigationBarTitleDisplayMode(.inline)
    }

    // ── 1. Les deux forces, séparées ──

    private var forces: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("LES DEUX FORCES")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary)

            // **Le seul endroit où on a le droit de les distinguer.** Sur
            // l'accueil, ce serait deux idées dans un objet — la règle dit le
            // quand, le cerveau dit le combien.
            TwoForcesChart(points: reading.curve, hoursAwake: reading.hoursAwake)

            Text("La ligne haute est ce que ta nuit permet ; elle descend à mesure que la journée avance. Les graduations dessous sont ce que l’heure en laisse passer. L’écart entre les deux est ce qui te reste.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .bentoSurface(Ink.indigo, corner: 28, intensity: 0.5)
    }

    // ── 2. Pourquoi la fenêtre fait cette largeur ──

    private var windowCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TA FENÊTRE AUJOURD’HUI")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary)

            Text(widthSentence)
                .font(.system(size: 17, weight: .light))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Les manques sont déjà calculés : on les nomme, on ne les note
            // pas.
            ForEach(reading.citedShortfalls, id: \.component) { shortfall in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Ink.marker.opacity(0.5))
                        .frame(width: 4, height: 4)
                    Text(name(shortfall.component))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .bentoSurface(Ink.teal, corner: 28, intensity: 0.45)
    }

    private var widthSentence: String {
        let hours = reading.window.duration / 3600
        let text = hours < 1
            ? "\(Int((hours * 60).rounded())) minutes"
            : String(format: "%.1f heures", hours).replacingOccurrences(of: ".", with: " h ")
        return "Elle dure \(text). Ce qui la resserre :"
    }

    private func name(_ component: ClarityComponent) -> String {
        switch component {
        case .regularity: "l’écart entre tes heures de lever"
        case .duration: "la durée de ta dernière nuit"
        case .circadian: "l’heure qu’il est"
        }
    }

    // ── 3. De quoi chaque partie de la journée est capable ──

    private var capabilities: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 0) {
                Text("CE DONT CHAQUE MOMENT EST CAPABLE")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                // **C'est ici que la modale vaut le plus** : elle dit que
                // cette partie du calcul repose sur un effet contesté.
                EvidenceButton(evidence: EvidenceLibrary.circadian)
            }
            .frame(height: 22)

            // **Aucun impératif, aucune heure nommée.** On décrit ce qu'un
            // moment permet ; ce qu'on en fait n'appartient pas à
            // l'application.
            moment("Près du sommet", "Une décision tient. C’est le moment où attraper ses propres erreurs coûte le moins.")
            moment("Dans le creux", "L’exécution de ce qu’on sait déjà faire passe. La relecture de son propre travail, moins.")
            moment("Au rebond du soir", "Une seconde plage utilisable, plus courte que celle du matin.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .bentoSurface(Ink.violet, corner: 28, intensity: 0.45)
    }

    private func moment(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(body)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ── 4. La justesse de l'application elle-même ──

    @ViewBuilder
    private var accuracy: some View {
        if let verdict = OwnAccuracy.verdict(from: calibrations.map {
            CalibrationRecord(askedAt: $0.askedAt, feltClear: $0.feltClear, measured: $0.measured)
        }) {
            VStack(alignment: .leading, spacing: 12) {
                Text("EST-CE QUE JE TOMBE JUSTE")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)

                Text(verdict.sentence)
                    .font(.system(size: 17, weight: .light))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // **Ce n'est pas un score à améliorer.** C'est le bulletin de
                // l'application, et il n'y a rien que l'utilisateur puisse
                // faire pour le faire monter.
                Text("C’est mon bulletin, pas le tien. Il n’y a rien à y améliorer de ton côté — et s’il est mauvais, il s’affiche quand même.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .bentoSurface(Ink.amber, corner: 28, intensity: 0.4)
        }
    }
}

/// Le plafond et la clarté, côte à côte.
///
/// C'est le seul dessin de l'application qui montre les deux processus
/// séparément — ailleurs, ils sont fondus dans un seul niveau.
struct TwoForcesChart: View {
    let points: [ClarityReading.CurvePoint]
    let hoursAwake: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack(alignment: .topLeading) {
                Path { path in
                    for (index, point) in points.enumerated() {
                        let position = CGPoint(x: x(point.hoursAwake, width),
                                               y: y(point.ceiling, height))
                        if index == 0 { path.move(to: position) } else { path.addLine(to: position) }
                    }
                }
                .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                ForEach(Array(stride(from: 0, to: points.count, by: max(1, points.count / 42))), id: \.self) { index in
                    let point = points[index]
                    let top = y(point.clarity, height)
                    Capsule()
                        .fill(Ink.marker.opacity(point.hoursAwake < hoursAwake ? 0.3 : 0.8))
                        .frame(width: 2, height: max(2, height - top))
                        .offset(x: x(point.hoursAwake, width) - 1, y: top)
                }

                Rectangle()
                    .fill(Ink.marker)
                    .frame(width: 1.5, height: height)
                    .offset(x: x(hoursAwake, width) - 0.75)
            }
        }
        .frame(height: 110)
    }

    private func x(_ hour: Double, _ width: CGFloat) -> CGFloat {
        let hours = points.map(\.hoursAwake)
        let low = hours.min() ?? 0, high = hours.max() ?? 20
        guard high > low else { return 0 }
        return width * CGFloat((hour - low) / (high - low))
    }

    private func y(_ value: Double, _ height: CGFloat) -> CGFloat {
        height * CGFloat(1 - min(1, max(0, value / 100)))
    }
}

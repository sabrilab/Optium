import SwiftUI

/// Les cinq paliers, parcourables.
///
/// **Expliquer, jamais faire monter.** La frontiere est mince et elle est
/// tenue ici : chaque palier dit ce que l'indice mesure a ce niveau-la, et
/// aucun ne dit comment passer au suivant. Une progression expliquee devient
/// une progression a obtenir, et le sommeil devient un score — c'est le
/// mecanisme meme de l'orthosomnie, contre lequel le produit se garde.
///
/// D'ou trois absences deliberees : pas de fleche vers le haut, pas de
/// « prochain palier », pas de distance a parcourir. Les cinq sont poses cote
/// a cote comme des descriptions, et celui de l'utilisateur est simplement
/// signale.
struct TierScreen: View {
    let current: Tier?

    @State private var shown: Tier = .clear
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                brain
                picker
                detail
                scale
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .background(InkBackground())
        .navigationTitle("Les paliers")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { shown = current ?? .clear }
    }

    // ── Le cerveau du palier montre ──

    @ViewBuilder
    private var brain: some View {
        if settings.brainEnabled {
            BrainView(
                fill: shown.fill,
                isDay: true,
                isVisible: scenePhase == .active
            )
            .frame(height: 210)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
            // Le remplissage s'anime entre deux paliers : c'est la seule chose
            // qui relie visuellement les cinq, et elle se lit comme une
            // quantite, pas comme une marche a gravir.
            .animation(Motion.entrance, value: shown)
        }
    }

    // ── Le choix ──

    private var picker: some View {
        HStack(spacing: 8) {
            ForEach(Tier.allCases.sorted(), id: \.self) { tier in
                Button {
                    guard tier != shown else { return }
                    Feedback.play(.answered)
                    shown = tier
                } label: {
                    VStack(spacing: 6) {
                        BrainMark(
                            fill: tier.fill,
                            tint: tier == shown ? Ink.marker : .white
                        )
                        .frame(width: 26, height: 26)
                        .opacity(tier == shown ? 1 : 0.4)

                        Text(tier.word)
                            .font(.system(size: 10, weight: tier == shown ? .semibold : .regular))
                            .foregroundStyle(tier == shown ? Ink.marker : Color.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // ── Ce que le palier decrit ──

    private var detail: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(shown.word)
                    .font(.system(size: 30, weight: .light))
                if shown == current {
                    Text("LE TIEN")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.4)
                        .foregroundStyle(Ink.marker)
                }
            }

            Text(shown.explanation)
                .font(.system(size: 17, weight: .light))
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider().overlay(Color.white.opacity(0.12))

            // La definition litterale de l'indice, bien plus parlante que le
            // score : « la probabilite d'etre dans le meme etat a la meme
            // heure d'un jour sur l'autre ».
            row("Même état d’un jour sur l’autre", "≈ \(shown.agreementShare) fois sur 100")
            row("Part de la population", "\(shown.populationShare) %")

            Text("La régularité prédit mieux la mortalité que la durée de sommeil — c’est ce qui lui vaut le poids le plus élevé dans le calcul. Windred et coll., *Sleep*, 2023, sur 60 977 participants.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .bentoSurface(hue(for: shown), corner: 28, intensity: 0.5)
        .animation(Motion.state, value: shown)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.footnote)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    /// Une teinte par palier, dans l'ordre de la palette. **Aucune n'est plus
    /// « bonne » qu'une autre** : pas de vert en haut, pas de rouge en bas —
    /// ce serait noter, et l'indice ne note pas.
    private func hue(for tier: Tier) -> Ink.CardHue {
        let index = Tier.allCases.sorted().firstIndex(of: tier) ?? 0
        return Ink.cardHues[index % Ink.cardHues.count]
    }

    // ── L'echelle complete, pour situer ──

    private var scale: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                Text("L’INDICE DE RÉGULARITÉ")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                EvidenceButton(evidence: EvidenceLibrary.regularity)
            }
            .frame(height: 22)

            ForEach(Tier.allCases.sorted().reversed(), id: \.self) { tier in
                HStack(spacing: 12) {
                    Text(tier.word)
                        .font(.footnote.weight(tier == shown ? .semibold : .regular))
                        .foregroundStyle(tier == shown ? Ink.marker : .secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(bounds(tier))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(minHeight: 26)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .bentoSurface(Ink.indigo, corner: 28, intensity: 0.3)
    }

    private func bounds(_ tier: Tier) -> String {
        let range = tier.range
        if range.upperBound >= 100 { return "\(Int(range.lowerBound)) et au-delà" }
        return "\(Int(range.lowerBound)) à \(Int(range.upperBound))"
    }
}

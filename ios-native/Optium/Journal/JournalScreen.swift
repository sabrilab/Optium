import SwiftData
import SwiftUI

/// Le retrospectif : où tu te situes, ce que tu as débloqué, ce que tu as fermé.
///
/// **Ce n'est pas un tableau de bord.** Il ne pousse à rien, ne notifie rien,
/// ne compte aucune série à ne pas briser. Le document est explicite sur la
/// raison : les applications de productivité meurent dans leur onglet
/// Statistiques.
struct JournalScreen: View {
    @Environment(ClarityStore.self) private var clarityStore
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase

    @Query(filter: #Predicate<WorkThread> { $0.closedAt != nil },
           sort: \WorkThread.closedAt, order: .reverse)
    private var closed: [WorkThread]

    @Query private var nights: [RecordedNight]
    @Query private var coffees: [CoffeeIntake]
    @Query private var resumptions: [Resumption]

    private var facts: ProofFacts {
        ProofFactsBuilder.facts(
            closed: closed,
            nights: nights.map(\.night),
            coffees: coffees.map(\.takenAt),
            resumptions: resumptions
        )
    }

    private var tier: Tier? {
        guard let regularity = clarityStore.reading.regularity else { return nil }
        return Tier(regularity: regularity)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    tierCard
                    proofGrid
                    if !closed.isEmpty { closedSection }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            .background(InkBackground())
            .navigationTitle("Où tu en es")
        }
    }

    // ── Le palier ──

    @ViewBuilder
    private var tierCard: some View {
        if let tier {
            VStack(alignment: .leading, spacing: 16) {
                Text("TON PALIER")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)

                HStack(alignment: .center, spacing: 18) {
                    // L'emblème est le cerveau lui-même, à un remplissage
                    // croissant. Pas de médaille : le même objet, plus plein.
                    if settings.brainEnabled {
                        BrainView(
                            fill: tier.fill,
                            base: 1,
                            agitation: 0,
                            isDay: true,
                            isVisible: scenePhase == .active
                        )
                        .frame(width: 96, height: 96)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(tier.word)
                            .font(.system(size: 30, weight: .light))
                        Text(situation(tier))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                scale(tier)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .bentoSurface(Ink.indigo, corner: 34)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("TON PALIER")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)
                Text("Pas encore attribuable")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Il se calcule sur une médiane de vingt-huit nuits. On ne peut pas y monter par gavage — ni le connaître avant.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .bentoSurface(Ink.indigo, corner: 34, intensity: 0.4)
        }
    }

    /// L'échelle, rendue visible.
    ///
    /// Cristallin, Limpide, Net, Voilé, Trouble n'ont aucun ordre intuitif :
    /// sans le tableau sous les yeux, personne ne sait si *Net* est au-dessus
    /// ou en dessous de *Limpide*. C'est un lexique, pas une échelle.
    ///
    /// La montrer coûte cinq silhouettes et supprime le problème sans toucher
    /// au vocabulaire.
    private func scale(_ current: Tier) -> some View {
        HStack(spacing: 10) {
            ForEach(Tier.allCases.sorted(), id: \.self) { tier in
                VStack(spacing: 5) {
                    BrainSilhouetteView(
                        fill: tier.fill,
                        tint: tier == current ? Ink.marker : .white,
                        showsBase: false
                    )
                    .frame(width: 26, height: 26)
                    .opacity(tier == current ? 1 : 0.34)
                    Text(tier.word)
                        .font(.system(size: 9, weight: tier == current ? .semibold : .regular))
                        .foregroundStyle(tier == current ? Ink.marker : Color.white.opacity(0.42))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 6)
    }

    /// Où l'on se situe — en distribution, jamais par rapport à des personnes.
    ///
    /// Trois règles absolues du document : jamais de noms ni de profils,
    /// jamais le volume, et seulement les mesures réellement comparables.
    private func situation(_ tier: Tier) -> String {
        let above = Tier.allCases
            .filter { $0 > tier }
            .reduce(0) { $0 + $1.populationShare }
        if above == 0 { return "Le palier le plus régulier. \(tier.populationShare) % des gens y sont." }
        return "\(above) % des gens dorment plus régulièrement. \(tier.populationShare) % sont à ton palier."
    }

    // ── Les preuves ──

    private var proofGrid: some View {
        let facts = facts
        return VStack(alignment: .leading, spacing: 12) {
            Text("LES PREUVES")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
                .padding(.top, 8)

            ForEach(Array(Proof.all.enumerated()), id: \.element.id) { index, proof in
                let earned = proof.isEarned(by: facts)
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: earned ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17))
                        .foregroundStyle(earned ? Ink.marker : Color.white.opacity(0.22))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(proof.word)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(earned ? .primary : .secondary)
                        Text(proof.requirement)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .bentoSurface(
                    Ink.cardHues[index % Ink.cardHues.count],
                    corner: 26,
                    intensity: earned ? 0.5 : 0.16
                )
            }
        }
    }

    // ── Les fils fermés ──

    private var closedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FILS FERMÉS")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
                .padding(.top, 8)

            ForEach(Array(closed.enumerated()), id: \.element.id) { index, thread in
                row(thread, hue: Ink.cardHues[index % Ink.cardHues.count])
            }
        }
    }

    private func row(_ thread: WorkThread, hue: Ink.CardHue) -> some View {
        let summary = thread.summary()
        return VStack(alignment: .leading, spacing: 12) {
            Text(thread.nature.word.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            Text(thread.phrase)
                .font(.system(size: 20, weight: .light))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 18) {
                mark("\(summary.resumptionCount)", "reprises")
                mark("\(summary.inWindowCount)", "dans la fenêtre")
                if summary.nightsCrossed > 0 {
                    mark("\(summary.nightsCrossed)", summary.nightsCrossed == 1 ? "nuit" : "nuits")
                }
                if summary.holdCount > 0 {
                    mark("\(summary.holdCount)", summary.holdCount == 1 ? "retenue" : "retenues")
                }
            }
        }
        .padding(18)
        .bentoSurface(hue, corner: 28, intensity: 0.4)
    }

    private func mark(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .medium))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

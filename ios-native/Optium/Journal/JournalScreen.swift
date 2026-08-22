import SwiftData
import SwiftUI

/// Le retrospectif : où tu te situes, ce que tu as débloqué, ce que tu as fermé.
///
/// **Ce n'est pas un tableau de bord.** Il ne pousse à rien, ne notifie rien,
/// ne compte aucune série à ne pas briser. Le document est explicite sur la
/// raison : les applications de productivité meurent dans leur onglet
/// Statistiques.
struct JournalScreen: View {
    /// L'onglet est-il au premier plan. Le cerveau en volume de la carte de
    /// palier n'est rendu que dans ce cas.
    var isVisible: Bool = true

    @Environment(ClarityStore.self) private var clarityStore
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase

    @Query(filter: #Predicate<WorkThread> { $0.closedAt != nil },
           sort: \WorkThread.closedAt, order: .reverse)
    private var closed: [WorkThread]

    @Query private var nights: [RecordedNight]
    @Query private var coffees: [CoffeeIntake]
    @Query private var resumptions: [Resumption]
    @Query(sort: \Calibration.askedAt, order: .reverse) private var calibrations: [Calibration]

    private var facts: ProofFacts {
        ProofFactsBuilder.facts(
            closed: closed,
            nights: nights.map(\.night),
            coffees: coffees.map(\.takenAt),
            resumptions: resumptions
        )
    }

    @State private var showsCorpus = false

    private var tenure: Int? {
        TierHistory.daysAtCurrentTier(nights: nights.map(\.night), now: Date())
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
                    corpusLink
                    calibrationCard
                    proofGrid
                    if !closed.isEmpty { closedSection }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .background(InkBackground())
            // Le palier ne bouge qu'apres des semaines : c'est ce qui autorise
            // a le souligner. La premiere valeur ne compte pas — arriver sur
            // l'ecran n'est pas franchir un palier.
            .onChange(of: tier) { previous, current in
                guard previous != nil, current != nil, previous != current else { return }
                Feedback.play(.tierChanged)
            }
            .navigationTitle("Où tu en es")
            .navigationDestination(isPresented: $showsCorpus) { CorpusScreen() }
        }
    }

    // ── Le palier ──

    @ViewBuilder
    private var tierCard: some View {
        if let tier {
            // **La carte ouvre les cinq paliers.** Le mot seul — « Cristallin »
            // — n'apprend rien de ce qu'il mesure, et l'echelle en dessous ne
            // fait que situer. Ce qui manquait, c'est ce que chaque etat
            // decrit.
            NavigationLink { TierScreen(current: tier) } label: { tierBody(tier) }
                .buttonStyle(Pressable())
        } else {
            emptyTierCard
        }
    }

    private func tierBody(_ tier: Tier) -> some View {
        Group {
            VStack(alignment: .leading, spacing: 16) {
                Text("TON PALIER")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)

                HStack(alignment: .center, spacing: 18) {
                    // L'emblème est le cerveau lui-même, à un remplissage
                    // croissant. Pas de médaille : le même objet, plus plein.
                    //
                    // En silhouette et non en Metal : c'est un emblème fixe de
                    // **Le seul cerveau en volume hors de l'ecran Session.**
                    //
                    // Il a d'abord ete une silhouette, au motif qu'un moteur
                    // 3D pour un embleme etait un gaspillage. C'etait passer a
                    // cote de ce que la carte annonce : le palier est la seule
                    // chose de l'application qui se gagne sur des semaines, et
                    // la seule qui merite d'etre montree en matiere plutot
                    // qu'en signe. L'echelle juste en dessous reste en
                    // symboles, et le contraste fait la hierarchie.
                    //
                    // Le rendu est suspendu des que l'onglet n'est plus
                    // visible : sans cela la boucle tournerait a soixante
                    // images par seconde derriere l'autre ecran.
                    BrainView(
                        fill: tier.fill,
                        isDay: true,
                        isVisible: isVisible && scenePhase == .active
                    )
                    .frame(width: 128, height: 128)
                    .allowsHitTesting(false)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(tier.word)
                            .font(.system(size: 30, weight: .light))
                        Text(tier.situation)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            // Le lien contraint la hauteur de son libelle : sans
                            // ca, la phrase se tronque au premier retour a la
                            // ligne.
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                        if let days = tenure {
                            // Retrospectif, jamais predictif : annoncer « tu
                            // passes Net dans six jours » serait un compte a
                            // rebours vers un score de sommeil, c'est-a-dire
                            // le levier meme de l'orthosomnie.
                            Text(days == 0 ? "Depuis aujourd’hui." : "Depuis \(days) jour\(days > 1 ? "s" : "").")
                                .font(.caption)
                                .foregroundStyle(Ink.marker)
                        }
                    }
                    Spacer(minLength: 0)
                }

                scale(tier)

                // Le chevron dit que la carte mene quelque part : sans lui,
                // rien ne distingue une carte qui informe d'une carte qui
                // ouvre.
                HStack(spacing: 6) {
                    Text("Ce que chaque palier décrit")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .bentoSurface(Ink.indigo, corner: 34)
        }
    }

    private var emptyTierCard: some View {
        Group {
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
                    BrainMark(
                        fill: tier.fill,
                        tint: tier == current ? Ink.marker : .white
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

    /// L'accès au corpus. Une entrée, pas une carte : ce n'est pas une
    /// statistique de plus, c'est un objet qu'on va lire.
    private var corpusLink: some View {
        NavigationLink {
            CorpusScreen()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ce que tu as décidé")
                        .font(.system(size: 19, weight: .light))
                        .foregroundStyle(.primary)
                    Text(corpusCount == 0
                         ? "Rien encore"
                         : "\(corpusCount) décision\(corpusCount > 1 ? "s" : "") écrite\(corpusCount > 1 ? "s" : "")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .bentoSurface(Ink.rose, corner: 28, intensity: 0.45)
        }
        .buttonStyle(.plain)
    }

    private var corpusCount: Int {
        closed.filter { $0.acceptance != nil || $0.restitution != nil }.count
    }

    // ── Ce que la calibration a appris ──

    /// L'écart entre le ressenti et la mesure, accumulé.
    ///
    /// C'est l'élément le plus métacognitif du produit. Les deux sens sont
    /// comptés côte à côte sans qu'aucun soit désigné comme le plus trompeur :
    /// voir `CalibrationSummary` pour ce que la littérature soutient, et ce
    /// qu'elle contredit.
    @ViewBuilder
    private var calibrationCard: some View {
        if let insight = CalibrationInsight.summary(of: calibrations.map {
            CalibrationRecord(askedAt: $0.askedAt, feltClear: $0.feltClear, measured: $0.measured)
        }) {
            VStack(alignment: .leading, spacing: 14) {
                Text("CE QUE TU APPRENDS")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)

                Text(insight.sentence)
                    .font(.system(size: 17, weight: .light))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 18) {
                    tally("\(insight.overestimates)", "clair, mesuré bas")
                    tally("\(insight.underestimates)", "émoussé, mesuré haut")
                    tally("\(insight.agreements)", "d’accord")
                }

                // La seule affirmation que la litterature soutient, dite une
                // fois, et jamais accrochee a l'un des deux sens.
                Text("On ne devient pas aveugle à sa fatigue. On devient moins capable d’attraper ses propres erreurs.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .bentoSurface(Ink.teal, corner: 30, intensity: 0.45)
        }
    }

    private func tally(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .medium))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

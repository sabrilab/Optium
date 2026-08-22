import SwiftData
import SwiftUI

/// Les nuits sur lesquelles l'application se fonde.
///
/// **Elle affirmait sans montrer.** La clarte, le palier et le refus de la
/// porte reposent tous sur des nuits que rien ne permettait de consulter. Pour
/// qui n'enregistre pas son sommeil dans Sante, ces nuits sont deduites de
/// l'immobilite du telephone — donc invisibles y compris hors de
/// l'application. Annoncer « clarte basse » a partir de la, sans recours,
/// n'est pas une mesure : c'est un verdict.
///
/// Cet ecran est le recours. Il ne persuade de rien et ne conseille rien : il
/// pose ce que l'application croit savoir, nuit par nuit, avec sa provenance.
///
/// **Il ne se corrige pas ici, et c'est deliberé.** Laisser modifier une nuit
/// ferait de l'historique une declaration, et toute la promesse d'Optium tient
/// a ce qu'il mesure au lieu de demander. Ce qui est faux se corrige dans
/// Sante, a la source.
struct NightsScreen: View {
    @Environment(ClarityStore.self) private var clarityStore
    /// La nuit qu'on corrige. L'ecran ne s'ouvre jamais tout seul.
    @State private var correcting: RecordedNight?
    @Environment(\.modelContext) private var context

    @Query(sort: \RecordedNight.asleepAt, order: .reverse)
    private var nights: [RecordedNight]

    @Query(sort: \CoffeeIntake.takenAt) private var coffees: [CoffeeIntake]

    /// Les modules avant la liste : on veut voir la forme de ses nuits avant
    /// de les lire une par une. La liste reste dessous, comme piece a
    /// conviction.
    private var chronological: [Night] {
        nights.map(\.night).sorted { $0.asleepAt < $1.asleepAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                if chronological.count >= 3 { modules }

                if !nights.isEmpty {
                    Text("CHAQUE NUIT")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.6)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }

                ForEach(Array(nights.prefix(60).enumerated()), id: \.element.id) { index, night in
                    Button { correcting = night } label: { row(night) }
                        .buttonStyle(Pressable())
                        .cardEntrance(index)
                }

                if nights.isEmpty { empty }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 110)
        }
        .refreshable {
            Feedback.play(.threadOpened)
            await clarityStore.refresh(context: context)
        }
        .background(InkBackground())
        .sheet(item: $correcting) { NightEditor(night: $0) }
        .navigationTitle("Mes nuits")
        .navigationBarTitleDisplayMode(.inline)
    }

    // ── L'en-tete dit d'ou ca vient, avant la liste ──

    @ViewBuilder
    private var header: some View {
        if !nights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(provenance)
                    .font(.system(size: 17, weight: .light))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if corrected == 0 && inferred == 0 {
                    Text("Une nuit fausse ? Touche-la pour la corriger. Ta correction fait autorité et aucune relecture ne l’écrase.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if inferred > 0 {
                    Text("Une nuit déduite est une estimation faite à partir de l’immobilité du téléphone. Elle ne figure pas dans Santé, et tu ne peux pas la vérifier ailleurs qu’ici.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
            .bentoSurface(inferred > 0 ? Ink.amber : Ink.teal, corner: 28, intensity: 0.5)
        }
    }

    private var measured: Int { nights.count { $0.measured && !$0.corrected } }
    private var inferred: Int { nights.count { !$0.measured && !$0.corrected } }
    private var corrected: Int { nights.count { $0.corrected } }

    private var provenance: String {
        var parts = [String]()
        if measured > 0 { parts.append("\(measured) lues dans Santé") }
        if inferred > 0 { parts.append("\(inferred) déduites du mouvement") }
        if corrected > 0 { parts.append("\(corrected) corrigées à la main") }
        guard parts.count > 1 else {
            return "\(nights.count) nuits, \(parts.first ?? "")."
        }
        return "\(nights.count) nuits : " + parts.joined(separator: ", ") + "."
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aucune nuit.")
                .font(.system(size: 19, weight: .light))
            Text("Sans nuits, Optium n’annonce pas de clarté et la porte reste fermée. Il reste utilisable comme carnet de fils.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .bentoSurface(Ink.indigo, corner: 28, intensity: 0.4)
    }

    // ── Les modules ──
    //
    // **Trois nuits au minimum, et chaque module a son propre seuil.** Un
    // dessin construit sur deux points donne une impression de savoir a partir
    // de rien, ce qui est pire que de ne rien montrer.

    @ViewBuilder
    private var modules: some View {
        biais
        empreinte
        levers
        durees
        decalage
        cafe
    }

    /// Ce que les corrections ont appris.
    ///
    /// **Le seul module qui parle de la mesure et non du sommeil.** Corriger
    /// une nuit repare cette nuit-la ; corriger quatre fois dans le meme sens
    /// dit que la source se trompe systematiquement, et de combien.
    ///
    /// Il n'applique rien. Un decalage applique en silence fabriquerait des
    /// nuits que personne n'a mesurees ni validees.
    @ViewBuilder
    private var biais: some View {
        if let estimate = SleepBias.estimate(from: nights), estimate.isMeaningful {
            NightModule(
                title: "Ce que tes corrections apprennent",
                fact: biaisFact(estimate),
                limit: "Optium ne corrige rien tout seul. Il te dit ce qu’il observe ; les nuits restent telles que Santé les rend, sauf celles que tu corriges.",
                hue: Ink.violet
            ) {
                BiasArrow(minutes: estimate.wakeShift / 60)
            }
        }
    }

    private func biaisFact(_ estimate: SleepBias.Estimate) -> String {
        let shift = Int((abs(estimate.wakeShift) / 60).rounded())
        let direction = estimate.wakeShift > 0 ? "plus tard" : "plus tôt"
        return "Sur \(estimate.sampleCount) corrections, ton vrai réveil arrive en médiane \(shift) min \(direction) que ce que la source annonce."
    }

    private var empreinte: some View {
        NightModule(
            title: "L’empreinte",
            fact: empreinteFact,
            limit: "Chaque ligne est une nuit, la plus récente en bas. Un bloc qui reste aligné, c’est de la régularité ; un bloc qui glisse, c’est ce que l’indice mesure. Rien ici ne dit si c’est bien.",
            hue: Ink.indigo
        ) {
            SleepRaster(rows: NightInsights.raster(nights: chronological))
        }
    }

    private var empreinteFact: String {
        let count = min(chronological.count, 28)
        return "Tes \(count) dernières nuits, posées sur l’heure du jour."
    }

    private var levers: some View {
        NightModule(
            title: "Tes levers",
            fact: leversFact,
            limit: "Le trait est ta médiane, pas une cible. Rien ne dit qu’il faille s’y tenir — c’est seulement ce que tu fais le plus souvent.",
            hue: Ink.violet
        ) {
            WakeScatter(points: NightInsights.wakePoints(nights: chronological))
        }
    }

    private var leversFact: String {
        let points = NightInsights.wakePoints(nights: chronological).map(\.hour)
        guard let low = points.min(), let high = points.max() else { return "" }
        let spread = high - low
        return spread < 1
            ? "Tes levers tiennent dans moins d’une heure."
            : String(format: "Tes levers s’étalent sur %.0f h %02.0f.", spread.rounded(.down), (spread - spread.rounded(.down)) * 60)
    }

    @ViewBuilder
    private var durees: some View {
        if let summary = NightInsights.durations(nights: chronological) {
            NightModule(
                title: "Les durées",
                fact: dureesFact(summary),
                limit: "La bande claire va de 7 à 9 h. Ce n’est pas un plancher : la relation entre durée et santé est en U, et douze heures ne valent pas mieux que huit.",
                hue: Ink.teal
            ) {
                DurationBars(nights: nights.sorted { $0.asleepAt < $1.asleepAt }.suffix(28))
            }
        }
    }

    private func dureesFact(_ summary: NightInsights.DurationSummary) -> String {
        let share = Int((summary.inTargetShare * 100).rounded())
        return "Médiane \(hours(summary.median)) — de \(hours(summary.shortest)) à \(hours(summary.longest)). \(share) % de tes nuits sont dans la bande."
    }

    @ViewBuilder
    private var decalage: some View {
        if let lag = NightInsights.socialJetLag(nights: chronological) {
            NightModule(
                title: "Décalage social",
                fact: "Ton milieu de nuit se déplace de \(hours(lag)) entre semaine et week-end.",
                limit: "L’application ne sait pas quels jours tu travailles : elle prend samedi et dimanche pour tes jours libres. Si tu travailles le week-end, ce chiffre ne veut rien dire.",
                hue: Ink.amber
            ) {
                SocialLagDial(hours: lag / 3600)
            }
        }
    }

    @ViewBuilder
    private var cafe: some View {
        if let comparison = NightInsights.coffeeEffect(
            nights: chronological, coffees: coffees.map(\.takenAt)
        ) {
            NightModule(
                title: "Le café, et la nuit d’après",
                fact: cafeFact(comparison),
                limit: "Deux médianes côte à côte, pas une cause. Les jours à café tardif sont souvent les jours chargés — c’est peut-être la charge qui raccourcit la nuit.",
                hue: Ink.coral
            ) {
                PairedBars(
                    leftLabel: "après un café tardif\n(\(comparison.lateNights) nuits)",
                    leftValue: comparison.afterLateCoffee,
                    rightLabel: "sans\n(\(comparison.otherNights) nuits)",
                    rightValue: comparison.afterNone
                )
            }
        }
    }

    private func cafeFact(_ comparison: NightInsights.CoffeeComparison) -> String {
        let gap = abs(comparison.gap)
        if gap < 15 * 60 { return "Tes nuits durent à peu près pareil dans les deux cas." }
        return comparison.gap > 0
            ? "Tes nuits sont plus courtes de \(hours(gap)) après un café tardif."
            : "Tes nuits sont plus longues de \(hours(gap)) après un café tardif."
    }

    private func hours(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        return minutes % 60 == 0
            ? "\(minutes / 60) h"
            : String(format: "%d h %02d", minutes / 60, minutes % 60)
    }

    // ── Une nuit ──

    private func row(_ night: RecordedNight) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(night.wokeAt.formatted(.dateTime.weekday(.abbreviated).day().month()))
                    .font(.subheadline.weight(.medium))
                Text(schedule(night))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(duration(night))
                    .font(.system(size: 18, weight: .medium))
                    .monospacedDigit()
                Label(originWord(night), systemImage: originSymbol(night))
                    .font(.caption2)
                    .foregroundStyle(night.corrected || !night.measured
                                     ? Ink.marker : Color.secondary)
            }
        }
        .padding(16)
        .bentoSurface(
            night.measured ? Ink.indigo : Ink.amber,
            corner: 22,
            // Les nuits deduites sont plus marquees : ce sont celles dont il
            // faut se souvenir qu'elles sont des estimations.
            intensity: night.measured ? 0.26 : 0.44
        )
    }

    /// L'horaire, et le temps eveille quand il y en a.
    ///
    /// **Sans cette mention, la ligne se contredit** : « 23 h → 7 h » a cote
    /// de « 7 h 20 » se lit comme une erreur de calcul, alors que les quarante
    /// minutes manquantes sont un reveil au milieu de la nuit.
    private func schedule(_ night: RecordedNight) -> String {
        let base = "\(Clock.hhmm(night.asleepAt)) → \(Clock.hhmm(night.wokeAt))"
        let awake = night.night.span - night.night.duration
        guard awake >= 5 * 60 else { return base }
        return base + " · \(Int((awake / 60).rounded())) min éveillé"
    }

    private func originWord(_ night: RecordedNight) -> String {
        if night.corrected { return "corrigée" }
        return night.measured ? "Santé" : "déduite"
    }

    private func originSymbol(_ night: RecordedNight) -> String {
        if night.corrected { return "pencil" }
        return night.measured ? "heart.fill" : "iphone.gen3"
    }

    private func duration(_ night: RecordedNight) -> String {
        let minutes = Int((night.night.duration / 60).rounded())
        return minutes % 60 == 0
            ? "\(minutes / 60) h"
            : String(format: "%d h %02d", minutes / 60, minutes % 60)
    }
}

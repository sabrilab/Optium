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
    @Query(sort: \RecordedNight.asleepAt, order: .reverse)
    private var nights: [RecordedNight]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                ForEach(Array(nights.prefix(60).enumerated()), id: \.element.id) { index, night in
                    row(night)
                        .cardEntrance(index)
                }

                if nights.isEmpty { empty }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 110)
        }
        .background(InkBackground())
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

    private var measured: Int { nights.count { $0.measured } }
    private var inferred: Int { nights.count { !$0.measured } }

    private var provenance: String {
        if inferred == 0 { return "\(measured) nuits, toutes lues dans Santé." }
        if measured == 0 { return "\(inferred) nuits, toutes déduites du mouvement du téléphone." }
        return "\(nights.count) nuits : \(measured) lues dans Santé, \(inferred) déduites du mouvement."
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

    // ── Une nuit ──

    private func row(_ night: RecordedNight) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(night.wokeAt.formatted(.dateTime.weekday(.abbreviated).day().month()))
                    .font(.subheadline.weight(.medium))
                Text("\(Clock.hhmm(night.asleepAt)) → \(Clock.hhmm(night.wokeAt))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(duration(night))
                    .font(.system(size: 18, weight: .medium))
                    .monospacedDigit()
                Label(
                    night.measured ? "Santé" : "déduite",
                    systemImage: night.measured ? "heart.fill" : "iphone.gen3"
                )
                .font(.caption2)
                .foregroundStyle(night.measured ? Color.secondary : Ink.marker)
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

    private func duration(_ night: RecordedNight) -> String {
        let minutes = Int((night.night.duration / 60).rounded())
        return minutes % 60 == 0
            ? "\(minutes / 60) h"
            : String(format: "%d h %02d", minutes / 60, minutes % 60)
    }
}

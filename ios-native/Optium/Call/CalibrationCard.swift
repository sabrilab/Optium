import SwiftData
import SwiftUI

/// Le retour sur erreur.
///
/// **Deux fois par semaine au maximum.** Une tape, deux reponses. L'ecart
/// entre le ressenti et la mesure est ce que l'utilisateur apprend — et c'est
/// tout l'objet : en restriction chronique, la somnolence ressentie plafonne
/// alors que la performance continue de decliner, donc les gens perdent la
/// capacite de se juger.
///
/// **On ne demande jamais de predire une duree.** Le biais de planification la
/// rend fausse, et cela ajouterait une saisie avant chaque reprise.
struct CalibrationCard: View {
    let measured: ClarityLevel

    @Environment(\.modelContext) private var context
    @Query(sort: \Calibration.askedAt, order: .reverse) private var past: [Calibration]

    @State private var justAnswered: Calibration?

    /// Au plus deux fois par semaine, et jamais deux jours de suite.
    private var shouldAsk: Bool {
        guard justAnswered == nil else { return false }
        let week = Date().addingTimeInterval(-7 * 86_400)
        let recent = past.filter { $0.askedAt >= week }
        guard recent.count < 2 else { return false }
        guard let last = recent.first else { return true }
        return !Calendar.current.isDateInToday(last.askedAt)
            && !Calendar.current.isDateInYesterday(last.askedAt)
    }

    var body: some View {
        if let answered = justAnswered {
            verdict(answered)
        } else if shouldAsk {
            question
        }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("À L’INSTANT")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary)

            Text("Tu te sens comment ?")
                .font(.system(size: 22, weight: .light))

            HStack(spacing: 10) {
                answerButton("Clair", felt: true)
                answerButton("Émoussé", felt: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .bentoSurface(Ink.teal, corner: 30, intensity: 0.55)
    }

    private func answerButton(_ label: String, felt: Bool) -> some View {
        Button {
            let calibration = Calibration(feltClear: felt, measured: measured)
            context.insert(calibration)
            withAnimation { justAnswered = calibration }
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.glass)
        .tint(Ink.control)
    }

    /// L'ecart, jamais un jugement. Quand ressenti et mesure concordent, on
    /// n'a rien a dire — et on ne dit rien.
    private func verdict(_ calibration: Calibration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(calibration.disagrees ? "L’ÉCART" : "NOTÉ")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary)

            Text(sentence(calibration))
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(calibration.disagrees ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .bentoSurface(Ink.teal, corner: 30, intensity: calibration.disagrees ? 0.55 : 0.25)
    }

    /// Elle constate l'ecart, elle ne dit pas ce qu'il signifie.
    ///
    /// « C'est le cas qui trompe le plus » figurait ici. C'etait le recit
    /// courant — le fatigue se croit performant — et il n'est pas soutenu :
    /// les estimations de performance apres privation sont plutot **plus
    /// conservatrices** (Bermudez et coll., *Sleep Medicine Reviews*, 2021).
    /// Voir `CalibrationSummary`.
    private func sentence(_ calibration: Calibration) -> String {
        guard calibration.disagrees else { return "Ton ressenti et ma mesure disent la même chose." }
        return calibration.feltClear
            ? "Tu te sens clair, je te mesure bas."
            : "Tu te sens émoussé, je te mesure haut."
    }
}

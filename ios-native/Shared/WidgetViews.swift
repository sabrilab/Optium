import SwiftUI
import WidgetKit

// Les vues des widgets vivent avec le code partage et non dans l'extension :
// l'application doit pouvoir les rendre pour les verifier. Seules les
// declarations `Widget` et leur fournisseur de chronologie restent cote
// extension, parce qu'elles n'ont de sens que la.

struct ClarityWidgetView: View {
    /// La famille est passee et non lue de l'environnement : `widgetFamily`
    /// est en lecture seule, donc impossible a simuler pour verifier les cinq
    /// tailles cote application.
    let family: WidgetFamily
    let snapshot: WidgetSnapshot

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Le cerveau seul, aucun texte : a cette taille un mot serait
            // illisible et volerait la place du seul signal utile.
            BrainSilhouetteView(fill: snapshot.fill, tint: .white, showsBase: false)

        case .accessoryRectangular:
            HStack(spacing: 8) {
                BrainSilhouetteView(fill: snapshot.fill, tint: .white, showsBase: false)
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(snapshot.isConfident ? "Clarté \(snapshot.clarityWord)" : "Pas mesurable")
                        .font(.system(size: 13, weight: .medium))
                    Text("FENÊTRE \(hhmm(snapshot.windowStart))")
                        .font(.system(size: 11).monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

        case .systemMedium:
            HStack(spacing: 18) {
                BrainSilhouetteView(fill: snapshot.fill, base: snapshot.base, tint: Ink.focusGlow)
                    .frame(width: 88, height: 88)
                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.isConfident ? snapshot.clarityWord : "pas encore mesurable")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.white)
                    if let phrase = snapshot.threadPhrase {
                        Text(phrase)
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(2)
                    }
                    Text("FENÊTRE JUSQU’À \(hhmm(snapshot.windowEnd))")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Ink.marker)
                }
                Spacer(minLength: 0)
            }

        default:
            VStack(spacing: 12) {
                BrainSilhouetteView(fill: snapshot.fill, base: snapshot.base, tint: Ink.focusGlow)
                    .frame(width: 82, height: 82)
                // Un mot, pas un chiffre — la meme regle que dans
                // l'application, pour la meme raison.
                Text(snapshot.isConfident ? snapshot.clarityWord.capitalized : "—")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(.white)
            }
        }
    }

    private func hhmm(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

struct ThreadWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                BrainSilhouetteView(fill: snapshot.fill, tint: Ink.focusGlow, showsBase: false)
                    .frame(width: 26, height: 26)
                Text((snapshot.tierWord ?? "").uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.62))
                Spacer()
            }

            Text(snapshot.threadPhrase ?? "Aucun fil ouvert")
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer(minLength: 0)

            if let landing = landing {
                Text(landing)
                    .font(.system(size: 12, weight: .medium).monospaced())
                    .foregroundStyle(Ink.marker)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// L'atterrissage ne s'affiche que s'il existe : inventer une date serait
    /// pire que de laisser la place vide.
    private var landing: String? {
        guard let earliest = snapshot.landingEarliest, let latest = snapshot.landingLatest else { return nil }
        let format = Date.FormatStyle.dateTime.weekday(.abbreviated).day()
        return "\(earliest.formatted(format).uppercased()) → \(latest.formatted(format).uppercased())"
    }
}

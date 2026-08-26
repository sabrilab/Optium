import SwiftUI

/// La première carte de l'accueil : ouvrir un fil, ou celui qui tourne.
///
/// **Le même emplacement, deux états.** C'est le modèle du lecteur de
/// musique : ce qui joue reste visible en haut, et se rouvre d'un geste. Une
/// reprise en cours était jusqu'ici invisible depuis l'accueil — il fallait
/// retrouver le fil dans la liste et le rouvrir, alors que c'est la seule
/// chose de l'application qui se passe *maintenant*.
///
/// **Elle est en tête et ne bouge jamais.** Une carte qui apparaît au milieu
/// d'une liste déplace tout ce qui la suit ; en tête, l'écran reste stable
/// qu'un fil tourne ou non — et c'est ce qui permet de la reconnaître sans la
/// chercher.
struct RunningCard: View {
    /// Le fil dont une reprise est en cours, ou `nil`.
    let running: WorkThread?
    let onOpen: () -> Void
    let onCompose: () -> Void

    var body: some View {
        if let running {
            Button(action: onOpen) {
                content(running)
            }
            .buttonStyle(Pressable())
        } else {
            Button(action: onCompose) {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Ouvrir un fil")
                        .font(.subheadline.weight(.medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Ink.control)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 30))
            }
            .buttonStyle(.plain)
        }
    }

    private func content(_ thread: WorkThread) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // Le seul endroit de l'application où quelque chose est
                // annoncé comme *en train* de se passer.
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(Ink.marker)
                Text("EN COURS")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(Ink.marker)
                Spacer(minLength: 0)
                if thread.nature == .decision {
                    Text(thread.nature.word.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                }
            }

            Text(thread.phrase)
                .font(.system(size: 20, weight: .light))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)

            // Le temps du fil entier, pas de la session : un fil se mesure sur
            // sa vie, jamais sur la reprise courante.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(elapsed(thread, at: context.date))
                        .font(.system(size: 26, weight: .light))
                        .monospacedDigit()
                    Text(rank(thread))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bentoSurface(Ink.violet, corner: 30, intensity: 0.55)
    }

    /// Le temps total du fil, au format de l'île dynamique.
    private func elapsed(_ thread: WorkThread, at date: Date) -> String {
        let closed = thread.resumptions
            .filter { $0.endedAt != nil }
            .reduce(0.0) { $0 + $1.duration }
        let running = thread.currentResumption
            .map { date.timeIntervalSince($0.startedAt) } ?? 0
        let seconds = max(0, Int(closed + running))

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        guard hours > 0 else { return String(format: "%d:%02d", minutes, seconds % 60) }
        return String(format: "%d:%02d:%02d", hours, minutes, seconds % 60)
    }

    private func rank(_ thread: WorkThread) -> String {
        let count = thread.resumptions.count
        return "\(count)\(count == 1 ? "re" : "e") reprise"
    }
}

import SwiftData
import SwiftUI

/// Ce que tu as décidé, et pourquoi.
///
/// **C'est le seul véritable investissement du produit.** Tout le reste est
/// lu : le sommeil, le mouvement, la fenêtre. Ces lignes-là, l'utilisateur les
/// a écrites — à la porte, au moment où l'application l'arrêtait, donc au seul
/// moment où il réfléchissait vraiment à ce qu'il validait.
///
/// Les enregistrer sans jamais les remontrer revenait à jeter la seule chose
/// qu'on demande. Une application à laquelle on ne donne rien est une
/// application qu'on quitte sans rien perdre.
///
/// Ce n'est pas un tableau de bord : aucun chiffre, aucune courbe, aucune
/// moyenne. Ce sont des phrases, dans l'ordre où elles ont été écrites.
struct CorpusScreen: View {
    @Query(filter: #Predicate<WorkThread> { $0.closedAt != nil },
           sort: \WorkThread.closedAt, order: .reverse)
    private var closed: [WorkThread]

    /// Un fil n'entre au corpus que s'il porte une phrase écrite. Un fil fermé
    /// sans acceptation ni restitution n'a rien à relire.
    private var written: [WorkThread] {
        closed.filter { $0.acceptance != nil || $0.restitution != nil }
    }

    var body: some View {
        Group {
            if written.isEmpty {
                ContentUnavailableView {
                    Label("Rien encore", systemImage: "text.quote")
                } description: {
                    Text("Ce que tu écris à la porte, et ce que tu retiens en fermant un fil, s’inscrit ici.")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(Array(written.enumerated()), id: \.element.id) { index, thread in
                            entry(thread, hue: Ink.cardHues[index % Ink.cardHues.count])
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                }
            }
        }
        .background(InkBackground())
        .navigationTitle("Ce que tu as décidé")
        .toolbar {
            if !written.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: export()) {
                        Label("Exporter", systemImage: "square.and.arrow.up")
                    }
                    .tint(Ink.control)
                }
            }
        }
    }

    private func entry(_ thread: WorkThread, hue: Ink.CardHue) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                if let project = thread.project {
                    Circle().fill(project.hue.tint).frame(width: 6, height: 6)
                    Text(project.title.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(1.3)
                        .foregroundStyle(.secondary)
                    Text("·").font(.caption2).foregroundStyle(.tertiary)
                }
                Text(date(thread.closedAt).uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.3)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(thread.phrase)
                .font(.system(size: 19, weight: .light))
                .frame(maxWidth: .infinity, alignment: .leading)

            if let acceptance = thread.acceptance {
                quote("ACCEPTÉ", acceptance)
            }
            if let restitution = thread.restitution {
                quote("RETENU", restitution)
            }
        }
        .padding(18)
        .bentoSurface(hue, corner: 28, intensity: 0.42)
    }

    private func quote(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Ink.marker.opacity(0.85))
            Text(text)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 12)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 1)
        }
    }

    private func date(_ date: Date?) -> String {
        (date ?? Date()).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// Le corpus s'exporte en texte brut. Il appartient à qui l'a écrit, et un
    /// format qu'on ne peut pas ouvrir ailleurs serait une promesse creuse.
    private func export() -> String {
        written.map { thread in
            var block = "## \(thread.phrase)\n\(date(thread.closedAt))\n"
            if let acceptance = thread.acceptance { block += "\nAccepté : \(acceptance)\n" }
            if let restitution = thread.restitution { block += "\nRetenu : \(restitution)\n" }
            return block
        }.joined(separator: "\n---\n\n")
    }
}

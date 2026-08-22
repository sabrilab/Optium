import SwiftUI

/// Fermeture du fil.
///
/// La phrase de départ est remontrée **telle quelle**. C'est tout l'intérêt de
/// l'avoir figée à l'ouverture : on lit ce qu'on croyait faire à côté de ce
/// que ça a pris.
struct ClosedScreen: View {
    let thread: WorkThread
    let onDone: () -> Void

    @State private var restitution = ""
    @FocusState private var writing: Bool

    private var summary: ThreadSummary { thread.summary() }

    private func finish() {
        let trimmed = restitution.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { thread.restitution = trimmed }
        // La memoire du projet s'ecrit ici, une ligne par fil ferme. Elle est
        // en markdown local : l'utilisateur doit pouvoir la lire, la corriger
        // et tout effacer, sinon la promesse de confidentialite ne se verifie
        // pas.
        ProjectMemory(projectTitle: thread.project?.title ?? "Sans projet")
            .append(memoryLine(restitution: trimmed), at: thread.closedAt ?? Date())
        onDone()
    }

    private func memoryLine(restitution: String) -> String {
        var line = "« \(thread.phrase) » — \(summary.resumptionCount) reprises"
        if summary.nightsCrossed > 0 { line += ", \(summary.nightsCrossed) nuits" }
        if summary.holdCount > 0 { line += ", \(summary.holdCount) retenues" }
        if let acceptance = thread.acceptance { line += ". Accepté : \(acceptance)" }
        if !restitution.isEmpty { line += ". Retenu : \(restitution)" }
        return line
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("FIL FERMÉ")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 22)

                Text("Ce que ça a pris")
                    .font(.system(size: 24, weight: .light))
                    .padding(.bottom, 20)

                HStack(spacing: 12) {
                    tally("\(summary.resumptionCount)", summary.resumptionCount == 1 ? "reprise" : "reprises", Ink.indigo)
                    tally("\(summary.inWindowCount)", "dans la fenêtre", Ink.teal)
                }
                .padding(.bottom, 12)

                HStack(spacing: 12) {
                    tally("\(summary.nightsCrossed)", summary.nightsCrossed == 1 ? "nuit" : "nuits", Ink.violet)
                    tally("\(summary.holdCount)", summary.holdCount == 1 ? "retenue" : "retenues", Ink.amber)
                }
                .padding(.bottom, 26)

                VStack(alignment: .leading, spacing: 12) {
                    Text("TA PHRASE, \(openedOn)")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                    Text(thread.phrase)
                        .font(.system(size: 20, weight: .light))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .bentoSurface(Ink.rose, corner: 30, intensity: 0.45)

                restitutionField

                if let acceptance = thread.acceptance {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CE QUE TU AS ACCEPTÉ")
                            .font(.caption2.weight(.semibold))
                            .tracking(1.4)
                            .foregroundStyle(.secondary)
                        Text(acceptance)
                            .font(.system(size: 17, weight: .light))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .bentoSurface(Ink.coral, corner: 30, intensity: 0.4)
                    .padding(.top, 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 120)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: finish) {
                Text("C’est bien ça")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.glass)
            .tint(Ink.control)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    /// Ce qu'on en retient.
    ///
    /// Facultatif, et presente apres le bilan : on ne demande pas a quelqu'un
    /// ce qu'il a appris avant de lui avoir montre ce que ca a pris.
    private var restitutionField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CE QUE TU EN RETIENS")
                .font(.caption2.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            TextField("", text: $restitution, axis: .vertical)
                .font(.system(size: 17, weight: .light))
                .lineLimit(2...5)
                .focused($writing)
                .overlay(alignment: .topLeading) {
                    if restitution.isEmpty {
                        Text("Facultatif.")
                            .font(.system(size: 17, weight: .light))
                            .foregroundStyle(.tertiary)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(restitution.isEmpty ? Color.white.opacity(0.14) : Ink.marker)
                        .frame(height: 1)
                        .offset(y: 6)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .bentoSurface(Ink.teal, corner: 30, intensity: 0.35)
        .padding(.top, 12)
    }

    private var openedOn: String {
        thread.createdAt.formatted(.dateTime.weekday(.wide)).uppercased()
    }

    private func tally(_ value: String, _ label: String, _ hue: Ink.CardHue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.system(size: 30, weight: .light))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .bentoSurface(hue, corner: 28, intensity: 0.5)
    }
}

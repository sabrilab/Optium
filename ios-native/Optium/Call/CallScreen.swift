import SwiftData
import SwiftUI

/// L'appel au cerveau.
///
/// **Trois questions, et rien d'autre.** Un champ libre en ferait un chatbot
/// generique, ce que le produit refuse explicitement. Le role du cerveau est
/// borne, et c'est cette bornure qui le rend utile.
struct CallScreen: View {
    @Environment(ClarityStore.self) private var clarityStore
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @Query private var threads: [WorkThread]
    @Query private var nights: [RecordedNight]
    @Query(sort: \Project.openedAt, order: .reverse) private var projects: [Project]

    @State private var call = BrainCall()
    /// Le projet dont on parle. `nil` veut dire « tout », et non « aucun ».
    @State private var scope: Project?

    private static let questions = [
        "Qu’est-ce que j’ai appris sur ma façon de travailler ?",
        "Qu’est-ce que je fais de ce projet ensuite ?",
        "Sur quoi est-ce que je me raconte des histoires ?",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if settings.brainEnabled {
                        BrainView(
                            fill: clarityStore.reading.brainFill,
                            base: 1,
                            agitation: thinking ? 0.9 : 0.2,
                            isDay: true,
                            isVisible: scenePhase == .active
                        )
                        .frame(height: 190)
                        .frame(maxWidth: .infinity)
                    }

                    switch call.state {
                    case .idle:
                        if !projects.isEmpty { scopePicker }
                        questionList
                    case .unavailable(let reason):
                        answer(reason, muted: true)
                    case .thinking:
                        Text("…")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    case .answered(let text):
                        answer(text, muted: false)
                        Button("Autre chose") { call.reset() }
                            .font(.subheadline)
                            .foregroundStyle(Ink.marker)
                            .frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 60)
            }
            .background(InkBackground())
            .navigationTitle("Appel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }.tint(Ink.control)
                }
            }
        }
    }

    private var thinking: Bool {
        if case .thinking = call.state { return true }
        return false
    }

    /// De quel projet parle-t-on.
    ///
    /// **Sans lui, la deuxieme question ne pouvait pas etre repondue.** Elle
    /// demande « qu'est-ce que je fais de ce projet ensuite ? » alors que le
    /// cerveau recevait tous les fils, tous projets confondus, et aucune
    /// memoire : il devait deviner de quel projet il s'agissait. Le defaut
    /// reste « tout », qui est une reponse honnete quand on n'a qu'un projet.
    private var scopePicker: some View {
        Menu {
            Button("Tout") { scope = nil }
            ForEach(projects) { project in
                Button(project.title) { scope = project }
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(scope?.hue.tint ?? Color.white.opacity(0.28))
                    .frame(width: 7, height: 7)
                Text(scope?.title ?? "Tout")
                    .font(.subheadline)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(minHeight: 44)
        }
        .tint(Ink.control)
    }

    private var questionList: some View {
        VStack(spacing: 12) {
            ForEach(Self.questions, id: \.self) { question in
                Button {
                    Task { await call.ask(question, context: context) }
                } label: {
                    Text(question)
                        .font(.system(size: 18, weight: .light))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                }
                .buttonStyle(.plain)
                .bentoSurface(Ink.indigo, corner: 26, intensity: 0.4)
            }
        }
    }

    /// La memoire du perimetre, tronquee par la fin.
    ///
    /// On garde les dernieres lignes et non les premieres : la memoire
    /// s'accumule sans jamais s'ecraser, et c'est le recent qui eclaire la
    /// question posee. La borne existe parce que la fenetre du modele sur
    /// appareil est etroite — un fichier de deux ans la remplirait a lui seul
    /// et chasserait les faits mesures.
    private var memory: String {
        let titles = scope.map { [$0.title] } ?? projects.map(\.title) + ["Sans projet"]
        let lines = titles
            .map { ProjectMemory(projectTitle: $0).read() }
            .flatMap { $0.split(separator: "\n", omittingEmptySubsequences: true) }
            .filter { $0.hasPrefix("- ") }
        return lines.suffix(24).joined(separator: "\n")
    }

    private func answer(_ text: String, muted: Bool) -> some View {
        Text(text)
            .font(.system(size: 19, weight: .light))
            .foregroundStyle(muted ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var context: BrainCall.Context {
        // Le perimetre filtre ce que le cerveau voit. « Tout » ne filtre rien.
        let inScope = scope.map { project in
            threads.filter { $0.project?.id == project.id }
        } ?? threads
        let closed = inScope.filter { $0.closedAt != nil }
        return BrainCall.Context(
            nightCount: nights.count,
            regularity: clarityStore.reading.regularity,
            clarity: clarityStore.reading.clarity?.level,
            closedThreads: closed.map { thread in
                let summary = thread.summary()
                return (thread.phrase, summary.resumptionCount, summary.nightsCrossed, summary.holdCount)
            },
            openPhrases: inScope.filter { $0.closedAt == nil }.map(\.phrase),
            // **La memoire etait en ecriture seule.** Une ligne markdown
            // s'ecrivait a chaque fil ferme depuis le premier jour, et rien ne
            // la relisait jamais : le champ valait la chaine vide. C'est
            // pourtant elle qui donne au cerveau sa continuite d'un mois sur
            // l'autre.
            memory: memory
        )
    }
}

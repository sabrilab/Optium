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

    @State private var call = BrainCall()

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
                            fill: Double(clarityStore.reading.clarity.value) / 100,
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

    private func answer(_ text: String, muted: Bool) -> some View {
        Text(text)
            .font(.system(size: 19, weight: .light))
            .foregroundStyle(muted ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var context: BrainCall.Context {
        let closed = threads.filter { $0.closedAt != nil }
        return BrainCall.Context(
            nightCount: nights.count,
            regularity: clarityStore.reading.regularity,
            clarity: clarityStore.reading.clarity.level,
            isConfident: clarityStore.reading.isConfident,
            closedThreads: closed.map { thread in
                let summary = thread.summary()
                return (thread.phrase, summary.resumptionCount, summary.nightsCrossed, summary.holdCount)
            },
            openPhrases: threads.filter { $0.closedAt == nil }.map(\.phrase),
            memory: ""
        )
    }
}

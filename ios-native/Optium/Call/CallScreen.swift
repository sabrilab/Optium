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
    @State private var stage = CallStage()
    @State private var voice = Voice()
    /// La question choisie. **La parole libre n'ouvre qu'a l'interieur d'un
    /// sujet** : les trois questions bornent le role du cerveau, et ce bornage
    /// est ce qui l'empeche de devenir un assistant generique.
    @State private var subject: String?
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
                            effort: thinking ? 1 : 0,
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
                        holdToSpeak
                        Button("Autre chose") {
                            voice.stopSpeaking()
                            subject = nil
                            // La scene se vide avec l'appel : il ne doit rien
                            // rester a faire defiler.
                            stage.clear()
                            call.reset()
                        }
                            .font(.subheadline)
                            .foregroundStyle(Ink.marker)
                            .frame(minHeight: 44)
                    }

                    // Ce que le cerveau vient de consulter. Une seule carte, et
                    // elle remplace la precedente.
                    if let exhibit = stage.exhibit {
                        ExhibitCard(exhibit: exhibit)
                            .id(exhibit)
                    }
                }
                .animation(Motion.state, value: stage.exhibit)
                .padding(.horizontal, 22)
                .padding(.bottom, 60)
            }
            .background(InkBackground())
            // L'aura deborde jusqu'aux bords pendant qu'on parle.
            .overlay {
                CallAura(
                    level: voice.level,
                    isActive: voice.state == .listening || thinking
                )
            }
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
            Button("Tout") { Feedback.play(.answered); scope = nil }
            ForEach(projects) { project in
                Button(project.title) { Feedback.play(.answered); scope = project }
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
                    Feedback.play(.threadOpened)
                    subject = question
                    Task {
                        await call.ask(question, facts: facts, stage: stage)
                        if case let .answered(text) = call.state { voice.say(text) }
                    }
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

    /// Reprendre la parole, a l'interieur du sujet choisi.
    ///
    /// **Appui maintenu.** On parle tant qu'on appuie : pas de seuil de silence
    /// a regler, pas de faux depart, et la fin appartient a l'utilisateur. Un
    /// appel qu'on tient est un appel qui se termine quand on lache.
    @ViewBuilder
    private var holdToSpeak: some View {
        if voice.isSupported {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: voice.state == .listening ? "waveform" : "mic.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(voice.state == .listening ? Ink.marker : Ink.control)
                    .frame(width: 58, height: 58)
                    .glassEffect(.regular, in: .circle)
                    .scaleEffect(voice.state == .listening ? 1.06 : 1)
                    .animation(Motion.state, value: voice.state)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                guard voice.state == .idle else { return }
                                Feedback.play(.threadOpened)
                                voice.stopSpeaking()
                                Task { await voice.startListening() }
                            }
                            .onEnded { _ in
                                Task {
                                    let question = await voice.stopListening()
                                    guard !question.isEmpty else { return }
                                    Feedback.play(.answered)
                                    await call.ask(prefixed(question), facts: facts, stage: stage)
                                    if case let .answered(text) = call.state { voice.say(text) }
                                }
                            }
                    )

                Text(spokenLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var spokenLabel: String {
        switch voice.state {
        case .listening: voice.heard.isEmpty ? "Je t’écoute…" : voice.heard
        case .preparing: "Un instant…"
        case .unavailable(let why): why
        case .idle: "Maintiens pour parler"
        }
    }

    /// La parole libre reste rattachee au sujet choisi.
    private func prefixed(_ question: String) -> String {
        guard let subject else { return question }
        return "Toujours sur « \(subject) » : \(question)"
    }

    private func answer(_ text: String, muted: Bool) -> some View {
        Text(text)
            .font(.system(size: 19, weight: .light))
            .foregroundStyle(muted ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }


    /// L'instantane passe aux outils.
    ///
    /// Il est capture avant l'appel et ne bouge plus : les outils sont
    /// `Sendable` et consultes hors du fil principal, leur donner le contexte
    /// SwiftData les rendrait dependants d'un acteur.
    private var facts: CallFacts {
        // Le perimetre filtre ce que le cerveau voit. « Tout » ne filtre rien.
        let inScope = scope.map { project in
            threads.filter { $0.project?.id == project.id }
        } ?? threads
        let closed = inScope.filter { $0.closedAt != nil }
        let tier = clarityStore.reading.regularity.map(Tier.init(regularity:))

        return CallFacts(
            nightCount: nights.count,
            regularity: clarityStore.reading.regularity,
            clarityWord: clarityStore.reading.clarity?.level.word,
            window: clarityStore.reading.window,
            closed: closed.map { thread in
                let summary = thread.summary()
                return ClosedThreadFact(
                    phrase: thread.phrase,
                    resumptions: summary.resumptionCount,
                    nights: summary.nightsCrossed,
                    held: summary.holdCount
                )
            },
            open: inScope.filter { $0.closedAt == nil }.map(\.phrase),
            tierWord: tier?.word,
            tierShare: tier?.situation,
            tierDays: TierHistory.daysAtCurrentTier(nights: nights.map(\.night), now: Date()),
            memory: memory,
            scope: scope?.title
        )
    }

}

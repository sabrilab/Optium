import AppIntents
import Foundation
import SwiftData

/// Ouvrir un fil a la voix.
///
/// **N'ouvre pas l'application.** C'est la condition pour que l'intention
/// serve a quelque chose : une idee qui arrive en marchant se note en parlant,
/// pas en deverrouillant un telephone.
struct OpenThreadIntent: AppIntent {
    static let title: LocalizedStringResource = "Ouvrir un fil"
    static let description = IntentDescription("Ouvre un fil de travail à partir d’une phrase.")
    static let openAppWhenRun = false

    @Parameter(title: "Sur quoi ?", requestValueDialog: "Sur quoi ?")
    var phrase: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "Il me faut une phrase.")
        }

        let context = ModelContext(OptiumContainer.shared)
        // La nature se qualifie dans l'application : la deviner ici ferait
        // s'ouvrir ou non la porte sur une supposition.
        context.insert(WorkThread(phrase: trimmed, nature: .production))
        try context.save()

        return .result(dialog: "Fil ouvert.")
    }
}

/// Retenir une decision jusqu'a la prochaine fenetre.
///
/// C'est la porte, invoquee de l'exterieur. Elle retient le fil de decision
/// ouvert le plus recemment.
struct HoldDecisionIntent: AppIntent {
    static let title: LocalizedStringResource = "Retenir une décision"
    static let description = IntentDescription("Retient la décision en cours jusqu’à la prochaine fenêtre.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(OptiumContainer.shared)
        let descriptor = FetchDescriptor<WorkThread>(
            predicate: #Predicate { $0.closedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let open = (try? context.fetch(descriptor)) ?? []
        guard let decision = open.first(where: { $0.nature == .decision }) else {
            return .result(dialog: "Aucune décision ouverte.")
        }

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let next = Calendar.current.startOfDay(for: tomorrow).addingTimeInterval(9.5 * 3600)
        decision.hold(until: next, at: Date())
        try context.save()

        return .result(dialog: "Retenu jusqu’à demain matin.")
    }
}

/// Ce que le cerveau sait de son etat.
///
/// **Il parle de lui, jamais de l'utilisateur a l'imperatif.** Sans cette
/// regle, on se fait sermonner par un organe personnifie. Et il sait dire
/// qu'il ne sait pas : un oracle qui a toujours une reponse ment en
/// permanence.
struct ClarityIntent: AppIntent {
    static let title: LocalizedStringResource = "Demander la clarté"
    static let description = IntentDescription("Dit si le moment se prête à trancher.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(OptiumContainer.shared)
        let horizon = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        let nights = (try? context.fetch(
            FetchDescriptor<RecordedNight>(predicate: #Predicate { $0.wokeAt >= horizon })
        )) ?? []

        let reading = ClarityEngine.reading(nights: nights.map(\.night), now: Date())

        // Il sait dire qu'il ne sait pas : un oracle qui a toujours une
        // reponse ment en permanence.
        guard let clarity = reading.clarity else {
            let count = reading.observedNights
            return .result(dialog: count == 0
                ? "Je n’ai encore rien observé. Je ne peux pas te répondre."
                : "Je n’ai que \(count) nuit\(count > 1 ? "s" : ""). Ça ne suffit pas pour l’affirmer.")
        }

        let inWindow = reading.window.contains(Date())
        switch (clarity.level, inWindow) {
        case (.high, true):
            return .result(dialog: "Je tourne haut, et la fenêtre est ouverte.")
        case (.high, false), (.medium, true):
            return .result(dialog: "Je tourne \(clarity.level.word), hors de la fenêtre.")
        case (.medium, false):
            return .result(dialog: "Je tourne moyen. La fenêtre est passée.")
        case (.low, _):
            return .result(dialog: "Je tourne bas. Je retiendrais plutôt.")
        }
    }
}

struct OptiumShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ClarityIntent(),
            phrases: [
                "Appelle mon cerveau dans \(.applicationName)",
                "Est-ce que je tranche maintenant avec \(.applicationName)",
            ],
            shortTitle: "Clarté",
            systemImageName: "brain"
        )
        AppShortcut(
            intent: OpenThreadIntent(),
            phrases: ["Ouvre un fil dans \(.applicationName)"],
            shortTitle: "Ouvrir un fil",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: HoldDecisionIntent(),
            phrases: ["Retiens cette décision dans \(.applicationName)"],
            shortTitle: "Retenir",
            systemImageName: "hand.raised"
        )
    }
}

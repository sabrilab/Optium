import Foundation
import SwiftData

/// La nature d'un fil. Elle decide si la porte peut s'ouvrir.
enum ThreadNature: String, Codable, CaseIterable {
    case decision, production, mechanical

    var word: String {
        switch self {
        case .decision: "Décision"
        case .production: "Production"
        case .mechanical: "Mécanique"
        }
    }

    var explanation: String {
        switch self {
        case .decision: "Quelque chose à trancher. Le seul cas où Optium peut t’arrêter."
        case .production: "Quelque chose à produire."
        case .mechanical: "Quelque chose à exécuter, sans jugement."
        }
    }
}

enum ThreadState: String, Codable {
    case open, inProgress, closed, held
}

/// L'issue d'une tentative de fermeture.
enum ClosingOutcome {
    case direct
    case gate
}

/// Ce qu'un fil aura pris, une fois ferme.
struct ThreadSummary {
    let resumptionCount: Int
    let inWindowCount: Int
    let nightsCrossed: Int
    let holdCount: Int
    let totalDuration: TimeInterval
}

/// Un fil de travail : une phrase d'intention, ouverte de quelques heures a
/// plusieurs jours.
///
/// Nomme `WorkThread` et non `Thread` : `Thread` est le type de Foundation, et
/// l'ombrer rendrait ambigue toute utilisation du vrai. Meme piege que `Task`.
@Model
final class WorkThread {
    var id: UUID = UUID()
    /// L'intention. Saisie une fois, jamais reecrite — elle est remontree
    /// telle quelle a la fermeture, et c'est tout son interet.
    var phrase: String = ""
    var nature: ThreadNature = ThreadNature.production
    var state: ThreadState = ThreadState.open
    var createdAt: Date = Date()
    var closedAt: Date?
    /// Renseigne quand le fil est passe par la porte et a ete retenu.
    var heldUntil: Date?
    /// La ligne ecrite a la porte. Sans elle, une decision ne se ferme pas.
    var acceptance: String?
    /// Combien de fois ce fil a ete retenu. Compte pour la preuve « Retenue ».
    var holdCount: Int = 0
    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \Resumption.thread)
    var resumptions: [Resumption] = []

    init(phrase: String, nature: ThreadNature, createdAt: Date = Date()) {
        self.id = UUID()
        self.phrase = phrase
        self.nature = nature
        self.createdAt = createdAt
    }

    // ── Lectures ──

    var currentResumption: Resumption? {
        resumptions.first { $0.endedAt == nil }
    }

    var orderedResumptions: [Resumption] {
        resumptions.sorted { $0.startedAt < $1.startedAt }
    }

    /// **La regle centrale du produit.**
    ///
    /// La porte s'ouvre pour une decision a clarte basse, et pour rien
    /// d'autre. Sa rarete est ce qui la rend acceptable : elargir cette
    /// condition la transformerait en friction ordinaire, et l'application
    /// perdrait la seule chose qu'elle sait faire.
    func closingOutcome(clarity: ClarityLevel) -> ClosingOutcome {
        nature == .decision && clarity == .low ? .gate : .direct
    }

    // ── Transitions ──

    func startResumption(clarity: ClarityLevel, inWindow: Bool, at date: Date) {
        // Une reprise deja ouverte n'est pas doublee : l'ecran peut reapparaitre
        // sans consequence.
        guard currentResumption == nil else { return }
        resumptions.append(
            Resumption(startedAt: date, clarityAtStart: clarity, inWindow: inWindow)
        )
        state = .inProgress
    }

    func pause(at date: Date) {
        currentResumption?.endedAt = date
        if state == .inProgress { state = .open }
    }

    func close(at date: Date) {
        pause(at: date)
        state = .closed
        closedAt = date
    }

    /// Fermeture par la porte.
    ///
    /// - Returns: `false` si aucune ligne n'a ete ecrite. Le fil reste alors
    ///   intact — c'est le point de la porte : on ne la franchit qu'en disant
    ///   ce qu'on accepte.
    @discardableResult
    func closeThroughGate(acceptance text: String, at date: Date) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        acceptance = trimmed
        close(at: date)
        return true
    }

    func hold(until date: Date, at now: Date) {
        pause(at: now)
        state = .held
        heldUntil = date
        holdCount += 1
    }

    /// Un fil retenu redevient ouvert de lui-meme a l'echeance.
    ///
    /// Rien ne le notifie et rien ne le reproche : le plan se perime, il ne
    /// reprimande pas.
    func releaseIfDue(now: Date) {
        guard state == .held, let heldUntil, now >= heldUntil else { return }
        state = .open
        self.heldUntil = nil
    }

    // ── Bilan ──

    func summary(calendar: Calendar = .current) -> ThreadSummary {
        let ended = closedAt ?? Date()
        let startDay = calendar.startOfDay(for: createdAt)
        let endDay = calendar.startOfDay(for: ended)
        let nights = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0

        return ThreadSummary(
            resumptionCount: resumptions.count,
            inWindowCount: resumptions.filter(\.inWindow).count,
            nightsCrossed: max(0, nights),
            holdCount: holdCount,
            totalDuration: resumptions.reduce(0) { $0 + $1.duration }
        )
    }
}

import ActivityKit
import Foundation

/// La reprise en cours, sur l'ecran verrouille et dans l'ile dynamique.
///
/// Une seule a la fois : deux reprises simultanees n'existent pas dans le
/// produit, et deux activites empilees rendraient l'ile illisible.
@MainActor
enum LiveActivityController {
    private static var current: Activity<OptiumActivity>?

    static var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func start(thread: WorkThread, reading: ClarityReading, landing: Landing?) {
        guard isSupported, current == nil else { return }

        let attributes = OptiumActivity(
            phrase: thread.phrase,
            isDecision: thread.nature == .decision
        )
        let state = state(thread: thread, reading: reading, landing: landing)

        current = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil)
        )
    }

    static func update(thread: WorkThread, reading: ClarityReading, landing: Landing?) async {
        guard let current else { return }
        await current.update(
            ActivityContent(state: state(thread: thread, reading: reading, landing: landing),
                            staleDate: nil)
        )
    }

    /// Fin immediate : une activite qui survit a la reprise donnerait
    /// l'impression que le fil tourne encore.
    static func end() async {
        guard let activity = current else { return }
        current = nil
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    private static func state(
        thread: WorkThread,
        reading: ClarityReading,
        landing: Landing?
    ) -> OptiumActivity.ContentState {
        let format = Date.FormatStyle.dateTime.weekday(.abbreviated).day()
        return OptiumActivity.ContentState(
            fill: reading.clarity.map { Double($0.value) / 100 } ?? 0,
            base: reading.regularity.map { min(1, 0.45 + $0 / 100 * 0.55) } ?? 1,
            clarityWord: reading.clarity?.level.word ?? "en observation",
            resumptionNumber: thread.resumptions.count,
            startedAt: thread.currentResumption?.startedAt ?? Date(),
            windowEnd: reading.window.end,
            landing: landing.map {
                "\($0.earliest.formatted(format)) → \($0.latest.formatted(format))"
            }
        )
    }
}

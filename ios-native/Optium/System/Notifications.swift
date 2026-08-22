import Foundation
import UserNotifications

/// **Il y a exactement deux notifications, et il n'y en aura pas d'autres.**
///
/// Jamais pendant un fil. La porte n'en est pas une : elle se declenche dans
/// l'application, au moment de la fermeture. Aucune ne pousse vers un creneau,
/// aucune ne reproche quoi que ce soit — le plan se perime, il ne reprimande
/// pas.
enum Notifications {
    private static let morning = "optium.matin"
    private static let evening = "optium.soir"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Reprogramme les deux rendez-vous du jour.
    ///
    /// Repetition quotidienne : les heures suivent la fenetre, qui suit le
    /// chronotype appris. Elles se deplacent donc d'elles-memes quand les
    /// habitudes changent.
    static func schedule(window: DateInterval, bedtime: Date, threadCount: Int, calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [morning, evening])
        guard await requestAuthorization() else { return }

        // Trente minutes avant l'ouverture, jamais au reveil : prevenir
        // quelqu'un qui vient d'ouvrir les yeux, c'est l'interrompre.
        let opening = window.start
        let notice = opening.addingTimeInterval(-30 * 60)
        let morningBody = threadCount > 0
            ? "\(threadCount) fil\(threadCount > 1 ? "s" : "") placé\(threadCount > 1 ? "s" : ""). La décision d’abord — c’est le seul moment de la journée où elle tient."
            : "C’est le moment de la journée où une décision tient."
        await add(
            id: morning,
            title: "Ta fenêtre s’ouvre à \(hhmm(opening, calendar))",
            body: morningBody,
            at: notice,
            calendar: calendar
        )

        // Le soir : une observation, pas un ordre.
        let lastResumption = bedtime.addingTimeInterval(-90 * 60)
        await add(
            id: evening,
            title: "Dernière reprise avant \(hhmm(lastResumption, calendar))",
            body: "Au-delà, je démarre demain une reprise plus bas. Coucher visé \(hhmm(bedtime, calendar)).",
            at: lastResumption,
            calendar: calendar
        )
    }

    static func cancelAll() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [morning, evening])
    }

    private static func add(id: String, title: String, body: String, at date: Date, calendar: Calendar) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var parts = calendar.dateComponents([.hour, .minute], from: date)
        parts.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)

        try? await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private static func hhmm(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}

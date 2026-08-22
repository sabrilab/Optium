import Foundation

/// La phrase qui accompagne le refus.
///
/// **C'est l'ajout le plus important du tronçon.** Sans elle, la porte affirme
/// une clarté basse sans preuve : rien ne relie ce qui a été mesuré à ce que
/// l'application vient de faire.
///
/// Elle cite le fait mesuré dont le manque pèse le plus. Un fait, jamais un
/// score : « tu as dormi 5 h 10 » est vérifiable dans Santé, « ta régularité
/// est de 71 » ne l'est nulle part.
///
/// Ce qu'elle ne fait jamais : pas de conseil, pas de jugement, aucun nombre
/// qui ressemble à une note, et aucune cause — l'application mesure une
/// corrélation de vigilance, elle n'explique pas pourquoi la nuit a été courte.
enum GateJustification {
    static func sentence(for reading: ClarityReading, now: Date, calendar: Calendar = .current) -> String? {
        let cited = reading.citedShortfalls
        guard !cited.isEmpty else { return nil }

        let parts = cited.compactMap { phrase(for: $0.component, reading: reading, now: now, calendar: calendar) }
        guard let first = parts.first else { return nil }
        guard parts.count > 1 else { return first + "." }

        // Deux faits se joignent en une seule phrase : deux phrases separees
        // se liraient comme un reproche qui s'accumule.
        let second = parts[1].prefix(1).lowercased() + parts[1].dropFirst()
        return first + ", et " + second + "."
    }

    private static func phrase(
        for component: ClarityComponent,
        reading: ClarityReading,
        now: Date,
        calendar: Calendar
    ) -> String? {
        switch component {
        case .duration:
            guard let duration = reading.lastNightDuration else { return nil }
            let text = "Tu as dormi \(hours(duration)) cette nuit"
            // Sous quatre heures ou au-dela de dix, on precise que l'ecart
            // joue dans les deux sens : sans cela, dormir douze heures se lit
            // comme une erreur de mesure.
            let value = duration / 3600
            if value > 10 { return text + " — au-delà de ta cible, comme en deçà" }
            return text

        case .regularity:
            guard let spread = reading.wakeSpread, spread >= 20 * 60 else { return nil }
            return "Tes trois derniers levers ont varié de \(hours(spread))"

        case .circadian:
            let time = clock(now, calendar)
            if now > reading.window.end {
                return "Il est \(time) — au-delà de ta fenêtre, qui s’est fermée à \(clock(reading.window.end, calendar))"
            }
            return "Il est \(time) — ton creux de milieu de journée"
        }
    }

    /// « 5 h 10 ». Jamais un decimal, jamais un pourcentage.
    private static func hours(_ interval: TimeInterval) -> String {
        let total = Int((interval / 60).rounded())
        let h = total / 60
        let m = total % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : String(format: "%d h %02d", h, m)
    }

    private static func clock(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%d h %02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}

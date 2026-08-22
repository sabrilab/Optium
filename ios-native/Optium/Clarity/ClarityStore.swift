import Foundation
import Observation
import SwiftData

/// Tient la lecture courante de la clarte, et la tient a jour.
///
/// Elle n'observe rien en continu : elle relit les sources a l'ouverture de
/// l'application et au retour au premier plan. C'est suffisant — une clarte
/// ne change pas d'une minute a l'autre — et cela evite tout travail en
/// arriere-plan.
@Observable
@MainActor
final class ClarityStore {
    private(set) var reading: ClarityReading
    private(set) var isRefreshing = false
    /// Faux tant que l'utilisateur n'a accorde aucune source.
    private(set) var hasPermission = false

    @ObservationIgnored private let source: any SleepSource
    @ObservationIgnored private let calendar: Calendar

    /// Combien de nuits en arriere l'indice de regularite est calcule.
    static let window = 28

    /// La source par defaut se construit *dans* l'initialiseur et non en
    /// valeur par defaut du parametre : le projet isole tout sur l'acteur
    /// principal, et une valeur par defaut s'evalue hors de lui.
    init(source: (any SleepSource)? = nil, calendar: Calendar = .current) {
        self.source = source ?? CompositeSleepSource()
        self.calendar = calendar
        self.reading = ClarityEngine.reading(nights: [], now: Date(), calendar: calendar)
    }

    func requestPermission() async {
        hasPermission = await source.requestAuthorization()
    }

    /// Relit les sources, conserve ce qui est nouveau, recalcule.
    func refresh(context: ModelContext, now: Date = Date()) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let horizon = calendar.date(byAdding: .day, value: -Self.window, to: now) ?? now
        let fetched = await source.nights(from: horizon, to: now)
        record(fetched, measured: true, context: context)

        let stored = (try? context.fetch(
            FetchDescriptor<RecordedNight>(
                predicate: #Predicate { $0.wokeAt >= horizon },
                sortBy: [SortDescriptor(\.asleepAt)]
            )
        )) ?? []

        let coffees = (try? context.fetch(
            FetchDescriptor<CoffeeIntake>(predicate: #Predicate { $0.takenAt >= horizon })
        )) ?? []

        reading = ClarityEngine.reading(
            nights: stored.map(\.night),
            now: now,
            coffees: coffees.map(\.takenAt),
            calendar: calendar
        )
    }

    /// Conserve les nuits inconnues. Une nuit deja enregistree n'est pas
    /// reecrite : la premiere lecture fait foi, et une source qui se contredit
    /// d'un jour a l'autre ne doit pas faire bouger l'historique.
    private func record(_ nights: [Night], measured: Bool, context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<RecordedNight>())) ?? []
        let known = Set(existing.map { calendar.startOfDay(for: $0.wokeAt) })

        for night in nights where !known.contains(calendar.startOfDay(for: night.wokeAt)) {
            context.insert(RecordedNight(night, measured: measured))
        }
    }
}

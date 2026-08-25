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

    /// Le modele du jour, garde pour reevaluer la clarte **sans relire les
    /// sources**.
    ///
    /// La valeur change en continu ; relancer `refresh` chaque minute
    /// interrogerait Sante et SwiftData pour recalculer deux exponentielles.
    /// Le modele et l'ancre du reveil suffisent — le reste est une fonction
    /// pure du temps.
    private(set) var vigilance: Vigilance?
    private(set) var wakeAnchor: Date?
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

    /// Le dernier niveau **effectivement montre**, sur lequel l'hysteresis
    /// s'ancre.
    ///
    /// Elle partait de `reading.level`, fige au dernier rafraichissement :
    /// entre deux lectures des sources, chaque evaluation repartait donc du
    /// meme point de reference, et une valeur qui derivait franchissait le
    /// seuil d'un coup au lieu d'etre retenue. L'hysteresis ne tenait que
    /// tant que rien ne bougeait.
    private var shownLevel: ClarityLevel?

    /// La clarte a un instant donne, calculee sans toucher aux sources.
    ///
    /// - Returns: `nil` tant qu'aucune mesure n'existe.
    func live(at date: Date) -> (value: Int, ceiling: Double, level: ClarityLevel)? {
        guard let vigilance, let wakeAnchor, reading.clarity != nil else { return nil }
        let awake = max(0, date.timeIntervalSince(wakeAnchor) / 3600)
        let value = Int(min(100, max(0, vigilance.clarity(hoursAwake: awake).rounded())))
        let level = ClarityLevel.level(value: value, previous: shownLevel ?? reading.level)
        return (value, vigilance.ceiling(hoursAwake: awake), level)
    }

    /// **Le niveau de l'instant, et la seule source de verite.**
    ///
    /// Quatre endroits lisaient encore `reading.level`, fige au dernier
    /// rafraichissement : la porte, `clarityAtStart` a chaque reprise, le pont
    /// des widgets et l'appel. Le scenario reel : le rebond du soir arrive, le
    /// cerveau se remplit a l'ecran, et la porte refuse toujours avec la
    /// valeur du matin.
    ///
    /// **Ce qui decide doit lire ce que l'utilisateur voit.**
    ///
    /// - Returns: `nil` tant qu'aucune mesure n'existe — la porte reste alors
    ///   fermee, un refus sans preuve etant pire qu'une absence de refus.
    func currentLevel(at date: Date = Date()) -> ClarityLevel? {
        guard reading.clarity != nil else { return nil }
        return live(at: date)?.level ?? reading.level
    }

    /// A appeler quand un niveau vient d'etre montre, pour que l'hysteresis
    /// s'ancre dessus.
    func noteShown(_ level: ClarityLevel) {
        shownLevel = level
    }

    /// Relit les sources, conserve ce qui est nouveau, recalcule.
    func refresh(context: ModelContext, now: Date = Date()) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let horizon = calendar.date(byAdding: .day, value: -Self.window, to: now) ?? now
        let fetched = await source.nights(from: horizon, to: now)
        record(fetched, context: context)

        let stored = (try? context.fetch(
            FetchDescriptor<RecordedNight>(
                predicate: #Predicate { $0.wokeAt >= horizon },
                sortBy: [SortDescriptor(\.asleepAt)]
            )
        )) ?? []

        let coffees = (try? context.fetch(
            FetchDescriptor<CoffeeIntake>(predicate: #Predicate { $0.takenAt >= horizon })
        )) ?? []

        // **Le niveau precedent est transmis, sinon l'hysteresis n'existe
        // pas.** Elle compare la nouvelle valeur a l'etat affiche juste avant ;
        // sans cette memoire, chaque lecture repartirait du seuil brut et la
        // porte clignoterait autour de 42 et de 70.
        reading = ClarityEngine.reading(
            nights: stored.map(\.night),
            now: now,
            coffees: coffees.map(\.takenAt),
            calendar: calendar,
            previousLevel: reading.clarity == nil ? nil : reading.level
        )

        vigilance = ClarityEngine.vigilance(nights: stored.map(\.night), calendar: calendar)
        wakeAnchor = now.addingTimeInterval(-reading.hoursAwake * 3600)
        // La lecture des sources fait autorite : elle repart du niveau qu'elle
        // vient d'etablir.
        shownLevel = reading.clarity == nil ? nil : reading.level
    }

    /// Conserve ce qui est nouveau, **et corrige ce qui etait faux**.
    ///
    /// La regle etait « la premiere lecture fait foi » : une nuit deja
    /// enregistree n'etait jamais reecrite. L'intention — qu'une source qui se
    /// contredit ne fasse pas bouger l'historique — etait juste, mais l'effet
    /// etait un piege. Une nuit lue de travers restait fausse pour toujours,
    /// et aucune correction dans Sante ne pouvait la rattraper.
    ///
    /// Deux cas remplacent desormais l'enregistrement existant :
    ///
    /// 1. **Une nuit mesuree remplace une nuit deduite.** Sante fait autorite
    ///    sur l'accelerometre, toujours, meme des jours plus tard — c'est le
    ///    cas de quelqu'un qui met sa montre apres coup.
    /// 2. **Une nuit mesuree en remplace une autre si elle differe.** Sante
    ///    revise ses donnees, et les nuits de la veille sont souvent
    ///    completees dans la journee.
    ///
    /// Une nuit deduite ne remplace jamais rien : le mouvement ne corrige pas
    /// la mesure.
    private func record(_ nights: [Night], context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<RecordedNight>())) ?? []
        var byDay: [Date: RecordedNight] = [:]
        for stored in existing {
            byDay[calendar.startOfDay(for: stored.wokeAt)] = stored
        }

        for night in nights {
            let day = calendar.startOfDay(for: night.wokeAt)
            guard let stored = byDay[day] else {
                context.insert(RecordedNight(night, measured: night.origin == .measured))
                continue
            }
            // **Une correction ne se fait jamais ecraser.** C'est ce qui la
            // rend utilisable : corriger une nuit puis la voir revenir a sa
            // valeur fausse au prochain rafraichissement decouragerait pour de
            // bon.
            guard !stored.corrected, night.origin == .measured else { continue }
            let unchanged = stored.measured
                && abs(stored.asleepAt.timeIntervalSince(night.asleepAt)) < 60
                && abs(stored.wokeAt.timeIntervalSince(night.wokeAt)) < 60
            guard !unchanged else { continue }

            stored.asleepAt = night.asleepAt
            stored.wokeAt = night.wokeAt
            stored.measured = true
        }
    }
}

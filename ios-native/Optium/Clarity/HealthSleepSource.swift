import Foundation
import HealthKit

/// Lit le sommeil enregistre par HealthKit.
///
/// Source principale quand elle a des donnees : une montre mesure le sommeil,
/// elle ne le devine pas. Mais elle n'en a que si l'utilisateur enregistre
/// effectivement ses nuits — sans montre, HealthKit est vide, et c'est
/// `MotionSleepSource` qui prend le relais.
struct HealthSleepSource: SleepSource {
    private static let store = HKHealthStore()

    private var type: HKCategoryType { HKCategoryType(.sleepAnalysis) }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await Self.store.requestAuthorization(toShare: [], read: [type])
            return true
        } catch {
            return false
        }
    }

    func nights(from start: Date, to end: Date) async -> [Night] {
        guard isAvailable else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, _ in
                continuation.resume(returning: results as? [HKCategorySample] ?? [])
            }
            Self.store.execute(query)
        }

        // Seul le sommeil compte. « Au lit » n'est pas dormir, et le retenir
        // gonflerait toutes les durees.
        //
        // **Les quatre stades sont lus pour une seule chose : etablir que la
        // personne dort. Leur identite n'est jamais exploitee, et ne doit
        // jamais l'etre.**
        //
        // Les validations 2024 contre polysomnographie donnent, pour les
        // montres grand public : sommeil contre eveil au-dessus de 95 % de
        // sensibilite, duree totale a plus ou moins douze minutes — mais
        // sommeil profond entre 50 et 64 % seulement. Calculer une « duree de
        // sommeil profond » reviendrait a batir sur la seule partie non
        // fiable de la mesure.
        //
        // Optium ne lit donc que `asleepAt` et `wokeAt` : la duree et les
        // horaires, c'est-a-dire precisement ce que ces appareils mesurent
        // bien.
        let asleep = samples.filter { sample in
            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified: true
            default: false
            }
        }
        guard !asleep.isEmpty else { return [] }

        // **Union des intervalles, jamais somme.** Une montre et un iPhone qui
        // enregistrent la meme nuit produisent deux jeux d'echantillons qui se
        // recouvrent ; les additionner doublerait la nuit. Fusionner leurs
        // intervalles donne le temps reellement endormi, quel que soit le
        // nombre de sources.
        let merged = Self.union(of: asleep.map { $0.startDate...$0.endDate })

        // **Une heure de trou separe deux episodes.** En deca, c'est un reveil
        // au milieu de la nuit ; au-dela, c'est une sieste ou une autre nuit.
        var episodes: [[ClosedRange<Date>]] = []
        var current: [ClosedRange<Date>] = []
        for interval in merged {
            if let last = current.last,
               interval.lowerBound.timeIntervalSince(last.upperBound) > 3600 {
                episodes.append(current)
                current = []
            }
            current.append(interval)
        }
        if !current.isEmpty { episodes.append(current) }

        let nights = episodes.compactMap { parts -> Night? in
            guard let first = parts.first, let last = parts.last else { return nil }
            // Le temps endormi est la somme des morceaux, pas leur amplitude :
            // les reveils intra-nuit ne comptent pas.
            let slept = parts.reduce(0.0) { $0 + $1.upperBound.timeIntervalSince($1.lowerBound) }
            guard slept >= SleepInference.minimumDuration else { return nil }
            return Night(
                asleepAt: first.lowerBound,
                wokeAt: last.upperBound,
                origin: .measured,
                measuredSleep: slept
            )
        }

        return Self.longestPerDay(nights)
    }

    /// Fusionne des intervalles qui se recouvrent ou se touchent.
    static func union(of ranges: [ClosedRange<Date>]) -> [ClosedRange<Date>] {
        let sorted = ranges.sorted { $0.lowerBound < $1.lowerBound }
        var result: [ClosedRange<Date>] = []
        for range in sorted {
            if let last = result.last, range.lowerBound <= last.upperBound {
                result[result.count - 1] = last.lowerBound...max(last.upperBound, range.upperBound)
            } else {
                result.append(range)
            }
        }
        return result
    }

    /// Au-dela de cet ecart a l'ancre, un episode appartient a une autre
    /// nuit — ou a une sieste.
    ///
    /// **Rattacher par proximite plutot que par un seuil fixe d'une heure
    /// d'eveil.** Le seuil frappait precisement les dormeurs fragmentes,
    /// c'est-a-dire le public que l'application sert le mieux. Trois heures
    /// laissent passer un reveil nocturne long sans admettre une sieste
    /// d'apres-midi, qui tombe huit a dix heures apres le lever.
    static let attachmentWindow: TimeInterval = 3 * 3600

    /// Une nuit par jour de lever. **L'episode le plus long donne l'horaire,
    /// tous les episodes rattachables donnent la duree.**
    ///
    /// Ne garder que le plus long amputait les cycles fragmentes : quelqu'un
    /// qui dort deux heures, se reveille deux heures, puis dort quatre heures
    /// etait credite de quatre heures. Les deux premieres etaient jetees.
    ///
    /// L'intention restait juste — une sieste ne doit pas devenir « la nuit »
    /// — mais elle confondait deux choses que `Night` distingue deja :
    ///
    /// - l'episode le plus long est **l'ancre** : il donne `asleepAt` et
    ///   `wokeAt`, donc l'horaire, donc la regularite ;
    /// - la duree **additionne** les episodes rattachables a la meme nuit.
    static func longestPerDay(_ nights: [Night], calendar: Calendar = .current) -> [Night] {
        var byDay: [Date: [Night]] = [:]
        for night in nights {
            byDay[calendar.startOfDay(for: night.wokeAt), default: []].append(night)
        }

        return byDay.values.compactMap { episodes -> Night? in
            guard let anchor = episodes.max(by: { $0.duration < $1.duration }) else { return nil }

            // Un episode se rattache s'il touche l'ancre de pres. Le test
            // porte sur l'ecart entre les deux intervalles, pas sur l'heure :
            // un dormeur decale n'a pas de raison d'etre traite autrement.
            let attached = episodes.filter { episode in
                if episode == anchor { return true }
                let after = episode.asleepAt.timeIntervalSince(anchor.wokeAt)
                let before = anchor.asleepAt.timeIntervalSince(episode.wokeAt)
                return (after >= 0 && after <= attachmentWindow)
                    || (before >= 0 && before <= attachmentWindow)
            }

            let slept = attached.reduce(0.0) { $0 + $1.duration }
            // Les bornes couvrent tout ce qui est rattache : c'est l'amplitude
            // reelle de la nuit, et c'est elle qui situe le sommeil dans la
            // journee pour l'indice de regularite.
            let first = attached.map(\.asleepAt).min() ?? anchor.asleepAt
            let last = attached.map(\.wokeAt).max() ?? anchor.wokeAt

            return Night(
                asleepAt: first,
                wokeAt: last,
                origin: .measured,
                measuredSleep: slept
            )
        }.sorted { $0.asleepAt < $1.asleepAt }
    }
}

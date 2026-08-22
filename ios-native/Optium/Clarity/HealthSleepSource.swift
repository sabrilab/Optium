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

    /// Une nuit par jour de lever : **la plus longue**.
    ///
    /// Une sieste de l'apres-midi remonte de Sante comme un episode a part
    /// entiere. Sans ce tri, elle devenait « la nuit » du jour ou elle tombait
    /// — et c'est exactement ce qui faisait afficher des nuits qui n'en
    /// etaient pas.
    static func longestPerDay(_ nights: [Night], calendar: Calendar = .current) -> [Night] {
        var best: [Date: Night] = [:]
        for night in nights {
            let day = calendar.startOfDay(for: night.wokeAt)
            if let existing = best[day], existing.duration >= night.duration { continue }
            best[day] = night
        }
        return best.values.sorted { $0.asleepAt < $1.asleepAt }
    }
}

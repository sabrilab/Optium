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

        // Une nuit arrive en dizaines d'echantillons : on recolle ceux qui se
        // suivent a moins d'une heure.
        var nights: [Night] = []
        var currentStart = asleep[0].startDate
        var currentEnd = asleep[0].endDate

        for sample in asleep.dropFirst() {
            if sample.startDate.timeIntervalSince(currentEnd) <= 3600 {
                currentEnd = max(currentEnd, sample.endDate)
            } else {
                nights.append(Night(asleepAt: currentStart, wokeAt: currentEnd))
                currentStart = sample.startDate
                currentEnd = sample.endDate
            }
        }
        nights.append(Night(asleepAt: currentStart, wokeAt: currentEnd))

        return nights.filter { $0.duration >= SleepInference.minimumDuration }
    }
}

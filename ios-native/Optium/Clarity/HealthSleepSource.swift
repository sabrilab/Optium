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

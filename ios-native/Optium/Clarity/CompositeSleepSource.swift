import Foundation

/// HealthKit d'abord, le mouvement en repli.
///
/// L'ordre n'est pas negociable : une montre mesure le sommeil, le telephone
/// le devine. Mais HealthKit est vide pour qui n'enregistre pas ses nuits, et
/// dans ce cas le repli n'est pas un pis-aller — c'est la seule source.
///
/// Les deux se completent aussi dans le temps : une nuit sans montre au
/// poignet laisse un trou que le mouvement peut combler.
struct CompositeSleepSource: SleepSource {
    var health: any SleepSource = HealthSleepSource()
    var motion: any SleepSource = MotionSleepSource()

    var isAvailable: Bool { health.isAvailable || motion.isAvailable }

    func requestAuthorization() async -> Bool {
        async let healthGranted = health.requestAuthorization()
        async let motionGranted = motion.requestAuthorization()
        let (healthOK, motionOK) = await (healthGranted, motionGranted)
        return healthOK || motionOK
    }

    func nights(from start: Date, to end: Date) async -> [Night] {
        let measured = await health.nights(from: start, to: end)
        let inferred = await motion.nights(from: start, to: end)

        // Le mouvement ne comble que les nuits absentes du mesure : il ne le
        // corrige jamais.
        let covered = Set(measured.map { Calendar.current.startOfDay(for: $0.wokeAt) })
        let gaps = inferred.filter { !covered.contains(Calendar.current.startOfDay(for: $0.wokeAt)) }

        return (measured + gaps).sorted { $0.asleepAt < $1.asleepAt }
    }
}

import CoreMotion
import Foundation

/// Deduit les nuits du mouvement du telephone.
///
/// C'est la source de repli, et souvent la seule : sans montre, le sommeil
/// n'est enregistre nulle part.
///
/// **Elle ne tourne pas en arriere-plan.** iOS suspend l'application des
/// qu'elle quitte le premier plan, et « observer l'usage du telephone » ne
/// fait pas partie des modes d'arriere-plan autorises. On interroge donc
/// l'**historique** que CoreMotion conserve — sept jours — au moment ou
/// l'application s'ouvre. Le resultat est le meme, sans consommer de batterie.
///
/// Precision de l'ordre de vingt a trente minutes, ce qui suffit : l'indice de
/// regularite mesure la constance, pas l'heure exacte. Une erreur systematique
/// ne le deplace pas.
///
/// **Limite a dire a l'utilisateur** : le telephone doit passer la nuit pres
/// de lui. Charge dans une autre piece, il n'y a pas de signal — et
/// `SleepInference` ecarte les immobilites invraisemblables plutot que de les
/// lire comme des nuits parfaites.
struct MotionSleepSource: SleepSource {
    /// Une nuit ne se decoupe pas a la minute : on fusionne les segments
    /// immobiles separes par moins de dix minutes d'activite.
    private static let stitch: TimeInterval = 600

    var isAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        // CoreMotion n'a pas de demande explicite : la premiere interrogation
        // declenche l'invite systeme, et echoue si elle est refusee.
        let probe = await stillPeriods(from: Date().addingTimeInterval(-3600), to: Date())
        return probe != nil
    }

    func nights(from start: Date, to end: Date) async -> [Night] {
        // CoreMotion ne garde que sept jours.
        let floor = max(start, Date().addingTimeInterval(-7 * 86_400))
        guard let periods = await stillPeriods(from: floor, to: end) else { return [] }
        return SleepInference.nights(fromStillPeriods: periods, calendar: .current)
    }

    /// - Returns: `nil` si CoreMotion refuse de repondre — permission non
    ///   accordee, ou materiel absent. A distinguer d'un tableau vide, qui
    ///   veut dire « aucune immobilite trouvee ».
    private func stillPeriods(from start: Date, to end: Date) async -> [DateInterval]? {
        guard isAvailable else { return nil }
        let manager = CMMotionActivityManager()

        let activities: [CMMotionActivity]? = await withCheckedContinuation { continuation in
            manager.queryActivityStarting(from: start, to: end, to: .main) { result, _ in
                continuation.resume(returning: result)
            }
        }
        guard let activities else { return nil }

        var periods: [DateInterval] = []
        var runStart: Date?

        for (index, activity) in activities.enumerated() {
            let still = activity.stationary && activity.confidence != .low
            let next = index + 1 < activities.count ? activities[index + 1].startDate : end

            if still {
                if runStart == nil { runStart = activity.startDate }
            } else if let began = runStart {
                periods.append(DateInterval(start: began, end: activity.startDate))
                runStart = nil
            }
            if index == activities.count - 1, let began = runStart {
                periods.append(DateInterval(start: began, end: next))
            }
        }

        return stitched(periods)
    }

    /// Recolle les segments separes par un bref sursaut : se retourner dans son
    /// lit interrompt l'immobilite sans interrompre la nuit.
    private func stitched(_ periods: [DateInterval]) -> [DateInterval] {
        let sorted = periods.sorted { $0.start < $1.start }
        var merged: [DateInterval] = []
        for period in sorted {
            if let last = merged.last, period.start.timeIntervalSince(last.end) <= Self.stitch {
                merged[merged.count - 1] = DateInterval(start: last.start, end: period.end)
            } else {
                merged.append(period)
            }
        }
        return merged
    }
}

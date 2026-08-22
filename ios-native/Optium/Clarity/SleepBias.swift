import Foundation

/// Ce que les corrections apprennent a l'application.
///
/// **C'est la partie « comprendre de mieux en mieux ».** Corriger une nuit
/// repare cette nuit-la ; corriger vingt nuits dans le meme sens dit autre
/// chose — que la source se trompe **systematiquement**, et de combien.
///
/// Le cas typique : une montre date le lever d'un reveil bref a 5 h alors que
/// le vrai lever est a 6 h 40. L'ecart n'est pas aleatoire, il se repete.
///
/// **Le biais n'est jamais applique en silence.** Il est calcule, montre, et
/// l'utilisateur decide. Une correction automatique invisible fabriquerait des
/// nuits que personne n'a mesurees ni validees — exactement ce que le moteur
/// s'interdit en rendant la clarte optionnelle plutot qu'en inventant une
/// valeur par defaut.
enum SleepBias {
    /// En deca, un ecart repete n'est pas distinguable de quelques accidents.
    static let minimumCorrections = 4

    struct Estimate: Equatable {
        /// Decalage median du lever, en secondes. Positif : le vrai lever est
        /// **plus tard** que ce que la source annoncait.
        let wakeShift: TimeInterval
        /// Decalage median du coucher.
        let sleepShift: TimeInterval
        let sampleCount: Int

        /// Vrai si l'ecart merite d'etre signale. En deca de dix minutes, il
        /// est du meme ordre que l'imprecision de la mesure elle-meme —
        /// environ douze minutes contre polysomnographie.
        var isMeaningful: Bool { abs(wakeShift) >= 10 * 60 || abs(sleepShift) >= 10 * 60 }
    }

    /// - Parameter corrections: `(annonce, corrige)` pour le lever et le coucher.
    static func estimate(from nights: [RecordedNight]) -> Estimate? {
        var wakeDeltas = [TimeInterval](), sleepDeltas = [TimeInterval]()

        for night in nights where night.corrected {
            if let original = night.originalWokeAt {
                wakeDeltas.append(night.wokeAt.timeIntervalSince(original))
            }
            if let original = night.originalAsleepAt {
                sleepDeltas.append(night.asleepAt.timeIntervalSince(original))
            }
        }

        guard wakeDeltas.count >= minimumCorrections
           || sleepDeltas.count >= minimumCorrections else { return nil }

        return Estimate(
            wakeShift: median(wakeDeltas),
            sleepShift: median(sleepDeltas),
            sampleCount: max(wakeDeltas.count, sleepDeltas.count)
        )
    }

    /// La mediane, et non la moyenne : une seule correction aberrante — une
    /// nuit oubliee puis rattrapee de six heures — deplacerait une moyenne
    /// pour toujours.
    static func median(_ values: [TimeInterval]) -> TimeInterval {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}

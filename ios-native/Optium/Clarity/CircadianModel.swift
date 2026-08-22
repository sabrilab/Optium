import Foundation

/// Le modele a deux processus de Borbely, reduit a ce dont l'application a
/// besoin.
///
/// Deux forces se composent : une pression homeostatique qui monte avec le
/// temps passe eveille, et un rythme circadien qui oscille sur vingt-quatre
/// heures. Leur difference donne la vigilance disponible — d'ou le creux du
/// milieu d'apres-midi, que ni l'un ni l'autre n'explique seul.
///
/// **C'est la composante la moins etablie des trois, et son poids le dit** :
/// 0,2 contre 0,5 pour la regularite. L'effet de synchronie — mieux performer
/// a l'heure qui correspond a son chronotype — est largement admis, mais
/// dispute : *Collabra: Psychology* (2023) conclut a l'absence de gain
/// cognitif general et robuste issu du croisement heure du jour x chronotype,
/// et evoque un possible artefact methodologique.
///
/// **Le chronotype est appris de l'heure de lever reelle, jamais suppose.**
/// Il decale la courbe d'une a trois heures, et supposer un lever a sept
/// heures pour quelqu'un qui se leve a dix rendrait toute la mesure fausse.
struct CircadianModel {
    let habitualWake: Date
    var calendar: Calendar = .current

    /// Heure decimale du lever habituel, dans la journee.
    private var wakeHour: Double {
        let parts = calendar.dateComponents([.hour, .minute], from: habitualWake)
        return Double(parts.hour ?? 7) + Double(parts.minute ?? 0) / 60
    }

    /// 0…100 a l'instant donne.
    func score(at date: Date) -> Double {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60

        // Heures depuis le lever, ramenees dans les vingt-quatre heures.
        var awake = hour - wakeHour
        if awake < 0 { awake += 24 }

        // Processus S : la pression monte de facon saturante avec l'eveil.
        let pressure = 1 - exp(-awake / 12.0)

        // Processus C : oscillation calee sur le lever. Le pic tombe environ
        // trois heures apres, le creux environ huit.
        let phase = (awake - 3) / 24 * 2 * .pi
        let rhythm = cos(phase)

        // La vigilance est ce que le rythme laisse une fois la pression payee.
        let raw = 0.62 * rhythm - 0.85 * pressure + 0.5
        return min(100, max(0, raw * 100))
    }

    /// La fenetre du jour : le creneau ou une decision tient.
    ///
    /// Elle s'ouvre deux heures apres le lever — le temps que l'inertie du
    /// reveil se dissipe — et dure deux heures quarante.
    func window(on day: Date) -> DateInterval {
        let start = calendar.startOfDay(for: day)
            .addingTimeInterval((wakeHour + 2) * 3600)
        return DateInterval(start: start, duration: 2.67 * 3600)
    }
}

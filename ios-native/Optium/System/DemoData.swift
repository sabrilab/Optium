#if DEBUG
import Foundation
import SwiftData

/// Un jeu de donnees dense, pour regarder les ecrans.
///
/// **Il n'existe qu'en DEBUG et ne se declenche que sur `-demo`.** Aucun
/// chemin de l'application publiee ne peut l'atteindre : le fichier entier
/// disparait de la compilation en Release.
///
/// Il existe parce qu'une bonne partie de l'interface ne se montre qu'avec un
/// historique — la carte de palier demande vingt nuits, la calibration deux
/// reponses, les preuves des fils fermes. Sans lui, verifier une decision de
/// design revient a la juger sur des ecrans vides, ce qui revient a ne pas la
/// verifier.
enum DemoData {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo")
    }

    static func seed(into context: ModelContext) {
        // Idempotent : relancer l'application ne doit pas empiler les jeux.
        guard (try? context.fetch(FetchDescriptor<RecordedNight>()))?.isEmpty ?? false else { return }

        let calendar = Calendar.current
        let now = Date()

        // Quarante nuits d'un dormeur regulier mais imparfait : coucher autour
        // de 23 h 15 avec une derive de quelques dizaines de minutes, nuits de
        // sept heures et demie. De quoi atteindre un palier eleve sans le
        // rendre parfait.
        for offset in 1...40 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let drift = Double((offset * 37) % 50 - 25) / 60.0
            let asleep = calendar.startOfDay(for: day).addingTimeInterval((23.25 + drift) * 3600)
            let hours = 7.5 + Double((offset * 17) % 40 - 20) / 60.0
            context.insert(RecordedNight(
                Night(asleepAt: asleep, wokeAt: asleep.addingTimeInterval(hours * 3600)),
                measured: true
            ))
        }

        for offset in [0, 1, 2, 4, 5] {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            context.insert(CoffeeIntake(takenAt: calendar.startOfDay(for: day).addingTimeInterval(8.5 * 3600)))
        }

        // Les deux sens de l'ecart, et des accords : la carte de calibration
        // n'a d'interet que si les trois colonnes portent un nombre.
        let answers: [(Int, Bool, ClarityLevel)] = [
            (1, true, .high), (2, true, .low), (3, false, .high), (5, true, .high),
            (6, true, .low), (8, false, .low), (9, true, .high), (11, true, .low),
            (13, false, .high), (15, true, .high),
        ]
        for (offset, felt, measured) in answers {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            context.insert(Calibration(
                askedAt: calendar.startOfDay(for: day).addingTimeInterval(10 * 3600),
                feltClear: felt, measured: measured
            ))
        }

        let project = Project(title: "Refonte tarifaire", openedAt: now.addingTimeInterval(-30 * 86_400))
        context.insert(project)

        let closed: [(String, ThreadNature, Int, String?)] = [
            ("Choisir le palier d’entrée", .decision, 1, "J’accepte de trancher sans l’avis de Marc."),
            ("Rédiger la page de comparaison", .production, 2, nil),
            ("Comprendre pourquoi le churn monte", .mechanical, 3, nil),
            ("Arrêter l’offre annuelle", .decision, 5, "J’accepte de perdre les six clients concernés."),
            ("Reprendre le calcul de marge", .production, 6, nil),
            ("Décider du nom", .decision, 9, "J’accepte que ce ne soit pas unanime."),
            ("Cartographier les objections", .mechanical, 12, nil),
        ]
        for (phrase, nature, offset, acceptance) in closed {
            let created = now.addingTimeInterval(Double(-offset) * 86_400 - 6 * 3600)
            let thread = WorkThread(phrase: phrase, nature: nature, createdAt: created)
            thread.project = project
            context.insert(thread)
            let end = created.addingTimeInterval(5 * 3600)
            if let acceptance {
                _ = thread.closeThroughGate(acceptance: acceptance, at: end)
            } else {
                thread.close(at: end)
            }
            let resumption = Resumption(
                startedAt: created.addingTimeInterval(1800),
                clarityAtStart: offset.isMultiple(of: 2) ? .high : .medium,
                inWindow: offset % 3 != 0
            )
            resumption.endedAt = end
            resumption.thread = thread
            context.insert(resumption)
        }

        for (phrase, nature, inProject) in [
            ("Trancher le positionnement de l’offre pro", ThreadNature.decision, true),
            ("Écrire la note de cadrage", ThreadNature.production, true),
            // Un fil hors projet : le groupage doit montrer les deux cas.
            ("Rappeler le comptable", ThreadNature.mechanical, false),
        ] {
            let thread = WorkThread(phrase: phrase, nature: nature, createdAt: now.addingTimeInterval(-7200))
            if inProject { thread.project = project }
            context.insert(thread)
        }

        try? context.save()
    }
}
#endif

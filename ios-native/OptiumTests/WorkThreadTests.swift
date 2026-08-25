import Foundation
import SwiftData
import Testing

@testable import Optium

@MainActor
private func makeContext() throws -> ModelContext {
    let schema = Schema([Project.self, WorkThread.self, Resumption.self])
    let container = try ModelContainer(
        for: schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
}

private let now = Date(timeIntervalSince1970: 1_760_000_000)

@MainActor
private func makeThread(_ nature: ThreadNature, in context: ModelContext) -> WorkThread {
    let thread = WorkThread(phrase: "Choisir le modèle de tarification", nature: nature, createdAt: now)
    context.insert(thread)
    return thread
}

// ── La porte : la condition de declenchement ──
//
// C'est la regle centrale du produit. Elle doit se declencher pour un cas et
// un seul, et sa rarete est ce qui la rend acceptable : chaque test qui
// l'elargirait doit etre refuse.

@MainActor
@Test func laPorteSOuvrePourUneDecisionAClarteBasse() throws {
    let context = try makeContext()
    let thread = makeThread(.decision, in: context)

    #expect(thread.closingOutcome(clarity: .low) == .gate)
}

@MainActor
@Test func laPorteResteFermeePourUneDecisionAClarteSuffisante() throws {
    let context = try makeContext()
    let thread = makeThread(.decision, in: context)

    #expect(thread.closingOutcome(clarity: .medium) == .direct)
    #expect(thread.closingOutcome(clarity: .high) == .direct)
}

@MainActor
@Test func laPorteNeSOuvreJamaisHorsDUneDecision() throws {
    let context = try makeContext()

    // Meme a clarte basse : produire ou executer du mecanique ne se valide pas.
    #expect(makeThread(.production, in: context).closingOutcome(clarity: .low) == .direct)
    #expect(makeThread(.mechanical, in: context).closingOutcome(clarity: .low) == .direct)
}

// ── Les transitions ──

@MainActor
@Test func unFilNaitOuvert() throws {
    let context = try makeContext()
    let thread = makeThread(.decision, in: context)

    #expect(thread.state == .open)
    #expect(thread.closedAt == nil)
    #expect(thread.resumptions.isEmpty)
}

@MainActor
@Test func demarrerUneRepriseMetLeFilEnCours() throws {
    let context = try makeContext()
    let thread = makeThread(.production, in: context)

    thread.startResumption(clarity: .high, inWindow: true, at: now)

    #expect(thread.state == .inProgress)
    #expect(thread.resumptions.count == 1)
    #expect(thread.currentResumption?.endedAt == nil)
}

@MainActor
@Test func laRepriseEnregistreLaClarteDuMomentEtLaFenetre() throws {
    let context = try makeContext()
    let thread = makeThread(.production, in: context)

    thread.startResumption(clarity: .low, inWindow: false, at: now)

    let resumption = try #require(thread.currentResumption)
    #expect(resumption.clarityAtStart == .low)
    #expect(resumption.inWindow == false)
}

@MainActor
@Test func mettreEnPauseRouvreLeFilSansLeFermer() throws {
    let context = try makeContext()
    let thread = makeThread(.production, in: context)

    thread.startResumption(clarity: .high, inWindow: true, at: now)
    thread.pause(at: now.addingTimeInterval(1800))

    #expect(thread.state == .open)
    #expect(thread.currentResumption == nil)
    #expect(thread.resumptions.count == 1)
    #expect(thread.resumptions[0].endedAt == now.addingTimeInterval(1800))
}

@MainActor
@Test func demarrerDeuxFoisNeCreeQuUneRepriseOuverte() throws {
    let context = try makeContext()
    let thread = makeThread(.production, in: context)

    thread.startResumption(clarity: .high, inWindow: true, at: now)
    thread.startResumption(clarity: .high, inWindow: true, at: now.addingTimeInterval(60))

    // Une reprise deja ouverte n'est pas doublee : l'ecran de reprise peut
    // reapparaitre sans consequence.
    #expect(thread.resumptions.count == 1)
}

// ── Fermeture ──

@MainActor
@Test func fermerDirectementClotLeFilEtSaReprise() throws {
    let context = try makeContext()
    let thread = makeThread(.production, in: context)
    thread.startResumption(clarity: .high, inWindow: true, at: now)

    thread.close(at: now.addingTimeInterval(3600))

    #expect(thread.state == .closed)
    #expect(thread.closedAt == now.addingTimeInterval(3600))
    #expect(thread.resumptions[0].endedAt == now.addingTimeInterval(3600))
}

@MainActor
@Test func fermerParLaPorteExigeUneLigneEcrite() throws {
    let context = try makeContext()
    let thread = makeThread(.decision, in: context)

    #expect(thread.closeThroughGate(acceptance: "   ", at: now) == false)
    #expect(thread.state == .open)
    #expect(thread.acceptance == nil)
}

@MainActor
@Test func laLigneEcriteEstConserveeTelleQuelle() throws {
    let context = try makeContext()
    let thread = makeThread(.decision, in: context)

    let accepted = thread.closeThroughGate(
        acceptance: "  J'accepte la version courte parce que le reste peut attendre.  ",
        at: now
    )

    #expect(accepted == true)
    #expect(thread.state == .closed)
    #expect(thread.acceptance == "J'accepte la version courte parce que le reste peut attendre.")
}

// ── Retenue ──

@MainActor
@Test func retenirNeFermePasEtNoteLEcheance() throws {
    let context = try makeContext()
    let thread = makeThread(.decision, in: context)
    thread.startResumption(clarity: .low, inWindow: false, at: now)

    let tomorrow = now.addingTimeInterval(9 * 3600)
    thread.hold(until: tomorrow, at: now)

    #expect(thread.state == .held)
    #expect(thread.heldUntil == tomorrow)
    #expect(thread.closedAt == nil)
    // La reprise en cours se termine : on ne travaille plus dessus.
    #expect(thread.resumptions[0].endedAt == now)
}

@MainActor
@Test func unFilRetenuSeLibereALEcheance() throws {
    let context = try makeContext()
    let thread = makeThread(.decision, in: context)
    thread.hold(until: now.addingTimeInterval(3600), at: now)

    thread.releaseIfDue(now: now.addingTimeInterval(3601))

    #expect(thread.state == .open)
    #expect(thread.heldUntil == nil)
}

@MainActor
@Test func unFilRetenuNeSeLiberePasAvant() throws {
    let context = try makeContext()
    let thread = makeThread(.decision, in: context)
    thread.hold(until: now.addingTimeInterval(3600), at: now)

    thread.releaseIfDue(now: now.addingTimeInterval(3599))

    #expect(thread.state == .held)
}

@MainActor
@Test func liberer_unFilNonRetenuNeChangeRien() throws {
    let context = try makeContext()
    let thread = makeThread(.production, in: context)
    thread.startResumption(clarity: .high, inWindow: true, at: now)

    thread.releaseIfDue(now: now.addingTimeInterval(99_999))

    #expect(thread.state == .inProgress)
}

// ── Le bilan de fermeture ──

@MainActor
@Test func leBilanCompteLesReprisesEtCellesDansLaFenetre() throws {
    let context = try makeContext()
    let thread = makeThread(.production, in: context)

    thread.startResumption(clarity: .high, inWindow: true, at: now)
    thread.pause(at: now.addingTimeInterval(1800))
    thread.startResumption(clarity: .medium, inWindow: false, at: now.addingTimeInterval(7200))
    thread.pause(at: now.addingTimeInterval(9000))
    thread.startResumption(clarity: .high, inWindow: true, at: now.addingTimeInterval(20_000))
    thread.close(at: now.addingTimeInterval(23_000))

    let summary = thread.summary(calendar: .gregorianParis)
    #expect(summary.resumptionCount == 3)
    #expect(summary.inWindowCount == 2)
}

@MainActor
@Test func leBilanCompteLesNuitsTraversees() throws {
    let context = try makeContext()
    let thread = makeThread(.decision, in: context)

    // Ouvert un jour, ferme le surlendemain : deux nuits.
    thread.close(at: now.addingTimeInterval(2 * 86_400))

    #expect(thread.summary(calendar: .gregorianParis).nightsCrossed == 2)
}

@MainActor
@Test func unFilOuvertEtFermeDansLaJourneeNeTraverseAucuneNuit() throws {
    let context = try makeContext()
    let thread = makeThread(.production, in: context)

    thread.close(at: now.addingTimeInterval(3600))

    #expect(thread.summary(calendar: .gregorianParis).nightsCrossed == 0)
}

@MainActor
@Test func leBilanCompteLesRetenues() throws {
    let context = try makeContext()
    let thread = makeThread(.decision, in: context)

    thread.hold(until: now.addingTimeInterval(3600), at: now)
    thread.releaseIfDue(now: now.addingTimeInterval(3601))
    thread.hold(until: now.addingTimeInterval(7200), at: now.addingTimeInterval(3601))
    thread.releaseIfDue(now: now.addingTimeInterval(7201))
    _ = thread.closeThroughGate(acceptance: "Va pour la version courte.", at: now.addingTimeInterval(7300))

    #expect(thread.summary(calendar: .gregorianParis).holdCount == 2)
}

// ── Cascade ──

@MainActor
@Test func supprimerUnProjetSupprimeSesFilsEtLeursReprises() throws {
    let context = try makeContext()
    let project = Project(title: "Refonte", openedAt: now)
    context.insert(project)
    let thread = WorkThread(phrase: "Maquettes", nature: .production, createdAt: now)
    project.threads.append(thread)
    thread.startResumption(clarity: .high, inWindow: true, at: now)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Resumption>()) == 1)

    context.delete(project)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<WorkThread>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Resumption>()) == 0)
}

/// Calendrier fixe : les comptes de nuits dependent du fuseau, et un test qui
/// suit le fuseau de la machine echoue selon l'endroit ou il tourne.
extension Calendar {
    static var gregorianParis: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }
}

// ── Le temps deja passe sur un fil ──
//
// Le chronometre repartait de zero a chaque reprise : rouvrir un fil
// travaille pendant des heures affichait « 00:12 », comme si rien n'avait ete
// fait. Un fil se mesure sur sa vie entiere, pas sur la session courante.

@MainActor
@Test func leTotalCumuleLesReprisesFermees() {
    let thread = WorkThread(phrase: "Trancher le positionnement", nature: .decision)
    let base = Date().addingTimeInterval(-6 * 3600)

    for offset in 0..<3 {
        let resumption = Resumption(
            startedAt: base.addingTimeInterval(Double(offset) * 3600),
            clarityAtStart: .medium,
            inWindow: false
        )
        resumption.endedAt = resumption.startedAt.addingTimeInterval(1800)
        thread.resumptions.append(resumption)
    }

    // Trois reprises d'une demi-heure : une heure trente.
    #expect(abs(thread.summary().totalDuration - 1.5 * 3600) < 5)
}

@MainActor
@Test func laRepriseEnCoursCompteDansLeTotal() {
    let thread = WorkThread(phrase: "Écrire la note", nature: .production)

    let done = Resumption(startedAt: Date().addingTimeInterval(-7200),
                          clarityAtStart: .high, inWindow: true)
    done.endedAt = done.startedAt.addingTimeInterval(3600)
    thread.resumptions.append(done)

    thread.resumptions.append(Resumption(
        startedAt: Date().addingTimeInterval(-600), clarityAtStart: .medium, inWindow: false))

    // Une heure fermee, dix minutes en cours.
    #expect(thread.summary().totalDuration > 3600)
    #expect(thread.summary().totalDuration < 3600 + 700)
}

@MainActor
@Test func unFilSansRepriseNAPasDeTemps() {
    let thread = WorkThread(phrase: "Rappeler le comptable", nature: .mechanical)
    #expect(thread.summary().totalDuration == 0)
}

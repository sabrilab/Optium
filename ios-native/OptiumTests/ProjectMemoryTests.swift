import Foundation
import Testing

@testable import Optium

// ── La memoire se relit ──
//
// Elle a passe un temps en ecriture seule : une ligne s'ecrivait a chaque fil
// ferme, et l'appel passait une chaine vide au modele. Le fichier grossissait
// sans que personne ne l'ouvre. Ces tests fixent l'aller-retour.

private func freshMemory() -> ProjectMemory {
    let memory = ProjectMemory(projectTitle: "Test \(UUID().uuidString)")
    try? FileManager.default.removeItem(at: memory.url)
    return memory
}

@Test func uneMemoireVideSeLitSansEchouer() {
    #expect(freshMemory().read().isEmpty)
}

@Test func ceQuiEstEcritSeRelit() {
    let memory = freshMemory()
    memory.append("« Choisir le palier » — 3 reprises")

    #expect(memory.read().contains("Choisir le palier"))
    try? FileManager.default.removeItem(at: memory.url)
}

@Test func laMemoireSAccumuleEtNEcrasePas() {
    let memory = freshMemory()
    memory.append("première")
    memory.append("deuxième")
    memory.append("troisième")

    let text = memory.read()
    #expect(text.contains("première"))
    #expect(text.contains("deuxième"))
    #expect(text.contains("troisième"))
    // Les lignes de faits commencent par un tiret ; l'en-tete n'en est pas une.
    #expect(text.split(separator: "\n").filter { $0.hasPrefix("- ") }.count == 3)
    try? FileManager.default.removeItem(at: memory.url)
}

@Test func deuxProjetsNePartagentPasLeurMemoire() {
    let a = ProjectMemory(projectTitle: "Refonte tarifaire")
    let b = ProjectMemory(projectTitle: "Refonte éditoriale")
    #expect(a.slug != b.slug)
}

@Test func leSlugSurvitALaCasseEtAuxAccents() {
    // Le fichier est indexe sur le titre : deux graphies du meme projet ne
    // doivent pas ouvrir deux memoires.
    #expect(ProjectMemory(projectTitle: "Refonte Tarifaire").slug
         == ProjectMemory(projectTitle: "refonte tarifaire").slug)
}

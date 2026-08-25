import Foundation
import Testing

@testable import Optium

// ── La justesse de l'application, pas celle de l'utilisateur ──
//
// La calibration mesurait l'ecart entre ce que la personne ressent et ce qui
// est mesure — implicitement, sa justesse a elle. Personne ne mesurait celle du
// produit. On retourne la mesure.

private func record(_ daysAgo: Int, felt: Bool, measured: ClarityLevel) -> CalibrationRecord {
    CalibrationRecord(
        askedAt: Date().addingTimeInterval(-Double(daysAgo) * 86_400),
        feltClear: felt,
        measured: measured
    )
}

@Test func sousCinqCalibrationsAucunVerdict() {
    let few = (0..<4).map { record($0, felt: true, measured: .high) }
    #expect(OwnAccuracy.verdict(from: few) == nil)
}

@Test func lAccordEstCompteQuandLaMesureEstFranche() throws {
    let agreeing = (0..<6).map { record($0, felt: true, measured: .high) }
    let verdict = try #require(OwnAccuracy.verdict(from: agreeing))

    #expect(verdict.agreed == 6)
    #expect(verdict.disagreed == 0)
    #expect(verdict.rate == 1)
}

@Test func uneMesureMoyenneNeCompteNiPourNiContre() {
    // La compter d'un cote ou de l'autre gonflerait artificiellement le taux.
    let neutral = (0..<8).map { record($0, felt: true, measured: .medium) }
    #expect(OwnAccuracy.verdict(from: neutral) == nil)
}

@Test func unMauvaisResultatSAfficheQuandMeme() throws {
    // **C'est ce qui rend l'application verifiable au lieu d'etre crue sur
    // parole.** Une application qui masquerait son taux d'erreur ne vaudrait
    // pas la peine d'etre mesuree.
    let wrong = (0..<6).map { record($0, felt: true, measured: .low) }
    let verdict = try #require(OwnAccuracy.verdict(from: wrong))

    #expect(verdict.rate == 0)
    #expect(!verdict.sentence.isEmpty)
    #expect(verdict.sentence.lowercased().contains("trompé"))
}

@Test func laPhraseNeSExcuseNiNeSeVante() throws {
    for measured in [ClarityLevel.high, .low] {
        let records = (0..<6).map { record($0, felt: true, measured: measured) }
        let verdict = try #require(OwnAccuracy.verdict(from: records))
        let text = verdict.sentence.lowercased()

        for banned in ["désolé", "pardon", "excellent", "bravo", "parfait", "améliore"] {
            #expect(!text.contains(banned), "« \(banned) » dans : \(text)")
        }
    }
}

@Test func lesCalibrationsTropAnciennesSontIgnorees() {
    // Trente jours : au-dela, le moteur a change et le verdict porterait sur
    // une version qui n'existe plus.
    let old = (0..<8).map { record(40 + $0, felt: true, measured: .high) }
    #expect(OwnAccuracy.verdict(from: old) == nil)
}

@Test func leTauxMelangeLesDeuxSens() throws {
    let mixed = (0..<4).map { record($0, felt: true, measured: .high) }
             + (0..<4).map { record($0 + 4, felt: true, measured: .low) }
    let verdict = try #require(OwnAccuracy.verdict(from: mixed))

    #expect(verdict.agreed == 4)
    #expect(verdict.disagreed == 4)
    #expect(abs(verdict.rate - 0.5) < 0.01)
}

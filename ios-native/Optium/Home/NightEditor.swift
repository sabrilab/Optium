import SwiftData
import SwiftUI

/// Corriger une nuit.
///
/// **L'application ne demande jamais, elle accepte d'etre corrigee.** Elle
/// n'ouvre pas cet ecran d'elle-meme, ne relance sur rien, ne signale pas les
/// nuits « a verifier ». C'est ce qui la distingue d'un journal de sommeil :
/// la saisie reste possible, elle n'est jamais attendue.
///
/// Ce qui est corrige devient definitif — aucune relecture de Sante ne
/// l'ecrase. Sans cette garantie, corriger une nuit puis la voir revenir a sa
/// valeur fausse decouragerait pour de bon.
struct NightEditor: View {
    let night: RecordedNight

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ClarityStore.self) private var clarityStore
    @Environment(ActionLog.self) private var actions

    @State private var asleepAt = Date()
    @State private var wokeAt = Date()

    private var duration: TimeInterval { wokeAt.timeIntervalSince(asleepAt) }
    private var isValid: Bool { duration >= 3600 && duration <= 20 * 3600 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text(night.wokeAt.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.system(size: 22, weight: .light))

                    field("ENDORMI À", selection: $asleepAt)
                    field("RÉVEILLÉ À", selection: $wokeAt)

                    HStack {
                        Text("Durée")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(isValid ? readable(duration) : "—")
                            .font(.system(size: 20, weight: .medium))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }

                    source

                    if night.corrected {
                        Button("Revenir à la mesure d’origine") { revert() }
                            .font(.subheadline)
                            .foregroundStyle(Ink.marker)
                            .frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .background(InkBackground())
            .navigationTitle("Corriger la nuit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }.tint(Ink.control)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button { save() } label: {
                    Text("Enregistrer")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.glass)
                .tint(Ink.control)
                .disabled(!isValid)
                .padding(.horizontal, 22)
                .padding(.bottom, 10)
            }
            .onAppear {
                asleepAt = night.asleepAt
                wokeAt = night.wokeAt
            }
        }
    }

    private func field(_ label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary)
            DatePicker("", selection: selection)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Ink.marker)
        }
    }

    /// D'ou vient ce qu'on est en train de corriger.
    private var source: some View {
        Text(sourceSentence)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sourceSentence: String {
        if night.corrected {
            guard let original = night.originalWokeAt else { return "Corrigée à la main." }
            return "Corrigée à la main. Santé annonçait un réveil à \(Clock.hhmm(original))."
        }
        return night.measured
            ? "Lue dans Santé. Ta correction fera autorité : aucune relecture ne l’écrasera."
            : "Déduite du mouvement du téléphone. Ta correction fera autorité."
    }

    private func save() {
        guard isValid else { return }
        // L'original n'est conserve qu'a la premiere correction : sans cela,
        // corriger deux fois effacerait la mesure de depart, et l'ecart appris
        // ne voudrait plus rien dire.
        if !night.corrected {
            night.originalAsleepAt = night.asleepAt
            night.originalWokeAt = night.wokeAt
        }
        night.asleepAt = asleepAt
        night.wokeAt = wokeAt
        night.corrected = true

        Feedback.play(.threadClosed)
        actions.record("Nuit corrigée")
        Task { await clarityStore.refresh(context: context) }
        dismiss()
    }

    private func revert() {
        guard let asleep = night.originalAsleepAt, let woke = night.originalWokeAt else { return }
        night.asleepAt = asleep
        night.wokeAt = woke
        night.corrected = false
        night.originalAsleepAt = nil
        night.originalWokeAt = nil

        Feedback.play(.held)
        actions.record("Correction annulée")
        Task { await clarityStore.refresh(context: context) }
        dismiss()
    }

    private func readable(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded())
        return minutes % 60 == 0
            ? "\(minutes / 60) h"
            : String(format: "%d h %02d", minutes / 60, minutes % 60)
    }
}

import SwiftData
import SwiftUI

/// La première phrase.
///
/// Le seul texte que l'utilisateur écrit dans une journée. **Aucune durée à
/// choisir** — c'est tout le point du produit : on ne s'engage pas sur un
/// temps, on ouvre une intention.
struct ThreadComposer: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var phrase = ""
    @State private var nature: ThreadNature = .production
    @FocusState private var writing: Bool

    private var trimmed: String { phrase.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("SUR QUOI ?")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.6)
                        .foregroundStyle(.secondary)

                    TextField("", text: $phrase, axis: .vertical)
                        .font(.system(size: 21, weight: .light))
                        .lineLimit(2...5)
                        .focused($writing)
                        .overlay(alignment: .topLeading) {
                            if phrase.isEmpty {
                                Text("Une phrase.")
                                    .font(.system(size: 21, weight: .light))
                                    .foregroundStyle(.tertiary)
                                    .allowsHitTesting(false)
                            }
                        }

                    Text("Elle te sera remontrée à la fermeture du fil, telle quelle.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("NATURE")
                            .font(.caption2.weight(.semibold))
                            .tracking(1.6)
                            .foregroundStyle(.secondary)

                        ForEach(ThreadNature.allCases, id: \.self) { option in
                            natureRow(option)
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .background(InkBackground())
            .navigationTitle("Nouveau fil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }.tint(Ink.control)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    open()
                } label: {
                    Text("Ouvrir le fil")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.glass)
                .tint(Ink.control)
                .disabled(trimmed.isEmpty)
                .padding(.horizontal, 22)
                .padding(.bottom, 10)
            }
            .onAppear { writing = true }
        }
    }

    private func natureRow(_ option: ThreadNature) -> some View {
        Button {
            nature = option
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: nature == option ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(nature == option ? Ink.marker : Color.white.opacity(0.3))
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.word)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(option.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func open() {
        guard !trimmed.isEmpty else { return }
        context.insert(WorkThread(phrase: trimmed, nature: nature))
        dismiss()
    }
}

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

    @Query(sort: \Project.openedAt, order: .reverse) private var projects: [Project]

    @State private var phrase = ""
    @State private var nature: ThreadNature = .production
    @State private var project: Project?
    @State private var newProjectTitle = ""
    @State private var namingProject = false
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

                    projectSection

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

    /// Le projet est facultatif. Un fil peut vivre seul — l'imposer
    /// obligerait à ranger avant de penser, ce qui est exactement l'inverse
    /// de « une phrase, et on ouvre ».
    @ViewBuilder
    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROJET")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary)

            Menu {
                Button("Aucun") { project = nil }
                ForEach(projects) { candidate in
                    Button(candidate.title) { project = candidate }
                }
                Divider()
                Button("Nouveau projet…") { namingProject = true }
            } label: {
                HStack {
                    Text(project?.title ?? "Aucun")
                        .font(.subheadline)
                        .foregroundStyle(project == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(minHeight: 44)
            }
            .tint(Ink.control)
        }
        .alert("Nouveau projet", isPresented: $namingProject) {
            TextField("Nom", text: $newProjectTitle)
            Button("Annuler", role: .cancel) { newProjectTitle = "" }
            Button("Créer") { createProject() }
        }
    }

    private func createProject() {
        let trimmed = newProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let created = Project(title: trimmed, colorIndex: projects.count % Ink.cardHues.count)
        context.insert(created)
        project = created
        newProjectTitle = ""
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
        Feedback.play(.threadOpened)
        let thread = WorkThread(phrase: trimmed, nature: nature)
        context.insert(thread)
        project?.threads.append(thread)
        dismiss()
    }
}

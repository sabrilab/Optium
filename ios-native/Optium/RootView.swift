import SwiftUI

enum RootTab: Hashable {
    case session, projects, stats
}

struct RootView: View {
    /// Suivi de l'onglet actif : la scene 3D s'en sert pour suspendre son rendu
    /// des qu'elle n'est plus visible.
    @State private var selection: RootTab = .session

    var body: some View {
        TabView(selection: $selection) {
            Tab("Session", systemImage: "brain", value: RootTab.session) {
                SessionScreen(selectedTab: selection)
            }
            Tab("Projets", systemImage: "folder", value: RootTab.projects) {
                ProjectsScreen()
            }
            Tab("Statistiques", systemImage: "chart.bar", value: RootTab.stats) {
                StatsScreen()
            }
        }
    }
}

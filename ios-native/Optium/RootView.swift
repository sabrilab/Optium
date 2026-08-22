import SwiftUI

enum RootTab: Hashable {
    case home, journal
}

struct RootView: View {
    @State private var selection: RootTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("Aujourd’hui", systemImage: "brain", value: RootTab.home) {
                HomeScreen(isVisible: selection == .home)
            }
            Tab("Journal", systemImage: "text.line.first.and.arrowtriangle.forward", value: RootTab.journal) {
                JournalScreen()
            }
        }
        // L'application ne suit pas l'apparence d'iOS : le noir est un choix de
        // direction artistique, et la scene comme les lavis n'existent que sur
        // lui.
        .preferredColorScheme(.dark)
        .tint(Ink.control)
    }
}

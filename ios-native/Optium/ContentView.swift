import SwiftUI

/// Vue d'attente : le portage remplace ce fichier par le TabView racine.
struct ContentView: View {
    var body: some View {
        ContentUnavailableView(
            "Optium",
            systemImage: "brain",
            description: Text("Le portage natif commence ici.")
        )
    }
}

#Preview {
    ContentView()
}

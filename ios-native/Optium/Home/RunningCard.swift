import SwiftUI

/// La première carte de l'accueil : ouvrir un fil, ou celui qui tourne.
///
/// **Le même emplacement, deux états.** C'est le modèle du lecteur de
/// musique : ce qui joue reste visible en haut, et se rouvre d'un geste. Une
/// reprise en cours était jusqu'ici invisible depuis l'accueil — il fallait
/// retrouver le fil dans la liste et le rouvrir, alors que c'est la seule
/// chose de l'application qui se passe *maintenant*.
///
/// **Elle est en tête et ne bouge jamais.** Une carte qui apparaît au milieu
/// d'une liste déplace tout ce qui la suit ; en tête, l'écran reste stable
/// qu'un fil tourne ou non — et c'est ce qui permet de la reconnaître sans la
/// chercher.
struct RunningCard: View {
    /// Le fil dont une reprise est en cours, ou `nil`.
    let running: WorkThread?
    /// Le dernier fil travaille aujourd'hui, quand rien ne tourne.
    ///
    /// **Une pause ne fait pas disparaitre le lecteur.** La carte se retirait
    /// des qu'on arretait la reprise et redevenait « Ouvrir un fil » : le fil
    /// sur lequel on venait de travailler disparaissait de l'ecran, et il
    /// fallait le retrouver dans la liste pour le reprendre. Un lecteur de
    /// musique en pause garde sa barre.
    var paused: WorkThread?
    let onOpen: () -> Void
    let onCompose: () -> Void
    /// Arreter la reprise sans ouvrir le fil.
    var onPause: (WorkThread) -> Void = { _ in }

    var body: some View {
        if let running {
            Button(action: onOpen) {
                content(running, isRunning: true)
            }
            .buttonStyle(Pressable())
        } else if let paused {
            Button(action: onOpen) {
                content(paused, isRunning: false)
            }
            .buttonStyle(Pressable())
        } else {
            Button(action: onCompose) {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Ouvrir un fil")
                        .font(.subheadline.weight(.medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Ink.control)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                // **La forme tactile avant le verre, et pas apres.**
                //
                // Un `Spacer` n'est pas une surface : sans `contentShape`, la
                // zone touchable s'arretait au texte et les trois quarts
                // droits de la carte ne repondaient a rien. Le verre
                // `.interactive()` n'arrangeait rien — il reagit au doigt sans
                // le transmettre.
                .contentShape(.rect(cornerRadius: 30))
                .glassEffect(.regular, in: .rect(cornerRadius: 30))
            }
            .buttonStyle(.plain)
        }
    }

    private func content(_ thread: WorkThread, isRunning: Bool) -> some View {
        // **Deux colonnes, pas trois lignes.** La carte empilait l'état, la
        // phrase et le compteur : elle faisait la hauteur d'une carte de
        // mesure alors qu'elle ne porte qu'une chose en train de se passer.
        // Le compteur à droite la ramène à deux lignes.
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    // Le seul endroit de l'application où quelque chose est
                    // annoncé comme *en train* de se passer. En pause, le
                    // marker s'éteint : il ne signale que le présent.
                    Image(systemName: isRunning ? "waveform" : "pause.fill")
                        .font(.caption2)
                        .foregroundStyle(isRunning ? Ink.marker : .secondary)
                    Text(isRunning ? "EN COURS" : "EN PAUSE")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.6)
                        .foregroundStyle(isRunning ? Ink.marker : .secondary)
                    if thread.nature == .decision {
                        Text("· \(thread.nature.word.uppercased())")
                            .font(.caption2.weight(.semibold))
                            .tracking(1.4)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                Text(thread.phrase)
                    .font(.system(size: 18, weight: .light))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }

            // Le temps du fil entier, pas de la session : un fil se mesure sur
            // sa vie, jamais sur la reprise courante.
            //
            // En matrice de points, comme dans l'écran du fil : c'est le même
            // compteur, et il doit se reconnaître d'un écran à l'autre.
            // En pause, le compteur est fige : rien ne court, donc rien ne
            // doit compter.
            TimelineView(.periodic(from: .now, by: isRunning ? 1 : 3600)) { context in
                DotMatrixText(
                    text: elapsed(thread, at: context.date),
                    // Un cran plus petit : a 3,4 le compteur pesait autant
                    // que la phrase, alors qu'il l'accompagne.
                    dot: 2.6,
                    gap: 1.6,
                    glow: Ink.focusGlow
                )
            }
            .fixedSize()

            // **La pause, sans ouvrir le fil.** Elle passe par le meme chemin
            // que celle de l'ecran — `ThreadRunner.pause` — donc les deux ne
            // peuvent pas diverger.
            //
            // Le bouton est hors du `Button` de la carte : imbriquer deux
            // boutons rend le plus interne inatteignable sur iOS.
            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Ink.control)
                .frame(width: 40, height: 40)
                .contentShape(.circle)
                .glassEffect(.regular, in: .circle)
                // Reprendre ouvre le fil : c'est l'ecran du fil qui demarre
                // une reprise, et le faire ici la demarrerait deux fois.
                .onTapGesture { isRunning ? onPause(thread) : onOpen() }
                .accessibilityLabel(isRunning ? "Mettre en pause" : "Reprendre")
                .accessibilityAddTraits(.isButton)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        // En pause, la carte s'assourdit sans changer de teinte : la
        // hierarchie se fait par la valeur, jamais par la couleur.
        .bentoSurface(Ink.violet, corner: 28, intensity: isRunning ? 0.55 : 0.3)
    }

    /// Le temps total du fil, au format de l'île dynamique.
    private func elapsed(_ thread: WorkThread, at date: Date) -> String {
        let closed = thread.resumptions
            .filter { $0.endedAt != nil }
            .reduce(0.0) { $0 + $1.duration }
        let running = thread.currentResumption
            .map { date.timeIntervalSince($0.startedAt) } ?? 0
        let seconds = max(0, Int(closed + running))

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        guard hours > 0 else { return String(format: "%d:%02d", minutes, seconds % 60) }
        return String(format: "%d:%02d:%02d", hours, minutes, seconds % 60)
    }

}

import AVFoundation

/// Les deux sons de l'application.
///
/// **Deux, et ils sont synthetises.** Aucun fichier audio n'est embarque :
/// une sinusoide avec enveloppe se calcule en quelques lignes, pese zero
/// octet, et surtout se regle — un fichier fige demanderait un aller-retour
/// dans un editeur pour changer une hauteur.
///
/// **La session est en `.ambient`**, et c'est la decision qui compte. Elle
/// laisse la musique de l'utilisateur jouer et **respecte l'interrupteur
/// silencieux**. Une application de travail qui coupe un podcast pour annoncer
/// qu'un fil est ferme se fait desinstaller le jour meme.
///
/// Le son est coupe par defaut. Le tactile suffit a la plupart des gestes ; le
/// son n'ajoute quelque chose que dans les deux moments ou l'on ne regarde
/// peut-etre pas l'ecran.
@MainActor
enum Chime {
    /// Renseigne depuis `RootView`.
    static var isEnabled = false

    enum Tone {
        /// Un fil se ferme. Une quinte montante : ca se termine vers le haut.
        case closed
        /// La porte s'ouvre. Deux notes graves qui descendent, tres douces.
        case gate
    }

    static func play(_ tone: Tone) {
        guard isEnabled else { return }
        switch tone {
        case .closed: render(notes: [(587.33, 0, 0.20), (880.00, 0.10, 0.34)], gain: 0.16)
        case .gate:   render(notes: [(261.63, 0, 0.42), (196.00, 0.16, 0.60)], gain: 0.13)
        }
    }

    // ── Details ──

    private static let engine = AVAudioEngine()
    private static let player = AVAudioPlayerNode()
    private static let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    private static var started = false

    private static func startIfNeeded() -> Bool {
        if started { return true }
        // `.ambient` : on se melange, on n'interrompt pas, et le silencieux
        // nous coupe. `.mixWithOthers` est implicite dans cette categorie mais
        // on l'ecrit pour que l'intention reste lisible.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        guard (try? engine.start()) != nil else { return false }
        player.play()
        started = true
        return true
    }

    /// - Parameter notes: `(hauteur en Hz, debut en secondes, duree)`.
    private static func render(notes: [(Double, Double, Double)], gain: Double) {
        guard startIfNeeded() else { return }

        let rate = format.sampleRate
        let total = notes.map { $0.1 + $0.2 }.max() ?? 0
        let frames = AVAudioFrameCount(total * rate)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames

        for index in 0..<Int(frames) { samples[index] = 0 }

        for (hertz, start, duration) in notes {
            let first = Int(start * rate)
            let count = Int(duration * rate)
            for offset in 0..<count where first + offset < Int(frames) {
                let time = Double(offset) / rate
                // Attaque rapide, extinction exponentielle : sans enveloppe, le
                // debut et la fin claquent, et un clic s'entend bien plus qu'un
                // son.
                let attack = min(1, time / 0.006)
                let decay = exp(-time / (duration * 0.34))
                // Une seule harmonique, discrete : la sinusoide pure sonne
                // synthetique, deux partiels suffisent a lui donner un corps.
                let wave = sin(2 * .pi * hertz * time)
                         + 0.18 * sin(4 * .pi * hertz * time)
                samples[first + offset] += Float(wave * attack * decay * gain)
            }
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
    }
}

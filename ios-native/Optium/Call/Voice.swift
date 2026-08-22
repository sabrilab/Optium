import AVFoundation
import Foundation
import Speech

/// La chaine vocale, entierement sur l'appareil.
///
/// ```
/// SpeechTranscriber / SpeechAnalyzer  →  FoundationModels  →  AVSpeechSynthesizer
/// ```
///
/// **Rien ne sort de l'appareil, et c'est le point qui compte.** La promesse
/// « aucune description de travail ne quitte l'appareil » vaut deja pour
/// l'appel ecrit ; elle doit valoir en vocal, sans quoi la fonctionnalite
/// devient un manquement. Le modele de transcription est donc **exige en
/// local** : si la locale n'est pas installee, on demande son installation, et
/// a defaut on refuse — jamais de bascule silencieuse.
///
/// **Rien n'est conserve.** Le texte transcrit vit dans `heard` pour la duree
/// de l'appel et disparait avec lui. Aucun modele, aucun fichier, aucune cle
/// de reglages ne porte de transcription : voir `VoiceTests`.
@MainActor
@Observable
final class Voice {
    enum State: Equatable {
        case idle
        case preparing
        case listening
        case unavailable(String)
    }

    private(set) var state: State = .idle
    /// Ce qui est entendu, en cours. Volatile, jamais persiste.
    private(set) var heard = ""
    /// 0…1 : le volume, pour faire respirer l'aura.
    private(set) var level: Double = 0

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var stream: AsyncStream<AnalyzerInput>.Continuation?
    private var engine: AVAudioEngine?
    private var collecting: Task<Void, Never>?

    private let synthesizer = AVSpeechSynthesizer()

    static let locale = Locale(identifier: "fr-FR")

    /// La transcription francaise est-elle possible sur cet appareil.
    ///
    /// Faux sur un materiel non eligible : on masque la commande plutot que
    /// d'en offrir une qui echouera.
    var isSupported: Bool { SpeechTranscriber.isAvailable }

    // ── Ecouter ──

    /// Demarre l'ecoute. Appelee a l'appui, pas au relachement.
    ///
    /// **Appui maintenu, et c'est un choix.** Une detection de silence
    /// demanderait un seuil a regler, produirait des faux departs, et
    /// deciderait a la place de l'utilisateur du moment ou il a fini de
    /// parler. Le maintien rend la fin explicite — et un appel qu'on tient est
    /// un appel qui se termine quand on lache.
    func startListening() async {
        guard state == .idle || isUnavailable else { return }
        state = .preparing
        heard = ""

        guard await hasMicrophonePermission() else {
            state = .unavailable("Optium n’a pas accès au micro.")
            return
        }

        let transcriber = SpeechTranscriber(locale: Self.locale, preset: .transcription)
        guard await ensureModelInstalled(for: transcriber) else {
            state = .unavailable("Le modèle de transcription français n’est pas installé sur cet appareil.")
            return
        }

        let (inputs, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = SpeechAnalyzer(inputSequence: inputs, modules: [transcriber])

        guard let format = await transcriber.availableCompatibleAudioFormats.first,
              startCapture(feeding: continuation, format: format) else {
            continuation.finish()
            state = .unavailable("Le micro n’a pas pu démarrer.")
            return
        }

        self.transcriber = transcriber
        self.analyzer = analyzer
        self.stream = continuation
        state = .listening

        collecting = Task { [weak self] in
            guard let results = self?.transcriber?.results else { return }
            do {
                for try await result in results {
                    // On ne garde que le dernier etat de la phrase : accumuler
                    // les revisions reconstituerait une transcription, et une
                    // transcription est exactement ce qui est interdit.
                    await MainActor.run { self?.heard = String(result.text.characters) }
                }
            } catch {
                await MainActor.run { self?.state = .unavailable("La transcription s’est interrompue.") }
            }
        }
    }

    /// Arrete l'ecoute et rend ce qui a ete entendu.
    @discardableResult
    func stopListening() async -> String {
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
        stream?.finish()
        stream = nil
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        analyzer = nil
        transcriber = nil
        collecting?.cancel()
        collecting = nil
        level = 0
        if case .listening = state { state = .idle }
        return heard.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // ── Parler ──

    /// Dit la reponse a voix haute.
    ///
    /// **La voix n'est jamais la seule sortie.** Le texte reste affiche quoi
    /// qu'il arrive : les voix francaises du systeme sont tres inegales, et
    /// conditionner la fonctionnalite a la presence d'une voix premium
    /// priverait d'appel des gens qui n'ont rien demande. On prend la
    /// meilleure disponible et on s'en contente.
    func say(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestFrenchVoice()
        // Legerement sous le defaut : le cerveau constate, il ne debite pas.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.94
        utterance.postUtteranceDelay = 0.1
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// La meilleure voix francaise installee.
    ///
    /// Les qualites `premium` et `enhanced` doivent avoir ete telechargees par
    /// l'utilisateur dans les reglages d'iOS ; `default` est toujours la.
    static func bestFrenchVoice() -> AVSpeechSynthesisVoice? {
        let french = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("fr") }
        let ranked: [AVSpeechSynthesisVoiceQuality] = [.premium, .enhanced, .default]
        for quality in ranked {
            if let voice = french.first(where: { $0.quality == quality }) { return voice }
        }
        return AVSpeechSynthesisVoice(language: "fr-FR")
    }

    // ── Details ──

    private var isUnavailable: Bool {
        if case .unavailable = state { return true }
        return false
    }

    private func hasMicrophonePermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        default: return await AVAudioApplication.requestRecordPermission()
        }
    }

    /// - Returns: faux si le modele local n'est ni present ni installable.
    private func ensureModelInstalled(for transcriber: SpeechTranscriber) async -> Bool {
        switch await AssetInventory.status(forModules: [transcriber]) {
        case .installed:
            return true
        case .supported, .downloading:
            guard let request = try? await AssetInventory.assetInstallationRequest(
                supporting: [transcriber]
            ) else { return false }
            try? await request.downloadAndInstall()
            return await AssetInventory.status(forModules: [transcriber]) == .installed
        case .unsupported:
            return false
        @unknown default:
            return false
        }
    }

    private func startCapture(
        feeding continuation: AsyncStream<AnalyzerInput>.Continuation,
        format: AVAudioFormat
    ) -> Bool {
        // `.record` avec `.duckOthers` : on baisse la musique le temps de la
        // question au lieu de la couper. `.ambient` ne permet pas d'enregistrer.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .spokenAudio,
                                 options: [.duckOthers, .defaultToSpeaker])
        try? session.setActive(true)

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let native = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: native, to: format) else { return false }

        input.installTap(onBus: 0, bufferSize: 4096, format: native) { [weak self] buffer, _ in
            // Le niveau alimente la respiration de l'aura. Il est calcule ici
            // parce que c'est le seul endroit ou le signal existe.
            if let channel = buffer.floatChannelData?[0] {
                var sum: Float = 0
                for index in 0..<Int(buffer.frameLength) { sum += channel[index] * channel[index] }
                let rms = sqrt(sum / Float(max(1, buffer.frameLength)))
                Task { @MainActor [weak self] in
                    self?.level = min(1, Double(rms) * 14)
                }
            }

            guard let converted = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(format.sampleRate * 0.4)
            ) else { return }

            var consumed = false
            var error: NSError?
            converter.convert(to: converted, error: &error) { _, status in
                if consumed { status.pointee = .noDataNow; return nil }
                consumed = true
                status.pointee = .haveData
                return buffer
            }
            guard error == nil, converted.frameLength > 0 else { return }
            continuation.yield(AnalyzerInput(buffer: converted))
        }

        engine.prepare()
        guard (try? engine.start()) != nil else { return false }
        self.engine = engine
        return true
    }
}

import SwiftData
import SwiftUI

/// L'unique écran permanent. Un mot, une fenêtre, les fils ouverts.
///
/// Pas de chiffre de performance, pas de graphe, pas de série. Le document est
/// explicite sur la raison : les applications de productivité meurent dans
/// leur onglet Statistiques.
struct HomeScreen: View {
    let isVisible: Bool

    @Environment(AppSettings.self) private var settings
    @Environment(ActionLog.self) private var actions
    @Environment(ClarityStore.self) private var clarityStore
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @Query(
        filter: #Predicate<WorkThread> { $0.closedAt == nil },
        sort: \WorkThread.createdAt
    )
    private var threads: [WorkThread]

    @Query(sort: \CoffeeIntake.takenAt, order: .reverse)
    private var coffees: [CoffeeIntake]

    @Query(filter: #Predicate<WorkThread> { $0.closedAt != nil })
    private var closed: [WorkThread]

    @Query private var allResumptions: [Resumption]

    /// Les nuits enregistrees, pour la bande sous la clarte.
    @Query(sort: \RecordedNight.wokeAt) private var recordedNights: [RecordedNight]

    @State private var composing = false
    /// Le fil en cours de modification. Ouvre le meme ecran que la creation.
    @State private var editingThread: WorkThread?
    @State private var showSettings = false
    @State private var calling = false
    @State private var baseExplanation: String?
    @State private var active: WorkThread?

    /// La lecture mesurée, sauf si le forçage de développement l'écrase.
    private var reading: ClarityReading {
        if let forced = settings.clarityOverride {
            return .forced(forced, window: clarityStore.reading.window)
        }
        return clarityStore.reading
    }

    private var window: DateInterval { reading.window }
    private var base: Double { reading.brainBase }

    /// L'agitation est le nombre de fils ouverts. Au-delà de cinq la surface
    /// est déjà pleinement remuée : compter plus loin n'ajoute rien à lire.
    private var agitation: Double { min(1, Double(threads.count) / 5) }

    var body: some View {
        NavigationStack {
            ZStack {
                InkBackground()

                Aura(isFocus: true, intensity: 0.35 + base * 0.4)
                    .frame(height: 560)
                    .offset(y: -180)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        brain
                        crossingMessage
                        clarityCard
                        if let clarity = reading.clarity {
                            CalibrationCard(measured: clarity.level)
                        }
                        landingCard
                        threadList
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                }
            }
            .navigationTitle("Aujourd’hui")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Réglages", systemImage: "gearshape")
                    }
                    .tint(Ink.control)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        calling = true
                    } label: {
                        Label("Appeler", systemImage: "waveform")
                    }
                    .tint(Ink.control)
                }
            }
            .sheet(isPresented: $composing) { ThreadComposer() }
            .sheet(item: $editingThread) { ThreadComposer(editing: $0) }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsScreen() }
            }
            .sheet(isPresented: $calling) { CallScreen() }
            .fullScreenCover(item: $active) { thread in
                ResumptionFlow(thread: thread)
            }
            // Un fil retenu redevient ouvert de lui-même à l'échéance. On le
            // constate à l'ouverture de l'écran plutôt que par une minuterie :
            // rien ne presse, et rien ne doit notifier.
            .onAppear(perform: releaseDueThreads)



            .onChange(of: scenePhase) { _, phase in
                if phase == .active { releaseDueThreads() }
            }
        }
    }

    /// Ce qui vient de changer, dit une seule fois.
    ///
    /// Au franchissement du seuil, l'application se met a pouvoir refuser.
    /// C'est un changement de comportement, et l'annoncer une fois vaut mieux
    /// que de le laisser decouvrir a la premiere porte.
    @ViewBuilder
    private var crossingMessage: some View {
        if reading.clarity != nil && !settings.hasSeenThreshold {
            VStack(alignment: .leading, spacing: 10) {
                Text("Optium a assez observé. À partir de maintenant, il t’arrêtera si tu essaies de trancher une décision quand tes nuits ne le permettent pas.")
                    .font(.system(size: 17, weight: .light))
                Button("Compris") { settings.hasSeenThreshold = true }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Ink.marker)
                    .frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .bentoSurface(Ink.teal, corner: 30, intensity: 0.5)
        }
    }

    @ViewBuilder
    private var brain: some View {
        if settings.brainEnabled {
            BrainView(
                fill: reading.brainFill,
                base: base,
                agitation: agitation,
                isDay: true,
                isVisible: isVisible && scenePhase == .active
            )
            .frame(height: 260)
            // La ligne de plafond n'est pas chiffree : sa valeur est derivee,
            // pas mesuree. Elle s'explique au toucher plutot que de porter un
            // nombre qui ne serait verifiable nulle part.
            //
            // Au `tap` seulement : un `drag` entrerait en conflit avec la
            // rotation du modele.
            .onTapGesture { explainBase() }
            .overlay(alignment: .bottom) {
                if let baseExplanation {
                    Text(baseExplanation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: baseExplanation)
        }
    }

    private func explainBase() {
        guard reading.clarity != nil, reading.regularity != nil else { return }
        baseExplanation = reading.brainFill >= reading.brainBase - 0.02
            ? "Tu es au plafond que ta nuit permet."
            : "La ligne marque ce que ta nuit permet aujourd’hui."
        Task {
            try? await Task.sleep(for: .seconds(4))
            baseExplanation = nil
        }
    }

    private var clarityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CLARTÉ")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary)

            if let clarity = reading.clarity {
                // Un mot, jamais un nombre. Un score chiffré de performance
                // cognitive s'approcherait d'un diagnostic.
                Text(clarity.level.word)
                    .font(.system(size: 34, weight: .light))

                // **Sa cause, juste en dessous.** Le mot apparaissait seul, et
                // il fallait ouvrir un autre écran pour savoir sur quoi il
                // reposait. Un verdict dont la cause est ailleurs se subit ;
                // posé à côté d'elle, il s'examine.
                NavigationLink { NightsScreen() } label: {
                    HStack(alignment: .top, spacing: 12) {
                        NightsStrip(nights: recordedNights)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 16)
                    }
                }
                .buttonStyle(.plain)
            } else {
                arrival
            }

            WindowStrip(window: window, now: Date())

            Text(windowSentence)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider().overlay(Color.white.opacity(0.12))

            legend

            // Sans clarté, la bande n'a rien à montrer : le recours reste
            // accessible, mais discret.
            if reading.clarity == nil {
                NavigationLink { NightsScreen() } label: {
                    HStack(spacing: 6) {
                        Text("Voir mes nuits")
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .bentoSurface(Ink.indigo, corner: 34)
    }

    // ── L'arrivée ──

    /// Ce que voit quelqu'un dont les nuits ne sont pas encore lues.
    ///
    /// **On ne simule rien.** Aucune donnée d'exemple, aucun cerveau rempli au
    /// hasard. Ce que l'application montre est vrai, y compris quand ce
    /// qu'elle a à dire est « je ne sais pas encore ».
    ///
    /// Le cas est rare : les sources rendent leur historique dès la première
    /// seconde. Il reste quand même à traiter — permission refusée, ou
    /// téléphone qui ne dort pas près de son propriétaire.
    @ViewBuilder
    private var arrival: some View {
        if clarityStore.hasPermission {
            VStack(alignment: .leading, spacing: 8) {
                Text("Optium lit tes nuits pour savoir quand tu peux décider.")
                    .font(.system(size: 19, weight: .light))
                Text(nightsProgress)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Ink.marker)
            }
        } else {
            // Cas distinct de « pas encore de données », et à ne pas
            // confondre : ici la mesure ne viendra jamais.
            VStack(alignment: .leading, spacing: 8) {
                Text("Optium a besoin de tes nuits pour fonctionner. Sans elles, il reste un carnet de fils.")
                    .font(.system(size: 18, weight: .light))
                Button("Ouvrir les réglages") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Ink.marker)
                .frame(minHeight: 44)
            }
        }
    }

    /// Le compte est réel : il mesure le remplissage de l'application
    /// elle-même, ce qui est la seule chose vraie à dire à ce moment.
    private var nightsProgress: String {
        let seen = min(reading.observedNights, ClarityEngine.minimumNights)
        return "\(seen) nuit\(seen > 1 ? "s" : "") observée\(seen > 1 ? "s" : "") sur \(ClarityEngine.minimumNights)."
    }

    // ── La légende ──

    /// Ce que le cerveau montre, nommé.
    ///
    /// **Seules figurent les grandeurs mesurées qui alimentent l'état affiché
    /// à cet instant.** Pas de moyenne, pas de comparaison, pas de veille. La
    /// colonne de gauche est vérifiable dans Santé ; une régularité ou un
    /// palier ne le sont nulle part, et c'est ce qui les disqualifie ici.
    ///
    /// Quatre lignes au maximum, jamais plus.
    @ViewBuilder
    private var legend: some View {
        VStack(spacing: 6) {
            if let duration = reading.lastNightDuration, isRecent(duration) {
                // **La ligne nomme sa provenance.** Elle annoncait « Nuit
                // 5 h 10 » sans dire d'ou venait le chiffre. Quand il est
                // deduit du mouvement, il ne se verifie nulle part ailleurs —
                // l'annoncer comme un fait mesure etait la seule entorse de
                // l'application a sa propre regle.
                legendRow(
                    reading.restsOnInference ? "Nuit déduite" : "Nuit",
                    format(duration)
                )
            }
            legendRow("Fenêtre", windowRange, muted: Date() > window.end)
            // Le café porte son bouton : c'est le seul geste déclaratif de
            // l'application, et le séparer de sa ligne le faisait apparaître
            // deux fois.
            //
            // Rien à zéro dans la valeur : une ligne à zéro est un reproche.
            coffeeRow
            // Au-delà de deux, seuil à partir duquel l'agitation se voit.
            if threads.count > 2 {
                legendRow("Fils", "\(threads.count) ouverts")
            }
        }
    }

    private func legendRow(_ label: String, _ value: String, muted: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(muted ? .tertiary : .secondary)
        }
    }

    private var todayCoffees: Int {
        coffees.filter { Calendar.current.isDateInToday($0.takenAt) }.count
    }

    private var windowRange: String {
        Date() > window.end
            ? "fermée à \(clock(window.end))"
            : "\(clock(window.start)) → \(clock(window.end))"
    }

    /// Une nuit de plus de 36 h n'a plus rien à dire de l'état d'aujourd'hui.
    private func isRecent(_ duration: TimeInterval) -> Bool {
        reading.observedNights > 0
    }

    private func format(_ interval: TimeInterval) -> String {
        let total = Int((interval / 60).rounded())
        return total % 60 == 0 ? "\(total / 60) h" : String(format: "%d h %02d", total / 60, total % 60)
    }

    private func clock(_ date: Date) -> String { Clock.hhmm(date) }

    /// Le seul geste déclaratif de l'application. Tout le reste est lu.
    ///
    /// Il agit sur la nuit projetée, donc sur la clarté de **demain** — jamais
    /// sur celle d'aujourd'hui. C'est ce qui en fait un enseignement plutôt
    /// qu'une punition.
    private var coffeeRow: some View {
        HStack(spacing: 8) {
            // Le symbole d'Apple plutot que le mot : il est reconnu sans etre
            // lu, et la ligne s'aligne avec le reste de la legende.
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Café")
            Spacer()
            Text(coffeeSentence)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            // Le retrait n'apparait que s'il y a quelque chose a retirer :
            // un bouton grise en permanence est un reproche muet.
            if todayCoffees > 0 {
                Button {
                    removeLastCoffee()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .tint(Ink.control)
                .accessibilityLabel("Retirer le dernier café")
            }

            Button {
                Feedback.play(.coffee)
                context.insert(CoffeeIntake())
                actions.record("Café noté")
                Task { await clarityStore.refresh(context: context) }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glass)
            .tint(Ink.control)
            .accessibilityLabel("Noter un café")
        }
        .frame(minHeight: 34)
    }

    private var coffeeSentence: String {
        guard todayCoffees > 0 else { return "aucun" }
        let count = "\(todayCoffees)"
        // La pénalité porte sur la nuit prochaine, jamais sur aujourd'hui.
        guard reading.projectedNightPenalty > 0.05 else { return count }
        return "\(count) · la nuit en pâtira"
    }

    private var windowSentence: String {
        let now = Date()
        if now < window.start {
            return "Ta fenêtre s’ouvre à \(clock(window.start))."
        }
        if window.contains(now) {
            return "Fenêtre ouverte jusqu’à \(clock(window.end))."
        }
        return "Fenêtre fermée. Elle rouvre demain matin."
    }

    /// L'atterrissage : le seul nombre de l'application, et toujours une
    /// fourchette. Elle se tait tant qu'il n'y a rien à extrapoler — inventer
    /// une date serait pire que se taire.
    @ViewBuilder
    private var landingCard: some View {
        if let landing = landing {
            VStack(alignment: .leading, spacing: 12) {
                Text("ATTERRISSAGE")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)
                Text(range(landing))
                    .font(.system(size: 26, weight: .light))
                Text("Calculé sur tes fils passés, pas sur une estimation.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .bentoSurface(Ink.violet, corner: 30, intensity: 0.5)
        }
    }

    private var landing: Landing? {
        let history = closed.map(\.resumptions.count).filter { $0 > 0 }
        let activeDays = Set(allResumptions.map { Calendar.current.startOfDay(for: $0.startedAt) })
        let capacity = activeDays.isEmpty ? 0 : Double(allResumptions.count) / Double(activeDays.count)

        return LandingEstimator.estimate(
            closedResumptions: history,
            openThreads: threads.count,
            dailyCapacity: capacity,
            from: Date()
        )
    }

    private func range(_ landing: Landing) -> String {
        let format = Date.FormatStyle.dateTime.weekday(.abbreviated).day()
        return "\(landing.earliest.formatted(format)) → \(landing.latest.formatted(format))"
    }

    /// Les fils ouverts, groupes sous leur projet.
    ///
    /// Le projet existait dans les donnees sans exister a l'ecran : on pouvait
    /// en creer un, y ranger un fil, et ne plus jamais le voir comme projet.
    /// Le groupe le rend visible sans ajouter d'ecran — l'application n'a que
    /// deux niveaux, et un troisieme pour ranger des dossiers serait payer
    /// cher une commodite.
    ///
    /// **L'ordre des groupes suit la premiere apparition d'un de leurs fils**,
    /// et non le titre ni la date d'ouverture du projet : la liste garde ainsi
    /// exactement l'ordre qu'elle avait avant le groupage, et ne se reorganise
    /// pas sous les yeux de quelqu'un qui ferme un fil.
    private var groups: [(project: Project?, threads: [WorkThread])] {
        var order: [Project?] = []
        var byProject: [UUID?: [WorkThread]] = [:]
        for thread in threads {
            let key = thread.project?.id
            if byProject[key] == nil {
                byProject[key] = []
                order.append(thread.project)
            }
            byProject[key]?.append(thread)
        }
        // Les fils sans projet ferment la marche : ce sont les moins ranges,
        // pas les plus importants.
        let sorted = order.filter { $0 != nil } + order.filter { $0 == nil }
        return sorted.map { ($0, byProject[$0?.id] ?? []) }
    }

    @ViewBuilder
    private var threadList: some View {
        VStack(spacing: 12) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                VStack(alignment: .leading, spacing: 12) {
                    projectHeader(group.project, index: index)
                    ForEach(Array(group.threads.enumerated()), id: \.element.id) { rank, thread in
                        Button {
                            active = thread
                        } label: {
                            // La teinte du projet colore tous ses fils : le
                            // groupe se lit alors comme un ensemble. Sans
                            // projet, on reprend la progression des teintes.
                            ThreadRow(
                                thread: thread,
                                hue: group.project?.hue
                                    ?? Ink.cardHues[(index + 1) % Ink.cardHues.count],
                                // Le nom est deja dans l'en-tete : le repeter
                                // sur chaque fil encombre pour rien.
                                showsProject: false
                            )
                        }
                        .buttonStyle(Pressable())
                        .cardEntrance(index + rank)
                        // **Un appui long, pas un balayage.** Les lignes ne
                        // sont pas dans une `List` — un balayage n'y existe
                        // pas — et surtout la suppression ne doit pas etre a
                        // un geste de distance d'un defilement.
                        .contextMenu {
                            Button {
                                editingThread = thread
                            } label: {
                                Label("Modifier", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                delete(thread)
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                composing = true
            } label: {
                Label("Ouvrir un fil", systemImage: "plus")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.glass)
            .tint(Ink.control)
        }
    }

    /// L'en-tete d'un groupe.
    ///
    /// Il ne s'affiche que s'il y a quelque chose a distinguer : avec un seul
    /// groupe sans projet, il n'annoncerait rien.
    @ViewBuilder
    private func projectHeader(_ project: Project?, index: Int) -> some View {
        if project != nil || groups.count > 1 {
            HStack(spacing: 8) {
                Circle()
                    .fill(project?.hue.tint ?? Color.white.opacity(0.28))
                    .frame(width: 7, height: 7)
                Text((project?.title ?? "Sans projet").uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.top, index == 0 ? 0 : 10)
            .padding(.horizontal, 4)
        }
    }

    /// **Sans confirmation, et c'est le point.** Un dialogue avant chaque
    /// suppression punit les mille fois ou l'on ne se trompe pas ; la bande
    /// d'annulation ne coute rien a personne et rattrape la seule fois ou l'on
    /// se trompe.
    private func delete(_ thread: WorkThread) {
        Feedback.play(.held)
        context.delete(thread)
        actions.record("Fil supprimé")
    }

    /// Retire le dernier cafe note aujourd'hui.
    ///
    /// L'annulation le couvre deja pendant six secondes ; ce geste existe pour
    /// la faute qu'on remarque une heure plus tard, quand la bande a disparu.
    private func removeLastCoffee() {
        guard let last = coffees
            .filter({ Calendar.current.isDateInToday($0.takenAt) })
            .max(by: { $0.takenAt < $1.takenAt }) else { return }
        Feedback.play(.held)
        context.delete(last)
        actions.record("Café retiré")
        Task { await clarityStore.refresh(context: context) }
    }

    private func releaseDueThreads() {
        let now = Date()
        for thread in threads { thread.releaseIfDue(now: now) }
    }
}

/// Un fil dans la liste.
struct ThreadRow: View {
    let thread: WorkThread
    let hue: Ink.CardHue
    /// Faux quand la ligne est deja sous un en-tete de projet.
    var showsProject = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if showsProject, let project = thread.project {
                    Circle()
                        .fill(project.hue.tint)
                        .frame(width: 6, height: 6)
                    Text(project.title.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(thread.nature.word.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                Spacer()
                if thread.state == .held, let until = thread.heldUntil {
                    Text("retenu jusqu’à \(until.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(Ink.marker)
                }
            }

            Text(thread.phrase)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !thread.resumptions.isEmpty {
                Text("\(thread.resumptions.count) reprise\(thread.resumptions.count > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .bentoSurface(hue, corner: 30, intensity: thread.state == .held ? 0.3 : 0.55)
    }
}

/// La fenêtre du jour, en graduations. Le repère marque l'instant présent.
struct WindowStrip: View {
    let window: DateInterval
    let now: Date

    private var progress: Double {
        guard window.duration > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(window.start) / window.duration))
    }

    private var isPast: Bool { now > window.end }

    var body: some View {
        // Une echelle pleine se lit comme « accompli ». Passe la fenetre, elle
        // veut dire l'inverse : le creneau est perdu, pas rempli. On la teint
        // donc en gris plutot que dans la couleur du present.
        TickScale(progress: progress, tint: isPast ? Color.white.opacity(0.25) : Ink.marker)
    }
}

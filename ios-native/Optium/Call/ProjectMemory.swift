import Foundation

/// La memoire d'un projet : un fichier markdown local, une ligne par fil ferme.
///
/// Markdown et non base de donnees, pour une raison qui n'est pas technique :
/// l'utilisateur doit pouvoir **la lire, la corriger, l'exporter, tout
/// effacer**. Un format qu'il ne peut pas ouvrir serait une promesse de
/// confidentialite invérifiable.
///
/// Le contenu ne quitte jamais l'appareil : le modele qui le lit tourne
/// dessus.
struct ProjectMemory {
    let slug: String

    private static var root: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("optium", isDirectory: true)
    }

    var url: URL { Self.root.appendingPathComponent("\(slug).md") }

    init(projectTitle: String) {
        self.slug = Self.slugify(projectTitle)
    }

    func read() -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    /// Ajoute une ligne. On n'ecrase jamais : la memoire s'accumule, et une
    /// relecture doit pouvoir remonter le fil.
    func append(_ line: String, at date: Date = Date()) {
        try? FileManager.default.createDirectory(at: Self.root, withIntermediateDirectories: true)

        let stamp = date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
        let entry = "- \(stamp) — \(line)\n"

        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(entry.utf8))
            try? handle.close()
        } else {
            let header = "# \(slug)\n\n"
            try? (header + entry).write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func erase() {
        try? FileManager.default.removeItem(at: url)
    }

    private static func slugify(_ title: String) -> String {
        let folded = title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let allowed = folded.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return String(allowed)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
    }
}

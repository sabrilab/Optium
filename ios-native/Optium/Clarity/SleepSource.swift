import Foundation

/// D'ou viennent les nuits.
protocol SleepSource: Sendable {
    var isAvailable: Bool { get }
    /// - Returns: faux si l'utilisateur refuse, ou si la source n'a rien a
    ///   offrir sur cet appareil.
    func requestAuthorization() async -> Bool
    func nights(from: Date, to: Date) async -> [Night]
}

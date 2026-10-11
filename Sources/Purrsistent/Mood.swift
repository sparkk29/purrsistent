import Foundation

/// How content the pet is, from 0 (grumpy) to 1 (delighted). Slowly fades without attention.
@MainActor
final class Mood {
    private static let decayPerSecond = 1.0 / (8 * 60 * 60)
    private static let saveInterval: TimeInterval = 15
    /// Coming back to a neglected pet shouldn't start it at rock bottom.
    private static let floorAfterAbsence = 0.25

    private let settings: Settings
    private var timeSinceSave: TimeInterval = 0

    private(set) var value: Double

    init(settings: Settings) {
        self.settings = settings
        if let saved = settings.savedMood {
            let elapsed = max(0, Date().timeIntervalSince(saved.date))
            value = max(Self.floorAfterAbsence, min(1, saved.value - elapsed * Self.decayPerSecond))
        } else {
            value = 0.7
        }
    }

    var label: String {
        switch value {
        case ..<0.25: "Grumpy"
        case ..<0.5: "Bored"
        case ..<0.75: "Content"
        default: "Happy"
        }
    }

    func boost(_ amount: Double) {
        value = min(1, value + amount)
    }

    func tick(_ dt: TimeInterval) {
        value = max(0, value - dt * Self.decayPerSecond)
        timeSinceSave += dt
        if timeSinceSave >= Self.saveInterval { save() }
    }

    func save() {
        timeSinceSave = 0
        settings.savedMood = (value, Date())
    }
}

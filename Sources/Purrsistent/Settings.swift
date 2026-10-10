import Foundation

enum PetSize: String, CaseIterable {
    case small, medium, large

    var points: CGFloat {
        switch self {
        case .small: 64
        case .medium: 96
        case .large: 128
        }
    }

    var title: String { rawValue.capitalized }
}

enum PetSpeed: String, CaseIterable {
    case slow, normal, fast

    var multiplier: CGFloat {
        switch self {
        case .slow: 0.6
        case .normal: 1
        case .fast: 1.6
        }
    }

    var title: String { rawValue.capitalized }
}

enum SoundVolume: String, CaseIterable {
    case low, medium, high

    var level: Float {
        switch self {
        case .low: 0.3
        case .medium: 0.6
        case .high: 1
        }
    }

    var title: String { rawValue.capitalized }
}

@MainActor
final class Settings {
    static let shared = Settings()

    private enum Keys {
        static let size = "petSize"
        static let speed = "petSpeed"
        static let stayStill = "stayStill"
        static let soundEnabled = "soundEnabled"
        static let soundVolume = "soundVolume"
    }

    private let defaults: UserDefaults

    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var size: PetSize {
        get { defaults.string(forKey: Keys.size).flatMap(PetSize.init(rawValue:)) ?? .medium }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.size)
            onChange?()
        }
    }

    var speed: PetSpeed {
        get { defaults.string(forKey: Keys.speed).flatMap(PetSpeed.init(rawValue:)) ?? .normal }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.speed)
            onChange?()
        }
    }

    var stayStill: Bool {
        get { defaults.bool(forKey: Keys.stayStill) }
        set {
            defaults.set(newValue, forKey: Keys.stayStill)
            onChange?()
        }
    }

    var soundEnabled: Bool {
        get { defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Keys.soundEnabled)
            onChange?()
        }
    }

    var soundVolume: SoundVolume {
        get { defaults.string(forKey: Keys.soundVolume).flatMap(SoundVolume.init(rawValue:)) ?? .medium }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.soundVolume)
            onChange?()
        }
    }
}

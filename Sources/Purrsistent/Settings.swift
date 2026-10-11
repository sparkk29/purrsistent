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

enum Coat: String, CaseIterable {
    case orange, midnight, silver, snowball, custom

    var title: String { rawValue.capitalized }
}

/// Which cat's meows and chirps to use. Each voice lives in `Resources/Sounds/<folder>/`.
enum Voice: String, CaseIterable {
    case classic, kitten, tomcat, custom

    var title: String { rawValue.capitalized }
    var folder: String { title }
}

enum BreakInterval: Int, CaseIterable {
    case off = 0
    case every25 = 25
    case every45 = 45
    case every60 = 60

    var seconds: TimeInterval? {
        self == .off ? nil : TimeInterval(rawValue * 60)
    }

    var title: String {
        self == .off ? "Off" : "Every \(rawValue) min"
    }
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
        static let voice = "voice"
        static let breakInterval = "breakInterval"
        static let coat = "coat"
        static let moodValue = "moodValue"
        static let moodDate = "moodDate"
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

    var voice: Voice {
        get { defaults.string(forKey: Keys.voice).flatMap(Voice.init(rawValue:)) ?? .classic }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.voice)
            onChange?()
        }
    }

    /// Persisted pet state rather than a preference, so it doesn't trigger `onChange`.
    var savedMood: (value: Double, date: Date)? {
        get {
            guard let date = defaults.object(forKey: Keys.moodDate) as? Date else { return nil }
            return (defaults.double(forKey: Keys.moodValue), date)
        }
        set {
            defaults.set(newValue?.value, forKey: Keys.moodValue)
            defaults.set(newValue?.date, forKey: Keys.moodDate)
        }
    }

    var coat: Coat {
        get { defaults.string(forKey: Keys.coat).flatMap(Coat.init(rawValue:)) ?? .orange }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.coat)
            onChange?()
        }
    }

    var breakInterval: BreakInterval {
        get { BreakInterval(rawValue: defaults.integer(forKey: Keys.breakInterval)) ?? .off }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.breakInterval)
            onChange?()
        }
    }
}

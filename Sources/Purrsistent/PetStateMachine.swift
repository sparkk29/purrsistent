import Foundation

enum PetState: String {
    case idle, walkLeft, walkRight, sit, sleep, dragged, falling, happy, petted, yawn, groom, eating

    var isWalking: Bool { self == .walkLeft || self == .walkRight }
}

@MainActor
final class PetStateMachine {
    private(set) var state: PetState = .idle
    private(set) var timeInState: TimeInterval = 0
    private var duration: TimeInterval = 2
    private var awakeIdleTime: TimeInterval = 0

    var onStateChange: ((_ old: PetState, _ new: PetState) -> Void)?
    /// Called when a state runs its full course, as opposed to being interrupted.
    var onStateCompleted: ((PetState) -> Void)?

    /// 0 (grumpy) to 1 (delighted); shifts the odds between lazing about and playing.
    var mood: Double = 0.7

    var allowWalking = true {
        didSet {
            if !allowWalking && state.isWalking { transition(to: .idle) }
        }
    }

    func tick(_ dt: TimeInterval) {
        timeInState += dt
        switch state {
        case .dragged, .falling, .petted:
            return
        case .sleep:
            break
        default:
            awakeIdleTime += dt
        }
        if timeInState >= duration {
            let finished = state
            transition(to: chooseNext())
            onStateCompleted?(finished)
        }
    }

    func noteInteraction() {
        awakeIdleTime = 0
    }

    func poke() {
        noteInteraction()
        transition(to: .happy)
    }

    func beginDrag() {
        noteInteraction()
        transition(to: .dragged)
    }

    func drop() {
        transition(to: .falling)
    }

    func startFalling() {
        guard state != .dragged, state != .falling else { return }
        transition(to: .falling)
    }

    func land() {
        guard state == .falling else { return }
        transition(to: .idle)
    }

    var canBePetted: Bool {
        switch state {
        case .dragged, .falling, .petted, .eating: false
        default: true
        }
    }

    func startPetting() {
        guard canBePetted else { return }
        noteInteraction()
        transition(to: .petted)
    }

    func stopPetting() {
        guard state == .petted else { return }
        noteInteraction()
        transition(to: .idle)
    }

    /// Plays a one-off action like a yawn, unless the pet is airborne.
    func perform(_ action: PetState) {
        guard state != .dragged, state != .falling else { return }
        transition(to: action)
    }

    /// Flips walking direction without restarting the current walk's duration.
    func turnAround() {
        let old = state
        switch state {
        case .walkLeft: state = .walkRight
        case .walkRight: state = .walkLeft
        default: return
        }
        onStateChange?(old, state)
    }

    static var isNightTime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 22 || hour < 6
    }

    private func chooseNext() -> PetState {
        if state == .sleep {
            awakeIdleTime = 0
            return .idle
        }

        let night = Self.isNightTime
        if awakeIdleTime >= (night ? 45 : 120) {
            return .sleep
        }

        var options: [(state: PetState, weight: Double)] = [
            (.idle, state == .idle ? 15 : 30),
            (.sit, (state == .sit ? 5 : 15) * (1.5 - mood)),
            (.yawn, night ? 10 : 4),
            (.groom, state == .groom ? 0 : 8),
        ]
        if allowWalking {
            let walkWeight = 22 * (0.5 + mood) * (night ? 0.5 : 1)
            options.append((.walkLeft, walkWeight))
            options.append((.walkRight, walkWeight))
        }
        if mood > 0.7 {
            options.append((.happy, 6))
        }
        return weightedPick(options)
    }

    private func weightedPick(_ options: [(state: PetState, weight: Double)]) -> PetState {
        let total = options.reduce(0) { $0 + $1.weight }
        var roll = Double.random(in: 0..<total)
        for option in options {
            if roll < option.weight { return option.state }
            roll -= option.weight
        }
        return options.last?.state ?? .idle
    }

    private func transition(to newState: PetState) {
        let old = state
        state = newState
        timeInState = 0
        duration = Self.randomDuration(for: newState)
        if old != newState { onStateChange?(old, newState) }
    }

    private static func randomDuration(for state: PetState) -> TimeInterval {
        switch state {
        case .idle: .random(in: 2...5)
        case .walkLeft, .walkRight: .random(in: 3...8)
        case .sit: .random(in: 4...10)
        case .groom: .random(in: 3...5)
        case .eating: 2
        case .sleep: .random(in: 60...180)
        case .happy, .yawn: 1.2
        case .dragged, .falling, .petted: .infinity
        }
    }
}

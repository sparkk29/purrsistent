import Foundation

enum PetState: String {
    case idle, walkLeft, walkRight, sit, sleep, dragged, falling, happy

    var isWalking: Bool { self == .walkLeft || self == .walkRight }
}

@MainActor
final class PetStateMachine {
    private(set) var state: PetState = .idle
    private(set) var timeInState: TimeInterval = 0
    private var duration: TimeInterval = 2
    private var awakeIdleTime: TimeInterval = 0

    var sleepAfter: TimeInterval = 120
    var onStateChange: ((_ old: PetState, _ new: PetState) -> Void)?

    var allowWalking = true {
        didSet {
            if !allowWalking && state.isWalking { transition(to: .idle) }
        }
    }

    func tick(_ dt: TimeInterval) {
        timeInState += dt
        switch state {
        case .dragged, .falling:
            return
        case .sleep:
            break
        default:
            awakeIdleTime += dt
        }
        if timeInState >= duration {
            transition(to: chooseNext())
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

    private func chooseNext() -> PetState {
        if state == .sleep {
            awakeIdleTime = 0
            return .idle
        }
        if awakeIdleTime >= sleepAfter {
            return .sleep
        }

        var options: [(state: PetState, weight: Double)] = [
            (.idle, state == .idle ? 15 : 30),
            (.sit, state == .sit ? 5 : 15),
        ]
        if allowWalking {
            options.append((.walkLeft, 22))
            options.append((.walkRight, 22))
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
        case .sleep: .random(in: 60...180)
        case .happy: 1.2
        case .dragged, .falling: .infinity
        }
    }
}

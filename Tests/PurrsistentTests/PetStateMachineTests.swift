import Testing
@testable import Purrsistent

@MainActor
@Suite struct PetStateMachineTests {
    private func makeMachine(random: @escaping () -> Double = seeded()) -> PetStateMachine {
        let machine = PetStateMachine()
        machine.random = random
        machine.isNight = { false }
        machine.mood = 0.5
        return machine
    }

    @Test func sleepEndsByWakingUpGradually() {
        let machine = makeMachine()
        machine.perform(.sleep)
        machine.tick(200)
        #expect(machine.state == .waking)
        machine.tick(2)
        #expect(machine.state == .stretch || machine.state == .idle)
    }

    @Test func wakeOnlyAffectsASleepingPet() {
        let machine = makeMachine()
        machine.wake()
        #expect(machine.state == .idle)
        machine.perform(.sleep)
        machine.wake()
        #expect(machine.state == .waking)
    }

    @Test func pokingASleepingPetStartlesIt() {
        let machine = makeMachine()
        machine.perform(.sleep)
        machine.poke()
        #expect(machine.state == .startled)
        machine.tick(1.1)
        #expect(machine.state == .idle)
    }

    @Test func aPokeIsHappyButTooManyAnnoy() {
        let machine = makeMachine()
        machine.poke()
        #expect(machine.state == .happy)
        for _ in 0..<3 {
            machine.tick(0.3)
            machine.poke()
        }
        #expect(machine.state == .annoyed)
    }

    @Test func pokesDoNotInterruptBeingCarried() {
        let machine = makeMachine()
        machine.beginDrag()
        machine.poke()
        #expect(machine.state == .dragged)
        machine.attend()
        #expect(machine.state == .dragged)
    }

    @Test func attentionOnlyInterruptsIdleBehaviorAndCoolsDown() {
        let machine = makeMachine()
        machine.attend()
        #expect(machine.state == .curious)
        machine.tick(3)
        #expect(machine.state != .curious)
        machine.perform(.idle)
        machine.attend()
        #expect(machine.state == .idle, "still cooling down")
        machine.tick(1)
        machine.perform(.idle)
        machine.tick(4)
        machine.perform(.idle)
        machine.attend()
        #expect(machine.state == .curious)

        machine.perform(.sleep)
        machine.tick(7)
        machine.attend()
        #expect(machine.state == .sleep, "a sleeping pet isn't disturbed")
    }

    @Test func aHardLandingStartlesAndASoftOneDoesNot() {
        let machine = makeMachine()
        machine.drop()
        machine.land(impactSpeed: 2000)
        #expect(machine.state == .startled)
        machine.drop()
        machine.land(impactSpeed: 300)
        #expect(machine.state == .idle)
    }

    @Test func stretchingCanLeadIntoGrooming() {
        let machine = makeMachine(random: { 0.1 })
        machine.perform(.stretch)
        machine.tick(2.1)
        #expect(machine.state == .groom)
    }

    @Test func drowsinessBuildsBeforeSleep() {
        let machine = makeMachine()
        var samples: [(time: Double, drowsiness: Double, state: PetState)] = []
        for second in 1...130 {
            machine.tick(1)
            samples.append((Double(second), machine.drowsiness, machine.state))
        }
        #expect(samples.filter { $0.time < 90 }.allSatisfy { $0.drowsiness == 0 })
        let late = samples.filter { $0.time >= 110 && $0.state.priority == .ambient && $0.state != .sleep }
        #expect(late.allSatisfy { $0.drowsiness > 0.5 })
        #expect(samples.contains { $0.state == .sleep })
    }

    @Test func priorities() {
        #expect(PetState.idle.priority < PetState.curious.priority)
        #expect(PetState.curious.priority < PetState.petted.priority)
        #expect(PetState.startled.priority < PetState.falling.priority)
    }
}

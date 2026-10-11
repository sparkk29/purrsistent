import CoreGraphics
import Testing
@testable import Purrsistent

typealias Pose = AnimeCatFactory.RigPose

func seeded(_ seed: UInt64 = 1) -> () -> Double {
    var generator = SeededRandom(seed: seed)
    return { Double.random(in: 0..<1, using: &generator) }
}

/// Steps the animator at 60 fps, handing each pose to `each`.
func run(_ animator: AnimeCatAnimator, for seconds: Double, each: (Pose) -> Void = { _ in }) {
    let step = 1.0 / 60
    for _ in 0..<Int((seconds / step).rounded()) {
        each(animator.update(by: step))
    }
}

private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    hypot(a.x - b.x, a.y - b.y)
}

/// How far the body's main joints move between two consecutive frames.
private func jump(_ a: Pose, _ b: Pose) -> CGFloat {
    max(distance(a.head, b.head), distance(a.hip, b.hip), distance(a.shoulder, b.shoulder), abs(a.lift - b.lift))
}

@Suite struct AnimeClipTests {
    @Test func oneShotClipHoldsItsLastKey() {
        let clip = AnimeCatClips.clip(for: .stretch)
        #expect(!clip.loops)
        let end = clip.sample(at: clip.length + 5)
        let last = clip.keys[clip.keys.count - 1]
        #expect(end.head == last.head)
        #expect(end.hip == last.hip)
    }

    @Test func loopingClipCyclesFromItsLoopStart() throws {
        let clip = AnimeCatClips.clip(for: .groom)
        let loopStart = try #require(clip.loopStart)
        let intro = clip.durations[..<loopStart].reduce(0, +)
        let cycle = clip.durations[loopStart...].reduce(0, +)
        for offset in [0.05, 0.3, 0.71] {
            let first = clip.sample(at: intro + offset)
            let later = clip.sample(at: intro + offset + cycle * 3)
            #expect(distance(first.frontNear, later.frontNear) < 0.001)
            #expect(distance(first.head, later.head) < 0.001)
        }
    }

    @Test(arguments: AnimeMotion.allCases)
    func clipsMoveContinuously(_ motion: AnimeMotion) {
        let clip = AnimeCatClips.clip(for: motion)
        var previous = clip.sample(at: 0)
        var time = 0.0
        while time < clip.length * 2 + 0.5 {
            time += 1.0 / 60
            let pose = clip.sample(at: time)
            #expect(jump(previous, pose) < 2, "\(motion) jumps at \(time)s")
            previous = pose
        }
    }
}

@Suite struct AnimeCatAnimatorTests {
    static let everyday: [AnimeMotion] = [.idle, .sit, .sleep, .waking, .curious, .happy, .stretch, .groom, .annoyed, .loaf, .walk, .petted, .yawn]

    @Test func transitionsBetweenEverydayMotionsNeverSnap() {
        for from in Self.everyday {
            for to in Self.everyday where to != from {
                let animator = AnimeCatAnimator(random: seeded())
                animator.start(from)
                run(animator, for: 0.7)
                var previous = animator.pose
                animator.setMotion(to)
                var worst: CGFloat = 0
                run(animator, for: 1.5) { pose in
                    worst = max(worst, jump(previous, pose))
                    previous = pose
                }
                #expect(worst < 1.2, "\(from) → \(to) jumps \(worst) units in one frame")
            }
        }
    }

    @Test func interruptingATransitionBlendsFromWhereTheCatIs() {
        let animator = AnimeCatAnimator(random: seeded())
        animator.start(.idle)
        run(animator, for: 0.5)
        animator.setMotion(.sleep)
        run(animator, for: 0.4)
        var previous = animator.pose
        animator.setMotion(.curious)
        var worst: CGFloat = 0
        run(animator, for: 1) { pose in
            worst = max(worst, jump(previous, pose))
            previous = pose
        }
        #expect(worst < 1.2)
    }

    @Test func eyesCloseThroughTheLidsWhenFallingAsleep() {
        let animator = AnimeCatAnimator(random: seeded())
        animator.start(.idle)
        run(animator, for: 0.5)
        animator.setMotion(.sleep)
        var lids: [CGFloat] = []
        var closedAfterOpen = false
        run(animator, for: 2) { pose in
            if pose.eyes == .open {
                lids.append(pose.lid)
            } else if pose.eyes == .closed {
                closedAfterOpen = true
            }
        }
        #expect(closedAfterOpen)
        #expect(lids.contains { $0 > 0.3 && $0 < 0.7 }, "the lids pass through half closed")
        #expect((lids.last ?? 0) > 0.85, "nearly shut before switching to the closed shape")
    }

    @Test func blinksAreSmoothAndIrregular() {
        let animator = AnimeCatAnimator(random: seeded(3))
        animator.start(.idle)
        var time = 0.0
        var blinkTimes: [Double] = []
        var shut = false
        var inBetween = 0
        run(animator, for: 40) { pose in
            time += 1.0 / 60
            if pose.lid > 0.2 && pose.lid < 0.8 { inBetween += 1 }
            if pose.lid > 0.9, !shut {
                shut = true
                blinkTimes.append(time)
            } else if pose.lid < 0.1 {
                shut = false
            }
        }
        #expect(blinkTimes.count >= 6)
        #expect(inBetween >= blinkTimes.count, "each blink has in-between lid frames")
        let gaps = zip(blinkTimes.dropFirst(), blinkTimes).map { $0 - $1 }
        let mean = gaps.reduce(0, +) / Double(gaps.count)
        let spread = (gaps.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(gaps.count)).squareRoot()
        #expect(spread > 0.4, "blink timing varies")
    }

    @Test func eyesLeadAndTheHeadFollowsTheAttentionPoint() {
        let animator = AnimeCatAnimator(random: seeded())
        animator.start(.idle)
        animator.attention = CGPoint(x: 10, y: 60)
        var firstLook: CGFloat?
        run(animator, for: 1.5) { pose in
            if firstLook == nil { firstLook = pose.look.dx }
        }
        #expect(animator.pose.look.dx < -0.6)
        #expect(animator.pose.look.dy > 0.5)
        #expect(animator.pose.headTilt > 3, "the head tips up toward a point above")

        animator.attention = CGPoint(x: 64, y: 5)
        run(animator, for: 1.5)
        #expect(animator.pose.look.dx > 0.6)
        #expect(animator.pose.look.dy < -0.5)
    }

    @Test func hoveringPerksTheEarsAndBrightensTheEyes() {
        let calm = AnimeCatAnimator(random: seeded())
        let hovered = AnimeCatAnimator(random: seeded())
        for animator in [calm, hovered] { animator.start(.sit) }
        hovered.hovered = true
        run(calm, for: 1)
        run(hovered, for: 1)
        #expect(hovered.pose.earTwitchLeft < calm.pose.earTwitchLeft - 4)
        #expect(hovered.pose.wide > calm.pose.wide + 0.2)
    }

    @Test func sleepingShowsAFewZs() {
        let animator = AnimeCatAnimator(random: seeded())
        animator.start(.sleep)
        var most = 0
        run(animator, for: 8) { _ in
            most = max(most, animator.particles.filter { $0.kind == .z }.count)
        }
        #expect(most >= 1)
        #expect(most <= 3)
        animator.setMotion(.waking)
        run(animator, for: 2)
        #expect(animator.particles.isEmpty, "Zs clear away after waking")
    }

    @Test func reducedMotionDampsHopsAndSkipsHearts() {
        func hop(reduced: Bool) -> (lift: CGFloat, hearts: Int) {
            let animator = AnimeCatAnimator(random: seeded())
            animator.reduceMotion = reduced
            animator.start(.idle)
            run(animator, for: 0.3)
            animator.setMotion(.happy)
            var lift: CGFloat = 0
            var hearts = 0
            run(animator, for: 1.2) { pose in
                lift = max(lift, pose.lift)
                hearts = max(hearts, animator.particles.filter { $0.kind == .heart }.count)
            }
            return (lift, hearts)
        }
        let normal = hop(reduced: false), reduced = hop(reduced: true)
        #expect(normal.lift > 3)
        #expect(normal.hearts >= 1)
        #expect(reduced.lift < 2)
        #expect(reduced.hearts == 0)
    }

    @Test func confusionShowsAQuestionMarkAndHasACooldown() {
        let animator = AnimeCatAnimator(random: seeded())
        animator.start(.idle)
        run(animator, for: 0.2)
        let before = animator.pose.headTilt
        #expect(animator.showConfusion())
        #expect(animator.particles.contains { $0.kind == .question })
        #expect(!animator.showConfusion())
        run(animator, for: 0.6)
        #expect(animator.pose.headTilt > before + 6)
        run(animator, for: 3)
        #expect(animator.showConfusion())

        let sleeper = AnimeCatAnimator(random: seeded())
        sleeper.start(.sleep)
        #expect(!sleeper.showConfusion())
    }

    @Test func talkingMovesTheMouthThenStops() {
        let animator = AnimeCatAnimator(random: seeded())
        animator.start(.curious)
        animator.speak(for: 1)
        var widest: CGFloat = 0
        var openings = 0
        var wasOpen = false
        run(animator, for: 1) { pose in
            widest = max(widest, pose.mouthOpen)
            let open = pose.mouthOpen > 0.2
            if open && !wasOpen { openings += 1 }
            wasOpen = open
        }
        #expect(widest > 0.3)
        #expect(openings >= 3, "several syllables, not one long gape")
        run(animator, for: 1)
        #expect(animator.pose.mouthOpen < 0.05)
    }

    @Test func turningAroundSqueezesInsteadOfSnapping() {
        let animator = AnimeCatAnimator(random: seeded())
        animator.start(.idle)
        run(animator, for: 0.1)
        #expect(!animator.mirrored)
        animator.facing = .left
        var narrowest: CGFloat = 1
        var flippedWhileWide = false
        run(animator, for: 0.3) { _ in
            narrowest = min(narrowest, animator.turnScale)
            if animator.mirrored && animator.turnScale > 0.95 && narrowest > 0.7 { flippedWhileWide = true }
        }
        #expect(narrowest < 0.7)
        #expect(!flippedWhileWide, "the flip happens at the narrowest point")
        #expect(animator.mirrored)
        #expect(animator.turnScale == 1)
    }

    @Test func tailStaysAttachedThroughBusyTransitions() {
        let animator = AnimeCatAnimator(random: seeded())
        animator.start(.idle)
        let sequence: [AnimeMotion] = [.happy, .startled, .annoyed, .sit, .groom, .stretch, .walk, .sleep, .waking, .idle]
        var longest: CGFloat = 0
        for motion in sequence {
            animator.setMotion(motion)
            run(animator, for: 0.9) { pose in
                for vector in [pose.tail1, pose.tail2, pose.tailTip] {
                    longest = max(longest, hypot(vector.dx, vector.dy))
                }
            }
        }
        #expect(longest < 30, "the tail never stretches out of shape")
    }

    @Test(arguments: AnimeMotion.allCases)
    func everyMotionProducesSanePoses(_ motion: AnimeMotion) {
        let animator = AnimeCatAnimator(random: seeded())
        animator.attention = CGPoint(x: 40, y: 40)
        animator.start(.idle)
        animator.setMotion(motion)
        run(animator, for: 3) { pose in
            let values = [pose.head.x, pose.head.y, pose.hip.x, pose.hip.y, pose.lid, pose.headTilt, pose.earTwitchLeft, pose.tailTip.dx, pose.tailTip.dy]
            let finite = values.allSatisfy { $0.isFinite }
            #expect(finite)
            #expect(pose.head.y + pose.lift < 64 && pose.head.y > 0)
            #expect(abs(pose.earTwitchLeft) < 80 && abs(pose.earTwitchRight) < 80)
        }
    }
}

import CoreGraphics
import Foundation

/// A floating sleep Z, heart, or question mark, in the right-facing canvas.
struct AnimeParticle {
    enum Kind { case z, heart, question }

    var kind: Kind
    var position: CGPoint
    var velocity: CGVector
    var life: TimeInterval
    var size: CGFloat
    var age: TimeInterval = 0
    var wobble: CGFloat = 0

    var progress: CGFloat { CGFloat(min(1, age / life)) }

    var alpha: CGFloat {
        let p = progress
        if p < 0.15 { return p / 0.15 }
        if p > 0.6 { return max(0, (1 - p) / 0.4) }
        return 1
    }

    var scale: CGFloat {
        switch kind {
        case .question:
            // Pops in with a little overshoot.
            let t = min(1, CGFloat(age) / 0.3)
            return size * (1 + 0.25 * sin(.pi * t)) * t
        case .z, .heart:
            return size * (0.7 + 0.45 * progress)
        }
    }
}

/// A damped spring, stepped in small increments so it stays stable at any frame rate.
struct Spring {
    var value: CGFloat
    var velocity: CGFloat = 0

    init(_ value: CGFloat = 0) {
        self.value = value
    }

    /// `frequency` in hertz; `damping` 1 settles without overshoot, lower values bounce.
    mutating func step(toward target: CGFloat, dt: TimeInterval, frequency: CGFloat, damping: CGFloat) {
        let omega = 2 * .pi * frequency
        var remaining = CGFloat(dt)
        while remaining > 0 {
            let h = min(remaining, 1 / 240)
            velocity += (omega * omega * (target - value) - 2 * damping * omega * velocity) * h
            value += velocity * h
            remaining -= h
        }
    }

    mutating func reset(to value: CGFloat) {
        self.value = value
        velocity = 0
    }
}

/// Drives the anime cat live. The pet's behavior picks a motion; the animator plays its clip,
/// eases from whatever the cat was doing into it, and layers coordinated secondary motion on
/// top: breathing, blinks with real eyelids, a gaze that follows the cursor with the head
/// lagging behind, springy ears that twitch on their own, a tail with follow-through, talking,
/// and the odd sleep Z or heart. It holds no app logic, so it can be driven and tested alone.
final class AnimeCatAnimator {
    typealias Pose = AnimeCatFactory.RigPose

    // MARK: Inputs

    /// Tones down secondary motion and bouncing, and skips decorative particles.
    var reduceMotion = false
    /// Speeds the walk cycle up along with the walking speed, so feet don't slide.
    var walkRate: Double = 1
    /// 0 when wide awake, rising toward 1 as the pet is about to fall asleep.
    var drowsiness: CGFloat = 0
    /// The cursor is over the cat.
    var hovered = false
    /// Where to look, in the right-facing canvas; nil lets the gaze wander.
    var attention: CGPoint?
    var facing: Facing = .right

    // MARK: Outputs

    private(set) var motion: AnimeMotion = .idle
    private(set) var pose = Pose()
    private(set) var particles: [AnimeParticle] = []
    /// Drawn facing left.
    private(set) var mirrored = false

    // MARK: State

    private let random: () -> Double
    private var time: TimeInterval = 0

    private var clip = AnimeCatClips.clip(for: .idle)
    private var clipTime: TimeInterval = 0
    private var base = Pose()
    private var blendFrom: Pose?
    private var blendTime: TimeInterval = 0
    private var blendDuration: TimeInterval = 0

    private var breathPhase: CGFloat = 0
    private var breathRate: CGFloat = 0.42
    private var breathAmount: CGFloat = 1
    private var drowsy: CGFloat = 0

    private struct Blink {
        var elapsed: TimeInterval = 0
        var duration: TimeInterval
        var hold: TimeInterval
        var asym: CGFloat
        var double: Bool
    }
    private var blink: Blink?
    private var nextBlink: TimeInterval = 2

    private var gazeX = Spring(0.5)
    private var gazeY = Spring(0)
    private var headTurn = Spring(0)
    private var lookWeight: CGFloat = 0
    private var wanderTarget = CGVector(dx: 0.5, dy: 0)
    private var nextWander: TimeInterval = 2
    private var lastGazeTarget = CGVector(dx: 0.5, dy: 0)

    private var earLeft = Spring(0)
    private var earRight = Spring(0)
    private var earFold = Spring(0)
    private var nextTwitchLeft: TimeInterval = 4
    private var nextTwitchRight: TimeInterval = 6
    private var wasHovered = false
    private var hoverWeight: CGFloat = 0

    private var tail1 = (x: Spring(-7), y: Spring(1))
    private var tail2 = (x: Spring(-12), y: Spring(10))
    private var tailTip = (x: Spring(-9), y: Spring(19))
    private var tailPhase: CGFloat = 0
    private var tailSway: CGFloat = 1
    private var tailRate: CGFloat = 0.32
    private var nextFlick: TimeInterval = 0
    private var lastLift: CGFloat = 0
    private var liftVelocity: CGFloat = 0

    private var confusion: TimeInterval?
    private var lastConfusion: TimeInterval = -.infinity
    private static let confusionLength: TimeInterval = 1.8
    private static let confusionCooldown: TimeInterval = 3

    private var talkRemaining: TimeInterval = 0
    private var mouthTarget: CGFloat = 0
    private var mouthOpen: CGFloat = 0
    private var nextSyllable: TimeInterval = 0

    private var nextParticle: TimeInterval = 0

    private var shownFacing: Facing = .right
    private var turnElapsed: TimeInterval = .infinity
    /// 0 to 1: how far round toward the viewer the cat is while turning around.
    private var turnAmount: CGFloat = 0
    static let turnDuration: TimeInterval = 0.6

    init(random: @escaping () -> Double = { Double.random(in: 0..<1) }) {
        self.random = random
        start(.idle)
    }

    // MARK: - Control

    /// Jumps straight into a motion with every layer settled, as on first appearance.
    func start(_ motion: AnimeMotion) {
        self.motion = motion
        clip = AnimeCatClips.clip(for: motion)
        clipTime = 0
        blendFrom = nil
        base = clip.sample(at: 0)
        pose = base
        earLeft.reset(to: base.earSpread + base.earTwitchLeft)
        earRight.reset(to: base.earSpread + base.earTwitchRight)
        earFold.reset(to: base.earTilt)
        tail1 = (Spring(base.tail1.dx), Spring(base.tail1.dy))
        tail2 = (Spring(base.tail2.dx), Spring(base.tail2.dy))
        tailTip = (Spring(base.tailTip.dx), Spring(base.tailTip.dy))
        lastLift = base.lift
        shownFacing = facing
        mirrored = facing == .left
        turnElapsed = .infinity
        turnAmount = 0
        nextBlink = time + between(1, 3)
        nextParticle = time + 0.6
    }

    /// Moves to a new motion, easing from the current pose so nothing snaps. Interrupting a
    /// transition halfway blends from wherever the cat is right now.
    func setMotion(_ newMotion: AnimeMotion) {
        guard newMotion != motion else { return }
        let old = motion
        motion = newMotion
        clip = AnimeCatClips.clip(for: newMotion)
        clipTime = 0
        blendFrom = base
        blendTime = 0
        blendDuration = max(
            Self.transitionDuration(from: old, to: newMotion),
            Self.travelTime(from: base, to: clip.sample(at: 0), reflex: Self.isReflex(newMotion))
        )
        enter(newMotion, from: old)
    }

    /// Moves the mouth as if talking, for about this long.
    func speak(for duration: TimeInterval) {
        talkRemaining = max(talkRemaining, duration)
    }

    /// A puzzled head tilt with one ear down and a question mark, for when something fails.
    /// Returns false while on cooldown or when the cat can't react (asleep or airborne).
    @discardableResult
    func showConfusion() -> Bool {
        guard time - lastConfusion >= Self.confusionCooldown, !Self.isAirborne(motion), motion != .sleep else { return false }
        lastConfusion = time
        confusion = 0
        let head = headTop(pose)
        particles.append(AnimeParticle(kind: .question, position: CGPoint(x: head.x + 5, y: head.y + 2), velocity: CGVector(dx: 0, dy: 0.8), life: 1.7, size: 2.2))
        return true
    }

    /// How long to ease from one motion into the next: snappy for reflexes, slow for settling
    /// down to sleep.
    static func transitionDuration(from old: AnimeMotion, to new: AnimeMotion) -> TimeInterval {
        switch (old, new) {
        case (_, .startled): 0.08
        case (_, .drag), (_, .leap): 0.1
        case (_, .fall): 0.15
        case (.fall, _): 0.12
        case (_, .sleep): 1.4
        case (.sleep, _): 0.6
        case (_, .happy): 0.18
        case (.startled, _), (.waking, _): 0.45
        case (.walk, _), (_, .walk): 0.25
        case (_, .stretch), (_, .groom), (_, .loaf), (_, .sit): 0.5
        default: 0.35
        }
    }

    /// Long enough that the body never moves faster than a cat plausibly would: big changes of
    /// pose, like springing up from a curl, take proportionally longer. Reflexes may be quicker.
    static func travelTime(from a: Pose, to b: Pose, reflex: Bool) -> TimeInterval {
        func distance(_ p: CGPoint, _ q: CGPoint) -> CGFloat { hypot(p.x - q.x, p.y - q.y) }
        let travel = max(distance(a.head, b.head), distance(a.hip, b.hip), distance(a.shoulder, b.shoulder), abs(a.lift - b.lift))
        return Double(travel / (reflex ? 90 : 26))
    }

    private static func isReflex(_ motion: AnimeMotion) -> Bool {
        motion == .startled || isAirborne(motion)
    }

    // MARK: - Update

    @discardableResult
    func update(by dt: TimeInterval) -> Pose {
        let dt = max(0, dt)
        time += dt
        clipTime += dt * (motion == .walk ? walkRate : 1)

        let target = clip.sample(at: clipTime)
        if let from = blendFrom {
            blendTime += dt
            let t = blendDuration > 0 ? CGFloat(min(1, blendTime / blendDuration)) : 1
            base = AnimeCatFactory.mix(from, target, t * t * t * (t * (6 * t - 15) + 10))
            if t >= 1 { blendFrom = nil }
        } else {
            base = target
        }

        // First, so that if the drawing flips this frame the springs below already know.
        updateTurn(dt: dt)

        var pose = base
        var earExtra = (left: CGFloat(0), right: CGFloat(0))
        applyDrowsiness(&pose, dt: dt)
        applyBreathing(&pose, dt: dt)
        applyGaze(&pose, dt: dt)
        applyHover(&pose, dt: dt, ears: &earExtra)
        applyConfusion(&pose, dt: dt, ears: &earExtra)
        applyEars(&pose, dt: dt, extra: earExtra)
        applyBlink(&pose, dt: dt)
        applyTail(&pose, dt: dt)
        applyTalking(&pose, dt: dt)
        if reduceMotion && !Self.isAirborne(motion) { pose.lift *= 0.3 }
        applyTurn(&pose)
        updateParticles(pose, dt: dt)
        self.pose = pose
        return pose
    }

    // MARK: - Layers

    /// Heavy lids, drooping ears, and a lowered head as the pet gets close to dozing off.
    private func applyDrowsiness(_ pose: inout Pose, dt: TimeInterval) {
        let allowed: Bool = switch motion {
        case .idle, .sit, .loaf: true
        default: false
        }
        approach(&drowsy, allowed ? min(1, max(0, drowsiness)) : 0, rate: 1.5, dt: dt)
        guard drowsy > 0.001 else { return }
        if pose.eyes == .open { pose.lid = max(pose.lid, 0.74 * drowsy) }
        pose.earSpread += 10 * drowsy
        pose.head.y -= 0.8 * drowsy
        pose.headTilt -= 4 * drowsy
    }

    private func applyBreathing(_ pose: inout Pose, dt: TimeInterval) {
        let (rate, amount): (CGFloat, CGFloat) = switch motion {
        case .sleep: (0.26, 1.35)
        case .waking, .loaf: (0.32, 1.1)
        case .idle, .sit, .curious, .annoyed, .groom, .petted, .knead, .eat: (0.42, 1)
        case .happy, .rollOver, .tailChase, .pounce: (0.8, 0.6)
        case .walk: (0.6, 0.35)
        case .stretch, .yawn, .startled, .scratch: (0.45, 0.4)
        case .drag, .fall, .leap: (0.9, 0)
        }
        approach(&breathRate, rate * (1 - 0.25 * drowsy), rate: 2, dt: dt)
        approach(&breathAmount, amount * (reduceMotion ? 0.5 : 1), rate: 2, dt: dt)
        breathPhase += 2 * .pi * breathRate * CGFloat(dt)
        let inhale = sin(breathPhase) * breathAmount
        pose.arch += 0.6 * inhale
        pose.sag += 0.4 * inhale
        pose.shoulder.y += 0.16 * inhale
        pose.hip.y += 0.05 * inhale
        pose.head.y += 0.2 * sin(breathPhase - 0.5) * breathAmount
    }

    /// Eyes dart to their target; the head follows more slowly with a small tilt.
    private func applyGaze(_ pose: inout Pose, dt: TimeInterval) {
        let weight: CGFloat = switch motion {
        case .idle, .sit, .curious, .loaf, .pounce: 1
        case .waking: 0.6
        case .annoyed: 0.5
        case .walk: 0.4
        default: 0
        }
        approach(&lookWeight, weight, rate: 4, dt: dt)

        var target: CGVector
        var headTarget: CGFloat
        if let attention {
            let head = CGPoint(x: base.head.x, y: base.head.y + base.lift)
            let dx = attention.x - head.x, dy = attention.y - head.y
            target = CGVector(dx: clamp(dx / 14, -1, 1), dy: clamp(dy / 14, -0.9, 0.9))
            headTarget = clamp(dy / 18, -1, 1) * 7
        } else {
            if time >= nextWander {
                nextWander = time + between(1.6, 4.2)
                wanderTarget = random() < 0.4
                    ? CGVector(dx: 0.5, dy: 0.05)
                    : CGVector(dx: CGFloat(between(-0.7, 0.8)), dy: CGFloat(between(-0.3, 0.45)))
            }
            target = wanderTarget
            headTarget = wanderTarget.dy * 4
        }
        let jump = hypot(target.dx - lastGazeTarget.dx, target.dy - lastGazeTarget.dy)
        if jump > 0.9, lookWeight > 0.5, blink == nil, random() < 0.35 {
            startBlink(slow: false)
        }
        lastGazeTarget = target

        gazeX.step(toward: target.dx, dt: dt, frequency: 5, damping: 0.95)
        gazeY.step(toward: target.dy, dt: dt, frequency: 5, damping: 0.95)
        headTurn.step(toward: headTarget * lookWeight * (reduceMotion ? 0.5 : 1), dt: dt, frequency: 1.2, damping: 0.85)
        pose.look = CGVector(
            dx: pose.look.dx + (gazeX.value - pose.look.dx) * lookWeight,
            dy: pose.look.dy + (gazeY.value - pose.look.dy) * lookWeight
        )
        pose.headTilt += headTurn.value
    }

    /// Ears perk and eyes brighten while the cursor rests on the cat. A sleeping cat only
    /// flicks an ear.
    private func applyHover(_ pose: inout Pose, dt: TimeInterval, ears: inout (left: CGFloat, right: CGFloat)) {
        let allowed: Bool = switch motion {
        case .idle, .sit, .curious, .loaf, .walk, .waking: true
        default: false
        }
        if hovered && !wasHovered && motion == .sleep {
            earRight.velocity += 420
        }
        wasHovered = hovered
        let target: CGFloat = hovered && allowed ? 1 : 0
        approach(&hoverWeight, target, rate: target > hoverWeight ? 5 : 2.5, dt: dt)
        guard hoverWeight > 0.001 else { return }
        ears.left -= 9 * hoverWeight
        ears.right -= 9 * hoverWeight
        pose.wide = max(pose.wide, 0.35 * hoverWeight)
        pose.headTilt += 4 * hoverWeight
    }

    private func applyConfusion(_ pose: inout Pose, dt: TimeInterval, ears: inout (left: CGFloat, right: CGFloat)) {
        guard var elapsed = confusion else { return }
        elapsed += dt
        let length = Self.confusionLength
        guard elapsed < length, !Self.isAirborne(motion), motion != .sleep else {
            confusion = nil
            return
        }
        confusion = elapsed
        let weight = smooth(min(1, elapsed / 0.25)) * smooth(min(1, (length - elapsed) / 0.45))
        pose.headTilt += 12 * weight
        ears.left += 20 * weight
        ears.right -= 6 * weight
        pose.look = CGVector(dx: pose.look.dx + (0.4 - pose.look.dx) * weight, dy: pose.look.dy + (0.75 - pose.look.dy) * weight)
        pose.lidAsym += 0.14 * weight
        pose.mouthOpen = max(pose.mouthOpen, 0.15 * weight)
    }

    /// Each ear springs toward its pose with a little overshoot, and now and then flicks on its own.
    private func applyEars(_ pose: inout Pose, dt: TimeInterval, extra: (left: CGFloat, right: CGFloat)) {
        let twitchy: Bool = switch motion {
        case .idle, .sit, .loaf, .sleep, .curious, .groom, .walk, .petted, .knead, .eat, .waking: true
        default: false
        }
        let interval: (TimeInterval, TimeInterval) = motion == .sleep ? (6, 14) : (3.5, 9)
        let strength: CGFloat = reduceMotion ? 0.4 : 1
        if time >= nextTwitchLeft {
            if twitchy { earLeft.velocity += CGFloat(between(380, 520)) * strength }
            nextTwitchLeft = time + between(interval.0, interval.1)
        }
        if time >= nextTwitchRight {
            if twitchy { earRight.velocity += CGFloat(between(380, 520)) * strength }
            nextTwitchRight = time + between(interval.0, interval.1)
        }
        earLeft.step(toward: pose.earSpread + pose.earTwitchLeft + extra.left, dt: dt, frequency: 3.2, damping: 0.45)
        earRight.step(toward: pose.earSpread + pose.earTwitchRight + extra.right, dt: dt, frequency: 3.2, damping: 0.45)
        earFold.step(toward: pose.earTilt, dt: dt, frequency: 3, damping: 0.6)
        pose.earSpread = 0
        pose.earTwitchLeft = earLeft.value
        pose.earTwitchRight = earRight.value
        pose.earTilt = earFold.value
    }

    /// Blinks close the upper lids smoothly, hold for a moment, and open a little slower. They
    /// come at irregular intervals, sometimes in pairs, and slow down when the cat is sleepy.
    private func applyBlink(_ pose: inout Pose, dt: TimeInterval) {
        guard pose.eyes == .open else {
            blink = nil
            return
        }
        let sleepy = drowsy > 0.4 || motion == .loaf || motion == .waking
        if blink == nil, time >= nextBlink {
            startBlink(slow: sleepy)
        }
        guard var current = blink else { return }
        current.elapsed += dt
        if current.elapsed >= current.duration {
            blink = nil
            if current.double {
                nextBlink = time + 0.08
            } else {
                let wideAwake = pose.wide > 0.6
                nextBlink = time + (sleepy ? between(1.6, 3.6) : wideAwake ? between(3.5, 7) : between(2.4, 6))
            }
            return
        }
        blink = current
        let amount = Self.lidCurve(elapsed: current.elapsed, duration: current.duration, hold: current.hold)
        pose.lid = max(pose.lid, amount)
        pose.lidAsym += current.asym * amount
    }

    /// 0 (open) to 1 (shut) through a blink: eases shut, holds, then eases open more slowly.
    static func lidCurve(elapsed: TimeInterval, duration: TimeInterval, hold: TimeInterval) -> CGFloat {
        let moving = max(0.001, duration - hold)
        let closing = moving * 0.4
        if elapsed < closing {
            let t = CGFloat(elapsed / closing)
            return t * t
        }
        if elapsed < closing + hold { return 1 }
        let t = CGFloat(min(1, (elapsed - closing - hold) / (moving - closing)))
        return 1 - (1 - (1 - t) * (1 - t))
    }

    private func startBlink(slow: Bool) {
        if slow {
            let asym = random() < 0.3 ? CGFloat(between(-0.2, 0.2)) : 0
            blink = Blink(duration: between(0.5, 0.7), hold: 0.14, asym: asym, double: false)
        } else {
            blink = Blink(duration: between(0.15, 0.2), hold: 0.03, asym: 0, double: random() < 0.12)
        }
    }

    /// The tail's three control points chase their posed positions on springs, the tip loosest,
    /// so motion ripples down the tail. A slow wave keeps it alive; annoyed cats flick it.
    private func applyTail(_ pose: inout Pose, dt: TimeInterval) {
        let (sway, rate): (CGFloat, CGFloat) = switch motion {
        case .idle, .sit, .curious: (1, 0.32)
        case .happy: (1.6, 0.9)
        case .petted, .knead: (1.2, 0.5)
        case .sleep: (0.25, 0.15)
        case .loaf, .waking: (0.4, 0.2)
        case .annoyed: (0.6, 0.6)
        case .groom, .eat, .yawn, .stretch, .scratch: (0.5, 0.3)
        case .walk, .rollOver, .pounce, .tailChase: (0.2, 0.4)
        case .drag, .fall, .leap, .startled: (0, 0.4)
        }
        approach(&tailSway, sway * (reduceMotion ? 0.4 : 1), rate: 1.5, dt: dt)
        approach(&tailRate, rate, rate: 1.5, dt: dt)
        tailPhase += 2 * .pi * tailRate * CGFloat(dt)

        var target1 = pose.tail1, target2 = pose.tail2, targetTip = pose.tailTip
        let s = tailSway
        if pose.tailInFront {
            target2.dy += 0.3 * sin(tailPhase + 0.5) * s
            targetTip.dx += 0.6 * sin(tailPhase) * s
            targetTip.dy += 0.9 * sin(tailPhase + 0.5) * s
        } else {
            target1.dx += 0.4 * sin(tailPhase + 0.9) * s
            target2.dx += 1.1 * sin(tailPhase + 0.45) * s
            target2.dy += 0.3 * cos(tailPhase) * s
            targetTip.dx += 2.2 * sin(tailPhase) * s
            targetTip.dy += 0.5 * sin(2 * tailPhase) * s
        }

        if motion == .annoyed, time >= nextFlick {
            nextFlick = time + between(0.6, 1.1)
            let side: CGFloat = random() < 0.5 ? -1 : 1
            tailTip.x.velocity += 26 * side * (reduceMotion ? 0.4 : 1)
            tailTip.y.velocity += 30 * (reduceMotion ? 0.4 : 1)
        }

        // Hops and landings throw the loose end of the tail around.
        let newLiftVelocity = dt > 0 ? (pose.lift - lastLift) / CGFloat(dt) : 0
        let kick = newLiftVelocity - liftVelocity
        liftVelocity = newLiftVelocity
        lastLift = pose.lift
        if !Self.isAirborne(motion) {
            tailTip.y.velocity -= kick * 0.5
            tail2.y.velocity -= kick * 0.25
        }

        tail1.x.step(toward: target1.dx, dt: dt, frequency: 2.6, damping: 0.8)
        tail1.y.step(toward: target1.dy, dt: dt, frequency: 2.6, damping: 0.8)
        tail2.x.step(toward: target2.dx, dt: dt, frequency: 1.9, damping: 0.7)
        tail2.y.step(toward: target2.dy, dt: dt, frequency: 1.9, damping: 0.7)
        tailTip.x.step(toward: targetTip.dx, dt: dt, frequency: 1.4, damping: 0.6)
        tailTip.y.step(toward: targetTip.dy, dt: dt, frequency: 1.4, damping: 0.6)
        pose.tail1 = CGVector(dx: tail1.x.value, dy: tail1.y.value)
        pose.tail2 = CGVector(dx: tail2.x.value, dy: tail2.y.value)
        pose.tailTip = CGVector(dx: tailTip.x.value, dy: tailTip.y.value)
    }

    /// Syllable-like mouth flaps with a slight nod while speaking.
    private func applyTalking(_ pose: inout Pose, dt: TimeInterval) {
        if talkRemaining > 0 {
            talkRemaining -= dt
            if time >= nextSyllable {
                mouthTarget = mouthTarget > 0.1 ? 0 : CGFloat(between(0.25, 0.8))
                nextSyllable = time + between(0.07, 0.15)
            }
        } else {
            mouthTarget = 0
        }
        approach(&mouthOpen, mouthTarget, rate: 30, dt: dt)
        guard mouthOpen > 0.01, pose.mouth == .closed else { return }
        pose.mouthOpen = max(pose.mouthOpen, mouthOpen)
        pose.head.y += 0.25 * mouthOpen
    }

    // MARK: - Particles

    private func enter(_ motion: AnimeMotion, from old: AnimeMotion) {
        switch motion {
        case .startled:
            tailTip.y.velocity += 60
            tail2.y.velocity += 30
            nextBlink = time + 1.2
        case .happy where !reduceMotion:
            let head = headTop(pose)
            particles.append(AnimeParticle(kind: .heart, position: CGPoint(x: head.x + 2, y: head.y), velocity: CGVector(dx: 0.8, dy: 6), life: 1.2, size: 1.7, wobble: CGFloat(random()) * 6))
        case .sleep:
            nextParticle = time + 1.6
        case .petted:
            nextParticle = time + 0.8
        default:
            break
        }
    }

    private func updateParticles(_ pose: Pose, dt: TimeInterval) {
        let head = headTop(pose)
        if time >= nextParticle {
            switch blendFrom == nil ? motion : nil {
            case .sleep where particles.filter({ $0.kind == .z }).count < 3:
                particles.append(AnimeParticle(
                    kind: .z,
                    position: CGPoint(x: head.x + 3, y: head.y - 2),
                    velocity: CGVector(dx: 1.6, dy: reduceMotion ? 2.2 : 4.2),
                    life: 2.8,
                    size: 1.9,
                    wobble: CGFloat(random()) * 6
                ))
                nextParticle = time + between(1.7, 2.3)
            case .petted where !reduceMotion && particles.filter({ $0.kind == .heart }).count < 2:
                particles.append(AnimeParticle(
                    kind: .heart,
                    position: CGPoint(x: head.x + 1, y: head.y),
                    velocity: CGVector(dx: 0.6, dy: 5.5),
                    life: 1.3,
                    size: 1.7,
                    wobble: CGFloat(random()) * 6
                ))
                nextParticle = time + between(1.4, 2)
            default:
                nextParticle = time + 0.5
            }
        }

        for index in particles.indices.reversed() {
            var particle = particles[index]
            // Zs hurry away once the cat is up.
            let speed: TimeInterval = particle.kind == .z && motion != .sleep ? 3 : 1
            particle.age += dt * speed
            let sway = particle.kind == .question ? 0 : 0.6 * cos(CGFloat(particle.age) * 3 + particle.wobble)
            particle.position.x += (particle.velocity.dx + sway) * CGFloat(dt)
            particle.position.y += particle.velocity.dy * CGFloat(dt)
            if particle.age >= particle.life {
                particles.remove(at: index)
            } else {
                particles[index] = particle
            }
        }
    }

    /// Roughly the top of the head, where floating particles start.
    private func headTop(_ pose: Pose) -> CGPoint {
        CGPoint(x: pose.head.x + 2, y: pose.head.y + pose.lift + 9)
    }

    // MARK: - Turning

    /// Turning around swings the cat round through facing the viewer. It is drawn mirrored from
    /// the halfway point, where it faces straight out and looks the same either way.
    private func updateTurn(dt: TimeInterval) {
        if facing != shownFacing, turnElapsed >= Self.turnDuration {
            turnElapsed = reduceMotion ? Self.turnDuration : 0
            if reduceMotion { shownFacing = facing }
        }
        if turnElapsed < Self.turnDuration {
            turnElapsed += dt
            let t = CGFloat(min(1, turnElapsed / Self.turnDuration))
            if t >= 0.5, shownFacing != facing {
                shownFacing = facing
                mirrorSprings()
            }
            // Lingers facing out for a moment around the halfway point.
            turnAmount = smooth(min(1, (1 - abs(1 - 2 * t)) * 1.2))
        } else {
            turnAmount = 0
        }
        mirrored = shownFacing == .left
    }

    /// When the drawing flips, the springy parts flip with it so they carry on from exactly where
    /// they were on screen, then swing over to their places on the other side: the tail sweeps
    /// across behind (or, wrapped round the paws, in front), and each ear keeps its own twitch.
    private func mirrorSprings() {
        func mirror(_ spring: inout Spring) {
            spring.value.negate()
            spring.velocity.negate()
        }
        mirror(&tail1.x)
        mirror(&tail2.x)
        mirror(&tailTip.x)
        swap(&earLeft, &earRight)
    }

    /// Foreshortens the side-on pose toward facing the viewer: the body shortens to a round
    /// end-on view over the middle of the canvas (the axis the drawing mirrors about), the paws
    /// gather under it in two columns, the head comes round over the chest looking straight
    /// out, and the tail swings in behind.
    private func applyTurn(_ pose: inout Pose) {
        let u = turnAmount
        guard u > 0.001 else { return }
        let middle = AnimeCatFactory.canvas / 2
        let center = CGPoint(x: (pose.hip.x + pose.shoulder.x) / 2, y: (pose.hip.y + pose.shoulder.y) / 2)
        let anchor = center.x + (middle - center.x) * u
        // Kept a hair apart so the spine's direction stays put.
        let spine = 1 - 0.98 * u
        pose.hip = CGPoint(x: anchor + (pose.hip.x - center.x) * spine, y: center.y + (pose.hip.y - center.y) * spine)
        pose.shoulder = CGPoint(x: anchor + (pose.shoulder.x - center.x) * spine, y: center.y + (pose.shoulder.y - center.y) * spine)
        pose.head.x = anchor + (pose.head.x - center.x) * (1 - u)

        let column: CGFloat = 3.4
        func gather(_ paw: inout CGPoint, near: Bool) {
            paw.x = anchor + (paw.x - center.x) * (1 - u) + (near ? column : -column) * u
        }
        gather(&pose.frontNear, near: true)
        gather(&pose.backNear, near: true)
        gather(&pose.frontFar, near: false)
        gather(&pose.backFar, near: false)

        // A tail held out behind swings in behind the body; one wrapped round the paws stays
        // wrapped and sweeps across the front after the flip.
        if !pose.tailInFront {
            let tailSpread = 1 - 0.9 * u
            pose.tail1.dx *= tailSpread
            pose.tail2.dx *= tailSpread
            pose.tailTip.dx *= tailSpread
        }

        pose.headTilt *= 1 - u
        pose.look.dx *= 1 - u
        pose.frontal = max(pose.frontal, u)
    }

    // MARK: - Helpers

    static func isAirborne(_ motion: AnimeMotion) -> Bool {
        motion == .drag || motion == .fall || motion == .leap
    }

    private func between(_ low: Double, _ high: Double) -> Double {
        low + (high - low) * random()
    }

    /// Moves `value` toward `target` exponentially, at about `rate` of the gap per second.
    private func approach(_ value: inout CGFloat, _ target: CGFloat, rate: CGFloat, dt: TimeInterval) {
        value += (target - value) * (1 - exp(-rate * CGFloat(dt)))
    }

    private func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
        min(high, max(low, value))
    }

    private func smooth(_ t: CGFloat) -> CGFloat {
        let t = min(1, max(0, t))
        return t * t * (3 - 2 * t)
    }
    private func smooth(_ t: TimeInterval) -> CGFloat { smooth(CGFloat(t)) }
}

/// A small deterministic generator (SplitMix64), for reproducible sprite exports and tests.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

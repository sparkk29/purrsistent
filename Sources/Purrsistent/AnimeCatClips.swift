import CoreGraphics
import Foundation

/// What the anime cat's body is doing. Breathing, blinking, gaze, ear twitches, and the tail's
/// sway are layered on top by `AnimeCatAnimator`, so clips only hold the deliberate motion.
enum AnimeMotion: CaseIterable {
    case idle, walk, sit, sleep, waking, curious, startled, annoyed
    case drag, fall, happy, petted, yawn, groom, eat, stretch, scratch, knead, rollOver, loaf, pounce, leap, tailChase

    init(_ state: PetState) {
        switch state {
        case .idle: self = .idle
        case .walkLeft, .walkRight: self = .walk
        case .sit: self = .sit
        case .sleep: self = .sleep
        case .waking: self = .waking
        case .curious: self = .curious
        case .startled: self = .startled
        case .annoyed: self = .annoyed
        case .dragged: self = .drag
        case .falling: self = .fall
        case .happy: self = .happy
        case .petted: self = .petted
        case .yawn: self = .yawn
        case .groom: self = .groom
        case .eating: self = .eat
        case .stretch: self = .stretch
        case .scratch: self = .scratch
        case .knead: self = .knead
        case .rollOver: self = .rollOver
        case .loaf: self = .loaf
        case .pounceCrouch: self = .pounce
        case .leaping: self = .leap
        case .tailChase: self = .tailChase
        }
    }

    init(_ key: AnimationKey) {
        switch key {
        case .idle: self = .idle
        case .walk: self = .walk
        case .sit: self = .sit
        case .sleep: self = .sleep
        case .drag: self = .drag
        case .fall: self = .fall
        case .happy: self = .happy
        case .petted: self = .petted
        case .yawn: self = .yawn
        case .groom: self = .groom
        case .eat: self = .eat
        case .stretch: self = .stretch
        case .scratch: self = .scratch
        case .knead: self = .knead
        case .rollOver: self = .rollOver
        case .loaf: self = .loaf
        case .pounce: self = .pounce
        case .leap: self = .leap
        case .tailChase: self = .tailChase
        }
    }
}

/// Keyframed rig poses with timings in seconds. A clip either plays once and holds its last key,
/// or plays an intro and then cycles from `loopStart` back around.
struct AnimeClip {
    typealias Pose = AnimeCatFactory.RigPose

    enum Easing { case linear, smooth }

    var keys: [Pose]
    /// Seconds from each key to the next. A looping clip has one more: from the last key back to
    /// `loopStart`.
    var durations: [TimeInterval]
    var loopStart: Int?
    var easing: Easing = .smooth

    init(_ keys: [Pose], durations: [TimeInterval], loopStart: Int? = nil, easing: Easing = .smooth) {
        precondition(!keys.isEmpty)
        precondition(durations.count == (loopStart == nil ? keys.count - 1 : keys.count))
        self.keys = keys
        self.durations = durations
        self.loopStart = loopStart
        self.easing = easing
    }

    static func hold(_ pose: Pose) -> AnimeClip {
        AnimeClip([pose], durations: [])
    }

    var loops: Bool { loopStart != nil }

    /// Length of a one-shot clip, or of the intro plus one cycle of a looping clip.
    var length: TimeInterval { durations.reduce(0, +) }

    /// How much to export as sprite frames: one full play, capped for long ambient loops.
    var exportLength: TimeInterval { min(max(length, 1), 4) }

    func sample(at time: TimeInterval) -> Pose {
        guard keys.count > 1 else { return keys[0] }
        var time = max(0, time)
        if let loopStart {
            let intro = durations[..<loopStart].reduce(0, +)
            let cycle = durations[loopStart...].reduce(0, +)
            if time >= intro, cycle > 0 {
                time = intro + (time - intro).truncatingRemainder(dividingBy: cycle)
            }
        } else if time >= length {
            return keys[keys.count - 1]
        }
        var start: TimeInterval = 0
        for (index, duration) in durations.enumerated() {
            if time < start + duration || index == durations.count - 1 {
                let from = keys[index]
                let to = index + 1 < keys.count ? keys[index + 1] : keys[loopStart ?? 0]
                let t = duration > 0 ? CGFloat(min(1, max(0, (time - start) / duration))) : 1
                return AnimeCatFactory.mix(from, to, easing == .smooth ? t * t * (3 - 2 * t) : t)
            }
            start += duration
        }
        return keys[keys.count - 1]
    }
}

enum AnimeCatClips {
    typealias Pose = AnimeCatFactory.RigPose
    private static let ground = AnimeCatFactory.ground

    static func clip(for motion: AnimeMotion) -> AnimeClip {
        switch motion {
        case .idle:
            // Small, slow shifts of weight; breathing, blinks, and glances come from the animator.
            var shift = Pose()
            shift.hip.y -= 0.3
            shift.shoulder.y += 0.15
            shift.head = CGPoint(x: 47.8, y: 32.8)
            shift.headTilt = 3
            shift.tail2 = CGVector(dx: -13, dy: 9)
            shift.tailTip = CGVector(dx: -11, dy: 18)
            var settle = Pose()
            settle.head = CGPoint(x: 47.3, y: 32.2)
            settle.headTilt = -2
            settle.earSpread = 3
            settle.tailTip = CGVector(dx: -7, dy: 19.5)
            return AnimeClip([Pose(), shift, settle], durations: [2.6, 2.4, 2.8], loopStart: 0)
        case .walk:
            let frames = walkCycle()
            return AnimeClip(frames, durations: Array(repeating: 1 / walkFramesPerSecond, count: frames.count), loopStart: 0, easing: .linear)
        case .sit:
            var lean = sitting
            lean.headTilt = 4
            lean.head.x += 0.3
            lean.tailTip.dy += 1.2
            return AnimeClip([sitting, lean], durations: [3, 3.4], loopStart: 0)
        case .sleep:
            var nestle = curled
            nestle.head.y += 0.25
            nestle.headTilt = -10
            nestle.tailTip.dx -= 0.6
            return AnimeClip([curled, nestle], durations: [5, 5], loopStart: 0)
        case .waking:
            var stir = curled
            stir.head.y += 1.2
            stir.headTilt = -6
            stir.earSpread = 16
            var raise = loafing
            raise.head = CGPoint(x: 45, y: 22)
            raise.headTilt = 6
            raise.eyes = .open
            raise.lid = 0.9
            raise.earSpread = 12
            var look = raise
            look.headTilt = 2
            look.lid = 0.68
            look.earSpread = 4
            return AnimeClip([curled, stir, raise, look], durations: [0.5, 0.6, 0.6])
        case .curious:
            var attend = Pose()
            attend.shoulder = CGPoint(x: 39.5, y: 22)
            attend.head = CGPoint(x: 49, y: 34)
            attend.headTilt = 9
            attend.earSpread = -10
            attend.wide = 0.5
            attend.tail1 = CGVector(dx: -6, dy: 4)
            attend.tail2 = CGVector(dx: -9, dy: 14)
            attend.tailTip = CGVector(dx: -4, dy: 20)
            var tilt = attend
            tilt.headTilt = 14
            tilt.head.x += 0.4
            tilt.earSpread = -13
            return AnimeClip([attend, tilt], durations: [0.9, 1.1], loopStart: 0)
        case .startled:
            var flinch = Pose()
            flinch.hip = CGPoint(x: 18, y: 23.5)
            flinch.shoulder = CGPoint(x: 37, y: 24)
            flinch.arch = 4.2
            flinch.sag = 0
            flinch.head = CGPoint(x: 45.5, y: 35.8)
            flinch.headTilt = 6
            flinch.earSpread = 30
            flinch.earTilt = 18
            flinch.wide = 1
            flinch.mouth = .open
            flinch.lift = 2.6
            flinch.frontNear.x -= 1
            flinch.frontFar.x -= 1
            flinch.tail1 = CGVector(dx: -5, dy: 5)
            flinch.tail2 = CGVector(dx: -7, dy: 13)
            flinch.tailTip = CGVector(dx: -5, dy: 20)
            var hold = flinch
            hold.lift = 0.6
            hold.mouth = .closed
            var settle = Pose()
            settle.arch = 1.5
            settle.earSpread = 10
            settle.earTilt = 5
            settle.wide = 0.5
            return AnimeClip([Pose(), flinch, hold, settle, Pose()], durations: [0.08, 0.25, 0.4, 0.3])
        case .annoyed:
            var sulk = Pose()
            sulk.hip.y = 20.5
            sulk.shoulder.y = 20
            sulk.head = CGPoint(x: 47.5, y: 31)
            sulk.headTilt = -6
            sulk.earSpread = 28
            sulk.earTilt = 10
            sulk.lid = 0.5
            sulk.look = CGVector(dx: 0.9, dy: -0.2)
            sulk.tail1 = CGVector(dx: -7, dy: -0.5)
            sulk.tail2 = CGVector(dx: -13, dy: 0.5)
            sulk.tailTip = CGVector(dx: -18, dy: 4)
            var huff = sulk
            huff.headTilt = -3
            huff.look = CGVector(dx: 0.6, dy: -0.1)
            huff.earSpread = 24
            return AnimeClip([sulk, huff], durations: [0.9, 0.9], loopStart: 0)
        case .drag:
            var sway = dangling
            sway.frontNear.x += 1.5
            sway.frontFar.x += 1.2
            sway.backNear.x += 1.5
            sway.backFar.x += 1
            sway.tailTip.dx += 2
            sway.earSpread += 6
            return AnimeClip([dangling, sway], durations: [0.33, 0.33], loopStart: 0)
        case .fall:
            var flail = falling
            flail.frontNear.y += 1.5
            flail.frontFar.y -= 1
            flail.backNear.y -= 1
            flail.backFar.y += 1.5
            flail.tailTip.dx -= 2
            flail.earSpread += 10
            return AnimeClip([falling, flail], durations: [0.25, 0.25], loopStart: 0)
        case .happy:
            var stand = Pose()
            stand.eyes = .happy
            stand.mouth = .open
            stand.blush = 1
            stand.tail2 = CGVector(dx: -10, dy: 12)
            stand.tailTip = CGVector(dx: -6, dy: 21)
            var crouch = stand
            crouch.hip.y = 18.8
            crouch.shoulder.y = 18.8
            crouch.head.y = 29
            crouch.arch = 0
            crouch.earSpread = 10
            var air = stand
            air.earSpread = -10
            air.lift = 5
            air.hip.y = 22
            air.shoulder.y = 22.5
            air.head.y = 33
            air.frontNear = CGPoint(x: 43, y: 9)
            air.frontFar = CGPoint(x: 39.5, y: 9.5)
            air.backNear = CGPoint(x: 18.5, y: 10)
            air.backFar = CGPoint(x: 15, y: 10.5)
            air.tailTip = CGVector(dx: -4, dy: 22)
            return AnimeClip([stand, crouch, air, crouch], durations: [0.14, 0.16, 0.16, 0.14], loopStart: 0)
        case .petted:
            var nuzzle = Pose()
            nuzzle.headTilt = 14
            nuzzle.earSpread = 26
            nuzzle.eyes = .closed
            nuzzle.blush = 1
            nuzzle.tailTip = CGVector(dx: -4, dy: 20)
            var lean = nuzzle
            lean.head.x += 0.6
            lean.shoulder.x += 0.4
            lean.earSpread = 32
            lean.headTilt = 18
            lean.tail2 = CGVector(dx: -13, dy: 8)
            lean.tailTip = CGVector(dx: -11, dy: 17)
            return AnimeClip([nuzzle, lean], durations: [0.8, 0.8], loopStart: 0)
        case .yawn:
            var start = Pose()
            start.headTilt = 10
            start.lid = 0.75
            start.mouth = .open
            start.earSpread = 10
            var wide = Pose()
            wide.head = CGPoint(x: 48, y: 33.5)
            wide.headTilt = 22
            wide.earSpread = 24
            wide.eyes = .closed
            wide.mouth = .wide
            wide.frontNear.x = 43
            var close = Pose()
            close.lid = 0.7
            return AnimeClip([Pose(), start, wide, wide, close], durations: [0.3, 0.2, 0.3, 0.3])
        case .groom:
            // The paw comes up under the chin and the head bows to lick it. The paw stays below
            // the mouth: at this size a paw over the muzzle reads as a smudge across the face.
            var raise = sitting
            raise.pawToFace = true
            raise.frontNear = CGPoint(x: 43, y: 15.5)
            raise.head = CGPoint(x: 43.5, y: 32)
            raise.headTilt = -8
            raise.lid = 0.3
            raise.look = CGVector(dx: 0.3, dy: -0.9)
            var lick = sitting
            lick.pawToFace = true
            lick.head = CGPoint(x: 42.5, y: 30)
            lick.headTilt = -18
            lick.earSpread = 6
            lick.eyes = .closed
            lick.mouth = .tongue
            lick.frontNear = CGPoint(x: 43.5, y: 18)
            var lower = lick
            lower.frontNear = CGPoint(x: 43.8, y: 17.2)
            lower.head.y -= 0.6
            lower.headTilt = -20
            var pause = lick
            pause.mouth = .closed
            pause.frontNear = CGPoint(x: 44.5, y: 16.5)
            pause.head = CGPoint(x: 43, y: 31.5)
            pause.headTilt = -10
            pause.earSpread = 14
            return AnimeClip([sitting, raise, lick, lower, lick, lower, lick, pause], durations: [0.45, 0.3, 0.2, 0.2, 0.2, 0.2, 0.35, 0.4], loopStart: 2)
        case .eat:
            var chew = Pose()
            chew.shoulder.y = 19.5
            chew.head = CGPoint(x: 47, y: 17)
            chew.headTilt = -22
            chew.eyes = .happy
            chew.mouth = .open
            chew.earSpread = 6
            var bite = chew
            bite.mouth = .closed
            bite.head.y += 0.6
            bite.earSpread = 12
            bite.tailTip = CGVector(dx: -11, dy: 18)
            return AnimeClip([chew, bite], durations: [0.45, 0.45], loopStart: 0)
        case .stretch:
            var bow = Pose()
            bow.shoulder = CGPoint(x: 40, y: 13.5)
            bow.hip = CGPoint(x: 21, y: 23)
            bow.arch = -1.5
            bow.head = CGPoint(x: 48.5, y: 20.5)
            bow.headTilt = -6
            bow.earSpread = 20
            bow.eyes = .closed
            bow.mouth = .wide
            bow.frontNear = CGPoint(x: 55, y: ground)
            bow.frontFar = CGPoint(x: 52, y: ground)
            bow.backNear = CGPoint(x: 21.5, y: ground)
            bow.backFar = CGPoint(x: 18, y: ground)
            bow.tail1 = CGVector(dx: -4, dy: 4)
            bow.tail2 = CGVector(dx: -7, dy: 12)
            bow.tailTip = CGVector(dx: -3, dy: 20)
            var deeper = bow
            deeper.arch = -2.5
            deeper.shoulder.y -= 0.6
            deeper.head.y -= 0.6
            var forward = Pose()
            forward.shoulder = CGPoint(x: 41, y: 21)
            forward.hip = CGPoint(x: 26, y: 18.5)
            forward.head = CGPoint(x: 49.5, y: 30.5)
            forward.lid = 0.78
            forward.frontNear = CGPoint(x: 44, y: ground)
            forward.frontFar = CGPoint(x: 41, y: ground)
            forward.backNear = CGPoint(x: 10, y: 7.5)
            forward.backFar = CGPoint(x: 22, y: ground)
            forward.tail1 = CGVector(dx: -6, dy: 1)
            forward.tail2 = CGVector(dx: -11, dy: 5)
            forward.tailTip = CGVector(dx: -13, dy: 10)
            var settle = Pose()
            settle.head.y -= 0.4
            return AnimeClip([Pose(), bow, deeper, forward, settle], durations: [0.5, 0.4, 0.5, 0.45])
        case .scratch:
            var scratch = sitting
            scratch.hip = CGPoint(x: 22, y: 12)
            scratch.shoulder = CGPoint(x: 35, y: 21.5)
            scratch.head = CGPoint(x: 40.5, y: 29)
            scratch.headTilt = -20
            scratch.earSpread = 8
            scratch.eyes = .closed
            scratch.scratching = true
            scratch.frontNear = CGPoint(x: 38.5, y: ground)
            scratch.frontFar = CGPoint(x: 35.5, y: ground)
            let paws = [CGPoint(x: 31, y: 22.5), CGPoint(x: 32, y: 24.5), CGPoint(x: 31.3, y: 23), CGPoint(x: 32.3, y: 24.8)]
            let keys = paws.enumerated().map { index, paw in
                var pose = scratch
                pose.backNear = paw
                pose.earTwitchRight = index % 2 == 0 ? 26 : 36
                return pose
            }
            return AnimeClip(keys, durations: [0.07, 0.07, 0.07, 0.07], loopStart: 0)
        case .knead:
            var press = Pose()
            press.hip = CGPoint(x: 20, y: 19.5)
            press.shoulder = CGPoint(x: 39, y: 17.5)
            press.head = CGPoint(x: 47.5, y: 27.5)
            press.eyes = .half
            press.earSpread = 14
            press.blush = 1
            press.tail1 = CGVector(dx: -6, dy: 3)
            press.tail2 = CGVector(dx: -9, dy: 12)
            press.tailTip = CGVector(dx: -5, dy: 20)
            var nearUp = press
            nearUp.frontNear = CGPoint(x: 43.5, y: 9.5)
            nearUp.frontFar = CGPoint(x: 39, y: ground)
            var down = press
            down.frontNear = CGPoint(x: 42.5, y: ground)
            down.frontFar = CGPoint(x: 39.5, y: ground)
            var farUp = press
            farUp.frontNear = CGPoint(x: 42.5, y: ground)
            farUp.frontFar = CGPoint(x: 40.5, y: 9.5)
            return AnimeClip([nearUp, down, farUp, down], durations: [0.33, 0.33, 0.33, 0.33], loopStart: 0)
        case .rollOver:
            // Belly up, head tipped back on the floor, curled kitten paws batting at the air.
            var belly = Pose()
            belly.upsideDown = true
            belly.hip = CGPoint(x: 16, y: 12.5)
            belly.shoulder = CGPoint(x: 32, y: 13)
            belly.arch = 1
            belly.sag = 0
            belly.head = CGPoint(x: 43.5, y: 16.5)
            belly.headTilt = -18
            belly.earSpread = 16
            belly.look = CGVector(dx: -0.6, dy: 0.6)
            belly.blush = 1
            belly.mouth = .open
            belly.frontNear = CGPoint(x: 35, y: 26)
            belly.frontFar = CGPoint(x: 29, y: 28)
            belly.backNear = CGPoint(x: 19, y: 25.5)
            belly.backFar = CGPoint(x: 14.5, y: 27)
            belly.tail1 = CGVector(dx: -4, dy: 0)
            belly.tail2 = CGVector(dx: -8, dy: 3)
            belly.tailTip = CGVector(dx: -7, dy: 8)
            var batNear = belly
            batNear.frontNear = CGPoint(x: 37.5, y: 28.5)
            batNear.backFar = CGPoint(x: 12.5, y: 28.5)
            batNear.headTilt = -12
            batNear.tailTip = CGVector(dx: -9, dy: 6)
            batNear.hip.y += 0.5
            var happy = belly
            happy.eyes = .happy
            happy.headTilt = -22
            happy.earSpread = 22
            happy.tailTip = CGVector(dx: -5, dy: 9)
            var batFar = belly
            batFar.frontFar = CGPoint(x: 31, y: 30.5)
            batFar.backNear = CGPoint(x: 21.5, y: 28)
            batFar.headTilt = -14
            batFar.look = CGVector(dx: -0.3, dy: 0.8)
            batFar.tailTip = CGVector(dx: -9, dy: 7)
            batFar.shoulder.y += 0.5
            return AnimeClip([belly, batNear, happy, batFar], durations: [0.5, 0.5, 0.5, 0.5], loopStart: 0)
        case .loaf:
            var nod = loafing
            nod.head.y -= 0.5
            nod.headTilt = -4
            nod.lid = 0.8
            return AnimeClip([loafing, nod], durations: [3.5, 3.5], loopStart: 0)
        case .pounce:
            var crouch = Pose()
            crouch.hip = CGPoint(x: 21, y: 15)
            crouch.shoulder = CGPoint(x: 39, y: 14)
            crouch.arch = 0.5
            crouch.head = CGPoint(x: 48, y: 19.5)
            crouch.headTilt = -4
            crouch.earSpread = -12
            crouch.wide = 1
            crouch.look = CGVector(dx: 0.9, dy: -0.2)
            crouch.frontNear = CGPoint(x: 47, y: ground)
            crouch.frontFar = CGPoint(x: 44.5, y: ground)
            crouch.backNear = CGPoint(x: 24, y: ground)
            crouch.backFar = CGPoint(x: 21, y: ground)
            crouch.tail1 = CGVector(dx: -6, dy: -1)
            crouch.tail2 = CGVector(dx: -10, dy: 1)
            crouch.tailTip = CGVector(dx: -12, dy: 6)
            var wiggle = crouch
            wiggle.hip.x += 1.2
            wiggle.hip.y += 0.5
            wiggle.tailTip = CGVector(dx: -10, dy: 9)
            wiggle.earTwitchRight = 10
            return AnimeClip([crouch, wiggle], durations: [0.2, 0.2], loopStart: 0)
        case .leap:
            var flight = Pose()
            flight.hip = CGPoint(x: 17, y: 21)
            flight.shoulder = CGPoint(x: 37, y: 28)
            flight.head = CGPoint(x: 44.5, y: 36)
            flight.headTilt = 8
            flight.wide = 1
            flight.look = CGVector(dx: 0.9, dy: -0.3)
            flight.earSpread = 22
            flight.mouth = .open
            flight.showShadow = false
            flight.frontNear = CGPoint(x: 55, y: 21.5)
            flight.frontFar = CGPoint(x: 53, y: 20)
            flight.backNear = CGPoint(x: 6, y: 13)
            flight.backFar = CGPoint(x: 9, y: 11.5)
            flight.tail1 = CGVector(dx: -5, dy: 0.5)
            flight.tail2 = CGVector(dx: -8, dy: 1.5)
            flight.tailTip = CGVector(dx: -10, dy: 3.5)
            var reach = flight
            reach.frontNear.y += 1
            reach.frontFar.y += 1
            reach.tailTip.dy += 1.5
            return AnimeClip([flight, reach], durations: [0.25, 0.25], loopStart: 0)
        case .tailChase:
            var chase = Pose()
            chase.headTurnedBack = true
            chase.head = CGPoint(x: 41, y: 30.5)
            chase.wide = 1
            chase.look = CGVector(dx: 0.8, dy: -0.4)
            chase.earSpread = -8
            chase.mouth = .open
            chase.tail1 = CGVector(dx: -3, dy: 7)
            chase.tail2 = CGVector(dx: 4, dy: 15)
            chase.tailTip = CGVector(dx: 12, dy: 13)
            let hops: [CGFloat] = [0, 2.5, 1, 0, 0, 2.5, 1, 0]
            let keys = hops.enumerated().map { index, hop in
                var pose = chase
                pose.flipped = (index / 2) % 2 == 1
                pose.lift = hop
                if hop > 0 {
                    pose.frontNear.y += 1.5
                    pose.backFar.y += 1.5
                }
                return pose
            }
            return AnimeClip(keys, durations: Array(repeating: 0.1, count: keys.count), loopStart: 0)
        }
    }

    // MARK: - Base poses

    static var sitting: Pose {
        var pose = Pose()
        pose.hip = CGPoint(x: 22, y: 11.5)
        pose.shoulder = CGPoint(x: 36, y: 22)
        pose.arch = 0
        pose.head = CGPoint(x: 44, y: 33.5)
        pose.hindFolded = true
        pose.tailInFront = true
        pose.frontNear = CGPoint(x: 39.5, y: ground)
        pose.frontFar = CGPoint(x: 36.5, y: ground)
        pose.backNear = CGPoint(x: 29, y: ground)
        pose.backFar = CGPoint(x: 26, y: ground)
        pose.tail1 = CGVector(dx: -4, dy: -1.5)
        pose.tail2 = CGVector(dx: 6, dy: -2.5)
        pose.tailTip = CGVector(dx: 22, dy: -1.8)
        return pose
    }

    static var curled: Pose {
        var pose = Pose()
        pose.hip = CGPoint(x: 25, y: 11.5)
        pose.shoulder = CGPoint(x: 36, y: 12)
        pose.arch = 2
        pose.sag = 0
        pose.head = CGPoint(x: 43.5, y: 13.5)
        pose.headTilt = -12
        pose.earSpread = 22
        pose.eyes = .closed
        pose.hindFolded = true
        pose.frontTucked = true
        pose.tailInFront = true
        pose.backNear = CGPoint(x: 31, y: ground)
        pose.backFar = CGPoint(x: 28, y: ground)
        pose.tail1 = CGVector(dx: -3, dy: -5)
        pose.tail2 = CGVector(dx: 10, dy: -6.5)
        pose.tailTip = CGVector(dx: 24, dy: -5.5)
        return pose
    }

    static var loafing: Pose {
        var pose = curled
        pose.hip = CGPoint(x: 24, y: 12.5)
        pose.shoulder = CGPoint(x: 37, y: 13.5)
        pose.arch = 1.5
        pose.head = CGPoint(x: 45, y: 23)
        pose.headTilt = 0
        pose.earSpread = 8
        pose.eyes = .open
        pose.lid = 0.72
        pose.tail1 = CGVector(dx: -3, dy: -5.5)
        pose.tail2 = CGVector(dx: 10, dy: -7.5)
        pose.tailTip = CGVector(dx: 22, dy: -7)
        return pose
    }

    private static var dangling: Pose {
        var pose = Pose()
        pose.hip = CGPoint(x: 30, y: 19.5)
        pose.shoulder = CGPoint(x: 33, y: 35.5)
        pose.arch = 0
        pose.head = CGPoint(x: 35, y: 44)
        pose.headTilt = 4
        pose.earSpread = 30
        pose.wide = 1
        pose.mouth = .open
        pose.showShadow = false
        pose.frontNear = CGPoint(x: 37, y: 27)
        pose.frontFar = CGPoint(x: 35, y: 28.5)
        pose.backNear = CGPoint(x: 33, y: 7.5)
        pose.backFar = CGPoint(x: 29.5, y: 8.5)
        pose.tail1 = CGVector(dx: 0.5, dy: -4)
        pose.tail2 = CGVector(dx: -1.5, dy: -8)
        pose.tailTip = CGVector(dx: -0.5, dy: -11)
        return pose
    }

    private static var falling: Pose {
        var pose = Pose()
        pose.hip = CGPoint(x: 21, y: 26)
        pose.shoulder = CGPoint(x: 40, y: 27)
        pose.head = CGPoint(x: 48.5, y: 35)
        pose.headTilt = 6
        pose.earSpread = 24
        pose.wide = 1
        pose.mouth = .open
        pose.showShadow = false
        pose.frontNear = CGPoint(x: 49, y: 16)
        pose.frontFar = CGPoint(x: 46, y: 15)
        pose.backNear = CGPoint(x: 13, y: 16)
        pose.backFar = CGPoint(x: 16, y: 14.5)
        pose.tail1 = CGVector(dx: -4, dy: 4)
        pose.tail2 = CGVector(dx: -6, dy: 10)
        pose.tailTip = CGVector(dx: -3, dy: 16)
        return pose
    }

    // MARK: - Walk

    /// Canvas units per second the pet moves at Normal speed (45 points at the 96-point size).
    private static let walkSpeed: Double = 30
    private static let walkStride: Double = 9
    /// Share of the cycle each paw spends planted on the ground.
    private static let walkDuty: Double = 0.6
    private static let walkFrames = 10

    /// Plays the walk so a planted paw slides back exactly as fast as the pet walks forward.
    static let walkFramesPerSecond = Double(walkFrames) * walkSpeed / (walkStride / walkDuty)

    /// Short, quick kitten steps. Paws step in a lateral sequence: back, front, other back,
    /// other front.
    private static func walkCycle() -> [Pose] {
        let base = Pose()
        let stride = CGFloat(walkStride), duty = CGFloat(walkDuty)
        func paw(_ rest: CGPoint, phase: CGFloat, lift: CGFloat) -> CGPoint {
            let q = phase - floor(phase)
            if q < duty {
                return CGPoint(x: rest.x + stride / 2 - stride * q / duty, y: ground)
            }
            let s = (q - duty) / (1 - duty)
            let eased = s * s * (3 - 2 * s)
            return CGPoint(x: rest.x - stride / 2 + stride * eased, y: ground + lift * sin(.pi * pow(s, 0.8)))
        }
        return (0..<walkFrames).map { index in
            let phase = CGFloat(index) / CGFloat(walkFrames)
            var pose = base
            pose.look = CGVector(dx: 0.6, dy: 0)
            pose.earSpread = 4 * sin(4 * .pi * phase + 1)
            pose.hip.y += 0.35 * cos(4 * .pi * phase)
            pose.shoulder.y += 0.35 * cos(4 * .pi * phase + 1.6)
            pose.head.y += 0.4 * cos(4 * .pi * phase + 2.2)
            pose.headTilt = 1.5 * sin(2 * .pi * phase)
            pose.backNear = paw(base.backNear, phase: phase, lift: 2.6)
            pose.frontNear = paw(base.frontNear, phase: phase + 0.25, lift: 3)
            pose.backFar = paw(base.backFar, phase: phase + 0.5, lift: 2.6)
            pose.frontFar = paw(base.frontFar, phase: phase + 0.75, lift: 3)
            pose.tail2.dx += 0.8 * sin(2 * .pi * phase + 0.6)
            pose.tailTip.dx += 1.8 * sin(2 * .pi * phase)
            return pose
        }
    }
}

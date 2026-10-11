import AppKit

/// An anime kitten built on a small rig: a chubby torso between hip and shoulder joints, a big
/// three-quarter head with glossy eyes and fluffy cheeks, four two-segment legs whose knees are
/// solved from the paw positions, and a fluffy tail. Animations are keyframed rig poses eased
/// into in-between frames.
/// All geometry is on the same 64x64 unit canvas as the cartoon cat, facing right.
enum AnimeCatFactory {
    enum Eyes { case open, half, closed, happy, wide }
    enum Mouth { case closed, open, wide, tongue }

    /// Paws are placed directly and the knees solved; tail points are relative to its base.
    struct RigPose {
        var hip = CGPoint(x: 20, y: 21)
        var shoulder = CGPoint(x: 39, y: 21)
        /// Extra curve along the back and the belly.
        var arch: CGFloat = 1
        var sag: CGFloat = 0.5
        var head = CGPoint(x: 47.5, y: 32.5)
        /// Degrees counter-clockwise; negative looks down.
        var headTilt: CGFloat = 0
        /// Degrees; positive folds both ears back.
        var earTilt: CGFloat = 0
        /// Degrees each ear swings outward: flattened when scared or blissful, negative to perk up.
        var earSpread: CGFloat = 0
        /// Degrees the right ear flicks outward on its own.
        var earTwitch: CGFloat = 0
        var frontNear = CGPoint(x: 41.5, y: ground)
        var frontFar = CGPoint(x: 37.5, y: ground)
        var backNear = CGPoint(x: 22.5, y: ground)
        var backFar = CGPoint(x: 18.5, y: ground)
        /// -1 points the elbows back like a real cat's; 1 bends them forward.
        var frontBend: CGFloat = -1
        var tail1 = CGVector(dx: -7, dy: 1)
        var tail2 = CGVector(dx: -12, dy: 10)
        var tailTip = CGVector(dx: -9, dy: 19)
        /// Raises the whole cat off the ground (the shadow stays put).
        var lift: CGFloat = 0
        var eyes: Eyes = .open
        /// How far open eyes are lidded, 0 to 1: the in-between frames of a blink.
        var lid: CGFloat = 0
        /// Where the pupils look, about -1...1 each way.
        var look = CGVector.zero
        var mouth: Mouth = .closed
        /// Hind legs folded under the haunch, as when sitting or lying down.
        var hindFolded = false
        /// The near hind leg reaches up to scratch even while folded.
        var scratching = false
        /// Front legs tucked under the chest.
        var frontTucked = false
        var tailInFront = false
        /// Lying on its back: belly and paws up.
        var upsideDown = false
        var headTurnedBack = false
        var flipped = false
        var blush = false
        var showShadow = true
        var zCount = 0
    }

    static let ground: CGFloat = 6.3

    private static let canvas: CGFloat = 64
    private static let imageSize = NSSize(width: 128, height: 128)
    private static let line: CGFloat = 0.85
    private static let rumpRadius: CGFloat = 8
    private static let chestRadius: CGFloat = 7.4
    private static let headScale: CGFloat = 1.5
    private static let frontLengths: (CGFloat, CGFloat) = (6.2, 6.6)
    /// Thigh, shin, and the long foot bone that ends at the hock.
    private static let hindLengths: (CGFloat, CGFloat, CGFloat) = (5.4, 5.4, 4.4)

    static func frames(for key: AnimationKey, palette: SpriteFactory.Palette) -> [NSImage] {
        poses(for: key).map { pose in
            NSImage(size: imageSize, flipped: false) { rect in
                draw(pose, palette: palette, in: rect)
                return true
            }
        }
    }

    static func framesPerSecond(for key: AnimationKey) -> Double {
        switch key {
        case .idle: 8
        case .walk: Double(walkFrames) * walkSpeed / (walkStride / walkDuty)
        case .sit: 4
        case .sleep: 2
        case .drag: 6
        case .fall: 8
        case .happy: 14
        case .petted: 5
        case .yawn: 10
        case .groom: 6
        case .eat: 8
        case .stretch: 10
        case .scratch: 14
        case .knead: 6
        case .rollOver: 6
        case .loaf: 4
        case .pounce: 10
        case .leap: 8
        case .tailChase: 10
        }
    }

    // MARK: - Animations

    static func poses(for key: AnimationKey) -> [RigPose] {
        switch key {
        case .idle:
            var breathe = RigPose()
            breathe.arch = 1.5
            breathe.head.y += 0.4
            breathe.tail2 = CGVector(dx: -13, dy: 9)
            breathe.tailTip = CGVector(dx: -11, dy: 18)
            breathe.look = CGVector(dx: 0.8, dy: 0.2)
            var sway = RigPose()
            sway.tailTip = CGVector(dx: -7, dy: 20)
            sway.look = CGVector(dx: -0.7, dy: 0)
            sway.headTilt = 3
            sway.earSpread = 4
            var frames = blink(tween([RigPose(), breathe, sway], steps: [4, 4, 4], loop: true), at: [10])
            frames[4].earTwitch = 30
            frames[5].earTwitch = 8
            frames[6].earTwitch = 22
            return frames
        case .walk:
            return walkCycle()
        case .sit:
            var twitch = sitting
            twitch.headTilt = 5
            twitch.tailTip.dy += 1.2
            twitch.look = CGVector(dx: 0.6, dy: 0.6)
            twitch.earSpread = -6
            var frames = blink(tween([sitting, twitch], steps: [4, 4], loop: true), at: [6])
            frames[2].earTwitch = 28
            frames[3].earTwitch = 6
            return frames
        case .sleep:
            var inhale = curled
            inhale.arch = 2.8
            inhale.head.y += 0.4
            let frames = tween([curled, inhale], steps: [3, 3], loop: true)
            return frames.enumerated().map { index, pose in
                var pose = pose
                pose.zCount = index / 2 + 1
                return pose
            }
        case .drag:
            var sway = dangling
            sway.frontNear.x += 1.5
            sway.frontFar.x += 1.2
            sway.backNear.x += 1.5
            sway.backFar.x += 1
            sway.tailTip.dx += 2
            sway.earSpread += 6
            return tween([dangling, sway], steps: [2, 2], loop: true)
        case .fall:
            var flail = falling
            flail.frontNear.y += 1.5
            flail.frontFar.y -= 1
            flail.backNear.y -= 1
            flail.backFar.y += 1.5
            flail.tailTip.dx -= 2
            flail.earSpread += 10
            return tween([falling, flail], steps: [2, 2], loop: true)
        case .happy:
            var stand = RigPose()
            stand.eyes = .happy
            stand.mouth = .open
            stand.blush = true
            var crouch = stand
            crouch.hip.y = 18.5
            crouch.shoulder.y = 18.5
            crouch.head.y = 28.5
            crouch.arch = 0
            crouch.earSpread = 12
            var air = stand
            air.earSpread = -10
            air.lift = 7
            air.hip.y = 22
            air.shoulder.y = 22.5
            air.head.y = 32.5
            air.frontNear = CGPoint(x: 43, y: 10)
            air.frontFar = CGPoint(x: 39.5, y: 10.5)
            air.backNear = CGPoint(x: 18, y: 11)
            air.backFar = CGPoint(x: 14.5, y: 11.5)
            air.tailTip = CGVector(dx: -5, dy: 22)
            return tween([stand, crouch, air, crouch], steps: [2, 2, 2, 2], loop: true)
        case .petted:
            var nuzzle = RigPose()
            nuzzle.head = CGPoint(x: 47.5, y: 32.5)
            nuzzle.headTilt = 14
            nuzzle.earSpread = 26
            nuzzle.eyes = .closed
            nuzzle.blush = true
            var curl = nuzzle
            curl.earSpread = 32
            curl.headTilt = 18
            curl.tail2 = CGVector(dx: -13, dy: 8)
            curl.tailTip = CGVector(dx: -11, dy: 17)
            nuzzle.tailTip = CGVector(dx: -4, dy: 20)
            return tween([nuzzle, curl], steps: [4, 4], loop: true)
        case .yawn:
            var start = RigPose()
            start.head = CGPoint(x: 47.5, y: 32.5)
            start.headTilt = 10
            start.eyes = .half
            start.mouth = .open
            var wide = RigPose()
            wide.head = CGPoint(x: 48, y: 33.5)
            wide.headTilt = 22
            wide.earSpread = 24
            wide.eyes = .closed
            wide.mouth = .wide
            wide.frontNear.x = 43
            return tween([RigPose(), start, wide, wide, RigPose()], steps: [3, 2, 3, 3], loop: false)
        case .groom:
            var lick = sitting
            lick.head = CGPoint(x: 42, y: 30.5)
            lick.headTilt = -14
            lick.earSpread = 8
            lick.eyes = .closed
            lick.mouth = .tongue
            lick.frontBend = -1
            lick.frontNear = CGPoint(x: 45.5, y: 26)
            var lower = lick
            lower.frontNear = CGPoint(x: 45, y: 24.5)
            lower.head.y += 0.6
            return tween([lick, lower], steps: [3, 3], loop: true)
        case .eat:
            var chew = RigPose()
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
            return tween([chew, bite], steps: [4, 4], loop: true)
        case .stretch:
            var bow = RigPose()
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
            var forward = RigPose()
            forward.shoulder = CGPoint(x: 41, y: 21)
            forward.hip = CGPoint(x: 26, y: 18.5)
            forward.head = CGPoint(x: 49.5, y: 30.5)
            forward.eyes = .half
            forward.frontNear = CGPoint(x: 44, y: ground)
            forward.frontFar = CGPoint(x: 41, y: ground)
            forward.backNear = CGPoint(x: 10, y: 7.5)
            forward.backFar = CGPoint(x: 22, y: ground)
            forward.tail1 = CGVector(dx: -6, dy: 1)
            forward.tail2 = CGVector(dx: -11, dy: 5)
            forward.tailTip = CGVector(dx: -13, dy: 10)
            return tween([RigPose(), bow, deeper, forward, RigPose()], steps: [5, 4, 5, 5], loop: false)
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
            return paws.enumerated().map { index, paw in
                var pose = scratch
                pose.backNear = paw
                pose.earTwitch = index % 2 == 0 ? 26 : 36
                return pose
            }
        case .knead:
            var press = RigPose()
            press.hip = CGPoint(x: 20, y: 19.5)
            press.shoulder = CGPoint(x: 39, y: 17.5)
            press.head = CGPoint(x: 47.5, y: 27.5)
            press.eyes = .half
            press.earSpread = 14
            press.blush = true
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
            return tween([nearUp, down, farUp, down], steps: [2, 2, 2, 2], loop: true)
        case .rollOver:
            // Belly up, head tipped back on the floor, curled kitten paws batting at the air.
            var belly = RigPose()
            belly.upsideDown = true
            belly.hip = CGPoint(x: 16, y: 12.5)
            belly.shoulder = CGPoint(x: 32, y: 13)
            belly.arch = 1
            belly.sag = 0
            belly.head = CGPoint(x: 43.5, y: 16.5)
            belly.headTilt = -18
            belly.earSpread = 16
            belly.look = CGVector(dx: -0.6, dy: 0.6)
            belly.blush = true
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
            return tween([belly, batNear, happy, batFar], steps: [3, 3, 3, 3], loop: true)
        case .loaf:
            var breathe = loafing
            breathe.arch = 2
            return blink(tween([loafing, breathe], steps: [6, 6], loop: true), at: [6, 7], eyes: .closed)
        case .pounce:
            var crouch = RigPose()
            crouch.hip = CGPoint(x: 21, y: 15)
            crouch.shoulder = CGPoint(x: 39, y: 14)
            crouch.arch = 0.5
            crouch.head = CGPoint(x: 48, y: 19.5)
            crouch.headTilt = -4
            crouch.earSpread = -12
            crouch.eyes = .wide
            crouch.look = CGVector(dx: 0.9, dy: -0.2)
            crouch.frontBend = -1
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
            wiggle.earTwitch = 10
            return tween([crouch, wiggle], steps: [2, 2], loop: true)
        case .leap:
            var flight = RigPose()
            flight.hip = CGPoint(x: 17, y: 21)
            flight.shoulder = CGPoint(x: 37, y: 28)
            flight.head = CGPoint(x: 44.5, y: 36)
            flight.headTilt = 8
            flight.eyes = .wide
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
            return tween([flight, reach], steps: [2, 2], loop: true)
        case .tailChase:
            var chase = RigPose()
            chase.headTurnedBack = true
            chase.head = CGPoint(x: 41, y: 30.5)
            chase.eyes = .wide
            chase.look = CGVector(dx: 0.8, dy: -0.4)
            chase.earSpread = -8
            chase.mouth = .open
            chase.tail1 = CGVector(dx: -3, dy: 7)
            chase.tail2 = CGVector(dx: 4, dy: 15)
            chase.tailTip = CGVector(dx: 12, dy: 13)
            let hops: [CGFloat] = [0, 2.5, 1, 0, 0, 2.5, 1, 0]
            return hops.enumerated().map { index, hop in
                var pose = chase
                pose.flipped = (index / 2) % 2 == 1
                pose.lift = hop
                if hop > 0 {
                    pose.frontNear.y += 1.5
                    pose.backFar.y += 1.5
                }
                return pose
            }
        }
    }

    private static var sitting: RigPose {
        var pose = RigPose()
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

    private static var curled: RigPose {
        var pose = RigPose()
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

    private static var loafing: RigPose {
        var pose = curled
        pose.hip = CGPoint(x: 24, y: 12.5)
        pose.shoulder = CGPoint(x: 37, y: 13.5)
        pose.arch = 1.5
        pose.head = CGPoint(x: 45, y: 23)
        pose.headTilt = 0
        pose.earSpread = 8
        pose.eyes = .half
        pose.tail1 = CGVector(dx: -3, dy: -5.5)
        pose.tail2 = CGVector(dx: 10, dy: -7.5)
        pose.tailTip = CGVector(dx: 22, dy: -7)
        return pose
    }

    private static var dangling: RigPose {
        var pose = RigPose()
        pose.hip = CGPoint(x: 30, y: 19.5)
        pose.shoulder = CGPoint(x: 33, y: 35.5)
        pose.arch = 0
        pose.head = CGPoint(x: 35, y: 44)
        pose.headTilt = 4
        pose.earSpread = 30
        pose.eyes = .wide
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

    private static var falling: RigPose {
        var pose = RigPose()
        pose.hip = CGPoint(x: 21, y: 26)
        pose.shoulder = CGPoint(x: 40, y: 27)
        pose.head = CGPoint(x: 48.5, y: 35)
        pose.headTilt = 6
        pose.earSpread = 24
        pose.eyes = .wide
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

    /// Canvas units per second the pet moves at Normal speed (45 points at the 96-point size).
    private static let walkSpeed: Double = 30
    private static let walkStride: Double = 9
    /// Share of the cycle each paw spends planted on the ground.
    private static let walkDuty: Double = 0.6
    private static let walkFrames = 10

    /// Short, quick kitten steps. A planted paw slides back exactly as fast as the pet walks
    /// forward (see the walk's frame rate), so it stays put on the screen. Paws step in a lateral
    /// sequence: back, front, other back, other front.
    private static func walkCycle() -> [RigPose] {
        let base = RigPose()
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

    /// Eases between keyframes, `steps[i]` frames from key `i` to the next. A one-shot
    /// sequence also ends on its last key.
    private static func tween(_ keys: [RigPose], steps: [Int], loop: Bool) -> [RigPose] {
        var frames: [RigPose] = []
        let segments = loop ? keys.count : keys.count - 1
        for i in 0..<segments {
            let from = keys[i], to = keys[(i + 1) % keys.count]
            for step in 0..<steps[i] {
                let t = CGFloat(step) / CGFloat(steps[i])
                frames.append(mix(from, to, t * t * (3 - 2 * t)))
            }
        }
        if !loop, let last = keys.last { frames.append(last) }
        return frames
    }

    /// Closes the eyes on the given frames, half-lidding open eyes on the frames either side so
    /// the blink eases shut and open again.
    private static func blink(_ frames: [RigPose], at indices: [Int], eyes: Eyes = .closed) -> [RigPose] {
        var frames = frames
        for index in indices where frames.indices.contains(index) {
            let wasOpen = frames[index].eyes == .open || frames[index].eyes == .wide
            frames[index].eyes = eyes
            guard wasOpen, eyes == .closed else { continue }
            for neighbor in [index - 1, index + 1] where frames.indices.contains(neighbor) && !indices.contains(neighbor) {
                frames[neighbor].lid = max(frames[neighbor].lid, 0.4)
            }
        }
        return frames
    }

    /// Continuous values blend; switches like eye shape take whichever key is closer.
    private static func mix(_ a: RigPose, _ b: RigPose, _ t: CGFloat) -> RigPose {
        func blend(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * t }
        func blend(_ p: CGPoint, _ q: CGPoint) -> CGPoint { CGPoint(x: blend(p.x, q.x), y: blend(p.y, q.y)) }
        func blend(_ v: CGVector, _ w: CGVector) -> CGVector { CGVector(dx: blend(v.dx, w.dx), dy: blend(v.dy, w.dy)) }
        var pose = t < 0.5 ? a : b
        pose.hip = blend(a.hip, b.hip)
        pose.shoulder = blend(a.shoulder, b.shoulder)
        pose.arch = blend(a.arch, b.arch)
        pose.sag = blend(a.sag, b.sag)
        pose.head = blend(a.head, b.head)
        pose.headTilt = blend(a.headTilt, b.headTilt)
        pose.earTilt = blend(a.earTilt, b.earTilt)
        pose.earSpread = blend(a.earSpread, b.earSpread)
        pose.earTwitch = blend(a.earTwitch, b.earTwitch)
        pose.frontNear = blend(a.frontNear, b.frontNear)
        pose.frontFar = blend(a.frontFar, b.frontFar)
        pose.backNear = blend(a.backNear, b.backNear)
        pose.backFar = blend(a.backFar, b.backFar)
        pose.tail1 = blend(a.tail1, b.tail1)
        pose.tail2 = blend(a.tail2, b.tail2)
        pose.tailTip = blend(a.tailTip, b.tailTip)
        pose.lift = blend(a.lift, b.lift)
        pose.lid = blend(a.lid, b.lid)
        pose.look = blend(a.look, b.look)
        return pose
    }

    // MARK: - Drawing

    private struct Colors {
        let fur, belly, line, shade, highlight, far, iris, irisDark, irisLight, lash, ink, pink, mouth: CGColor
        let stripes: CGColor?

        init(_ palette: SpriteFactory.Palette) {
            let fur = palette.fur
            let brightness = fur.usingColorSpace(.deviceRGB)?.brightnessComponent ?? 1
            self.fur = fur.cgColor
            belly = palette.belly.cgColor
            line = palette.outline.cgColor
            shade = (fur.blended(withFraction: 0.28, of: palette.outline) ?? fur).cgColor
            highlight = (fur.blended(withFraction: 0.3, of: .white) ?? fur).cgColor
            far = (fur.blended(withFraction: 0.2, of: palette.outline) ?? fur).cgColor
            iris = palette.glow.cgColor
            irisDark = (palette.glow.blended(withFraction: 0.6, of: .black) ?? palette.glow).cgColor
            irisLight = (palette.glow.blended(withFraction: 0.45, of: .white) ?? palette.glow).cgColor
            lash = (palette.outline.blended(withFraction: 0.6, of: .black) ?? .black).cgColor
            ink = (brightness < 0.4 ? fur.blended(withFraction: 0.65, of: .white) : palette.outline.blended(withFraction: 0.3, of: .black))?.cgColor ?? palette.outline.cgColor
            pink = NSColor(calibratedRed: 0.96, green: 0.62, blue: 0.66, alpha: 1).cgColor
            mouth = NSColor(calibratedRed: 0.45, green: 0.16, blue: 0.2, alpha: 1).cgColor
            stripes = palette.stripes?.cgColor
        }
    }

    /// Shapes drawn together: every outline first, so lines only show around the group's edge.
    private struct Part {
        var paths: [CGPath]
        var color: CGColor
        var shadeShift: CGFloat = 1.4
        var highlight = false
        var decorate: ((CGContext) -> Void)?
    }

    static func draw(_ pose: RigPose, palette: SpriteFactory.Palette, in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width / canvas, y: rect.height / canvas)
        if pose.flipped {
            context.translateBy(x: canvas, y: 0)
            context.scaleBy(x: -1, y: 1)
        }
        context.setLineJoin(.round)
        context.setLineCap(.round)
        let colors = Colors(palette)

        if pose.showShadow {
            let width = 36 * max(0.5, 1 - pose.lift / 16)
            let centerX = (pose.hip.x + pose.shoulder.x) / 2 + 2
            context.setFillColor(NSColor.black.withAlphaComponent(0.16).cgColor)
            context.fillEllipse(in: CGRect(x: centerX - width / 2, y: 3, width: width, height: 4.5))
        }
        context.translateBy(x: 0, y: pose.lift)

        let body = Body(pose)
        drawGroup(body.farParts(colors), colors: colors, in: context)
        if !pose.tailInFront { drawGroup([tailPart(pose, body: body, colors: colors)], colors: colors, in: context) }
        drawGroup(body.nearParts(colors), colors: colors, in: context)
        if pose.tailInFront { drawGroup([tailPart(pose, body: body, colors: colors)], colors: colors, in: context) }
        drawHead(pose, colors: colors, in: context)
        for part in body.raisedParts(colors) { drawGroup([part], colors: colors, in: context) }
        if pose.zCount > 0 { drawZs(pose, colors: colors) }
    }

    private static func drawGroup(_ parts: [Part], colors: Colors, in context: CGContext, lineWidth: CGFloat = line) {
        context.setStrokeColor(colors.line)
        context.setLineWidth(lineWidth * 2)
        for path in parts.flatMap(\.paths) {
            context.addPath(path)
            context.strokePath()
        }
        for part in parts {
            for path in part.paths {
                context.addPath(path)
                context.setFillColor(part.color)
                context.fillPath()
                if let decorate = part.decorate {
                    context.saveGState()
                    context.addPath(path)
                    context.clip()
                    decorate(context)
                    context.restoreGState()
                }
                crescent(path, shift: part.shadeShift, color: colors.shade, in: context)
                if part.highlight { crescent(path, shift: -0.9, color: colors.highlight, in: context) }
            }
        }
    }

    /// Fills the part of `path` not covered by itself shifted up (a cel-shaded underside),
    /// or shifted down for a negative shift (a highlight along the top).
    private static func crescent(_ path: CGPath, shift: CGFloat, color: CGColor, in context: CGContext) {
        var transform = CGAffineTransform(translationX: 0, y: shift)
        guard let shifted = path.copy(using: &transform) else { return }
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.addRect(CGRect(x: -32, y: -32, width: canvas + 64, height: canvas + 64))
        context.addPath(shifted)
        context.setFillColor(color)
        context.fillPath(using: .evenOdd)
        context.restoreGState()
    }

    // MARK: - Body

    private struct Body {
        let pose: RigPose
        let axis: CGVector
        let normal: CGVector

        init(_ pose: RigPose) {
            var pose = pose
            // A kitten's body: shorter than the rig's hip-to-shoulder span.
            pose.hip = pose.hip + (pose.shoulder - pose.hip) * 0.12
            self.pose = pose
            axis = (pose.shoulder - pose.hip).normalized
            let up = axis.perpendicular
            normal = pose.upsideDown ? -up : up
        }

        var tailBase: CGPoint { pose.hip - axis * 5.5 + normal * 1.5 }

        var torso: CGPath {
            let h = pose.hip, s = pose.shoulder
            let rr = rumpRadius, cr = chestRadius, k: CGFloat = 0.552
            let reach = (s - h).length * 0.35
            let rumpTop = h + normal * rr, chestTop = s + normal * cr
            let chestFront = s + axis * cr, chestBottom = s - normal * cr
            let rumpBottom = h - normal * rr, rumpBack = h - axis * rr
            let path = CGMutablePath()
            path.move(to: rumpTop)
            path.addCurve(to: chestTop, control1: rumpTop + axis * reach + normal * pose.arch, control2: chestTop - axis * reach + normal * pose.arch)
            path.addCurve(to: chestFront, control1: chestTop + axis * (cr * k), control2: chestFront + normal * (cr * k))
            path.addCurve(to: chestBottom, control1: chestFront - normal * (cr * k), control2: chestBottom + axis * (cr * k))
            path.addCurve(to: rumpBottom, control1: chestBottom - axis * reach - normal * pose.sag, control2: rumpBottom + axis * reach - normal * pose.sag)
            path.addCurve(to: rumpBack, control1: rumpBottom - axis * (rr * k), control2: rumpBack - normal * (rr * k))
            path.addCurve(to: rumpTop, control1: rumpBack + normal * (rr * k), control2: rumpTop - axis * (rr * k))
            path.closeSubpath()
            return path
        }

        var neck: CGPath {
            let start = pose.shoulder + axis * 1.5 + normal * 2.5
            return capsule(start, headPoint(CGPoint(x: -1, y: -3), of: pose), width: 9.5)
        }

        /// A soft bib of fur on the front of the chest, its tufts pointing down toward the paws.
        var chestFluff: CGPath {
            let center = pose.shoulder + axis * (chestRadius * 0.45) + normal * 0.5
            let local = furryEllipse(CGRect(x: -4.2, y: -5.6, width: 8.4, height: 11.2), tufts: [
                Tuft(from: 300, to: 20, count: 3, depth: 1, sweep: -0.4),
            ])
            var transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: atan2(axis.dy, axis.dx))
            return local.copy(using: &transform) ?? local
        }

        var haunch: CGPath {
            let center = pose.hip + axis * 1.2 - normal * 0.6
            var transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: atan2(axis.dy, axis.dx))
            return CGPath(ellipseIn: CGRect(x: -6.8, y: -7.8, width: 13.6, height: 15.6), transform: &transform)
        }

        var frontRoot: CGPoint { pose.shoulder - normal * 1.8 + axis * 0.5 }
        var hindRoot: CGPoint { pose.hip - normal * 1.2 + axis * 1 }

        /// Shoulder to elbow to paw, the elbow pointing back.
        func frontLeg(to paw: CGPoint) -> [CGPath] {
            let bend = pose.frontBend * (pose.upsideDown ? -1 : 1)
            let elbow = solveJoint(root: frontRoot, target: paw, upper: frontLengths.0, lower: frontLengths.1, bend: bend)
            return limb([frontRoot, elbow, paw], widths: [5.2, 4, 3.4]) + [pawPath(paw, tilt: pawTilt(paw))]
        }

        /// Hip to knee (pointing forward) to hock (pointing back) to paw: the springy zigzag of a
        /// cat's hind leg. The foot bone leans back from the paw toward the hip.
        func hindLeg(to paw: CGPoint) -> [CGPath] {
            let flip: CGFloat = pose.upsideDown ? -1 : 1
            let toHip = (hindRoot - paw).normalized
            let lean = 0.5 * flip
            let foot = CGVector(dx: toHip.dx * cos(lean) - toHip.dy * sin(lean), dy: toHip.dx * sin(lean) + toHip.dy * cos(lean))
            let hock = paw + foot * hindLengths.2
            let knee = solveJoint(root: hindRoot, target: hock, upper: hindLengths.0, lower: hindLengths.1, bend: flip)
            return limb([hindRoot, knee, hock, paw], widths: [6, 4.6, 3.5, 3.3]) + [pawPath(paw, tilt: pawTilt(paw))]
        }

        /// Lifted paws point their toes down.
        private func pawTilt(_ paw: CGPoint) -> CGFloat {
            guard !pose.upsideDown else { return 0 }
            return -0.45 * min(1, max(0, paw.y - ground - 0.3) / 2.5)
        }

        func legPart(_ paths: [CGPath], paws: [CGPoint], color: CGColor, colors: Colors) -> Part {
            Part(paths: paths, color: color, shadeShift: 1.1) { context in
                drawToes(paws, colors: colors, upsideDown: pose.upsideDown, in: context)
            }
        }

        func farParts(_ colors: Colors) -> [Part] {
            var paths: [CGPath] = []
            var paws: [CGPoint] = []
            if pose.hindFolded {
                paths.append(pawPath(pose.backFar))
            } else {
                paths += hindLeg(to: pose.backFar)
            }
            paws.append(pose.backFar)
            if !pose.frontTucked {
                paths += frontLeg(to: pose.frontFar)
                paws.append(pose.frontFar)
            }
            return [legPart(paths, paws: paws, color: colors.far, colors: colors)]
        }

        func nearParts(_ colors: Colors) -> [Part] {
            let stripes = colors.stripes
            var parts = [
                Part(paths: [torso], color: colors.fur, shadeShift: 2.2, highlight: true) { context in
                    belly(colors, in: context)
                    if let stripes { backStripes(stripes, in: context) }
                },
                Part(paths: [neck], color: colors.fur, shadeShift: 0),
                Part(paths: [chestFluff], color: colors.belly, shadeShift: 0.8),
                Part(paths: [haunch], color: colors.fur, shadeShift: 1.8, highlight: true) { context in
                    if let stripes { haunchStripes(stripes, in: context) }
                },
            ]
            if pose.hindFolded && !pose.scratching {
                parts.append(legPart([pawPath(pose.backNear)], paws: [pose.backNear], color: colors.fur, colors: colors))
            } else if !pose.scratching {
                parts.append(legPart(hindLeg(to: pose.backNear), paws: [pose.backNear], color: colors.fur, colors: colors))
            }
            if pose.frontTucked {
                let paw = CGPoint(x: pose.shoulder.x + chestRadius * 0.7, y: ground)
                parts.append(legPart([pawPath(paw)], paws: [paw], color: colors.fur, colors: colors))
            } else if !frontRaised {
                parts.append(legPart(frontLeg(to: pose.frontNear), paws: [pose.frontNear], color: colors.fur, colors: colors))
            }
            return parts
        }

        /// A near paw lifted across the body would merge into its outline, so it gets its own on top.
        var frontRaised: Bool {
            !pose.frontTucked && pose.frontNear.y > pose.shoulder.y - chestRadius * 0.5
        }

        func raisedParts(_ colors: Colors) -> [Part] {
            var parts: [Part] = []
            if pose.scratching {
                parts.append(legPart(hindLeg(to: pose.backNear), paws: [pose.backNear], color: colors.fur, colors: colors))
            }
            if frontRaised {
                parts.append(legPart(frontLeg(to: pose.frontNear), paws: [pose.frontNear], color: colors.fur, colors: colors))
            }
            return parts
        }

        private func belly(_ colors: Colors, in context: CGContext) {
            let angle = atan2(axis.dy, axis.dx)
            let spots: [(center: CGPoint, size: CGSize)] = [
                (pose.shoulder - normal * 4.2 - axis * 3, CGSize(width: 18, height: 7)),
                (pose.shoulder + axis * 3.6 - normal * 0.6, CGSize(width: 7, height: 11)),
            ]
            context.setFillColor(colors.belly)
            for spot in spots {
                var transform = CGAffineTransform(translationX: spot.center.x, y: spot.center.y).rotated(by: angle)
                context.addPath(CGPath(ellipseIn: CGRect(origin: CGPoint(x: -spot.size.width / 2, y: -spot.size.height / 2), size: spot.size), transform: &transform))
                context.fillPath()
            }
        }

        private func backStripes(_ color: CGColor, in context: CGContext) {
            context.setStrokeColor(color)
            context.setLineWidth(1.6)
            for t in [0.18, 0.38, 0.58, 0.76] as [CGFloat] {
                let spine = pose.hip + (pose.shoulder - pose.hip) * t
                let radius = rumpRadius + (chestRadius - rumpRadius) * t
                let top = spine + normal * (radius + pose.arch * 0.7)
                context.move(to: top + normal * 1)
                context.addQuadCurve(to: top - normal * 5.5 - axis * 1.2, control: top - normal * 2 + axis * 1)
                context.strokePath()
            }
        }

        private func haunchStripes(_ color: CGColor, in context: CGContext) {
            let center = pose.hip + axis * 1.2 - normal * 0.6
            context.setStrokeColor(color)
            context.setLineWidth(1.4)
            for offset in [-2.5, 0.5] as [CGFloat] {
                let start = center + axis * offset + normal * 7.5
                context.move(to: start)
                context.addQuadCurve(to: start - normal * 5 - axis * 2.5, control: start - normal * 3 + axis * 1.2)
                context.strokePath()
            }
        }
    }

    /// A smooth, tapering limb through its joints (a Catmull-Rom curve), with rounded ends.
    private static func limb(_ joints: [CGPoint], widths: [CGFloat]) -> [CGPath] {
        var samples: [(point: CGPoint, width: CGFloat)] = []
        let steps = 8
        for i in 0..<(joints.count - 1) {
            let p0 = joints[max(i - 1, 0)], p1 = joints[i], p2 = joints[i + 1], p3 = joints[min(i + 2, joints.count - 1)]
            for step in 0..<steps {
                let t = CGFloat(step) / CGFloat(steps)
                let t2 = t * t, t3 = t2 * t
                func axis(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
                    0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (3 * b - a - 3 * c + d) * t3)
                }
                let point = CGPoint(x: axis(p0.x, p1.x, p2.x, p3.x), y: axis(p0.y, p1.y, p2.y, p3.y))
                samples.append((point, widths[i] + (widths[i + 1] - widths[i]) * t))
            }
        }
        samples.append((joints[joints.count - 1], widths[widths.count - 1]))

        var left: [CGPoint] = [], right: [CGPoint] = []
        for (index, sample) in samples.enumerated() {
            let before = samples[max(index - 1, 0)].point, after = samples[min(index + 1, samples.count - 1)].point
            let normal = (after - before).normalized.perpendicular
            left.append(sample.point + normal * (sample.width / 2))
            right.append(sample.point - normal * (sample.width / 2))
        }
        let body = CGMutablePath()
        body.addLines(between: left + right.reversed())
        body.closeSubpath()
        let caps = [samples[0], samples[samples.count - 1]].map { sample in
            CGPath(ellipseIn: CGRect(x: sample.point.x - sample.width / 2, y: sample.point.y - sample.width / 2, width: sample.width, height: sample.width), transform: nil)
        }
        return [body] + caps
    }

    /// Toe lines on paws standing on the ground, or pink beans on paws turned up.
    private static func drawToes(_ paws: [CGPoint], colors: Colors, upsideDown: Bool, in context: CGContext) {
        for paw in paws {
            let c = CGPoint(x: paw.x + 0.3, y: paw.y)
            if upsideDown {
                context.setFillColor(colors.pink)
                context.fillEllipse(in: CGRect(x: c.x - 1.1, y: c.y - 0.2, width: 2.2, height: 1.5))
                for dx in [-1.4, 0, 1.4] as [CGFloat] {
                    context.fillEllipse(in: CGRect(x: c.x + dx - 0.45, y: c.y - 1.3, width: 0.9, height: 0.8))
                }
            } else if paw.y < ground + 0.4 {
                context.setStrokeColor(NSColor(cgColor: colors.line)?.withAlphaComponent(0.6).cgColor ?? colors.line)
                context.setLineWidth(0.35)
                for dx in [0.7, 1.8] as [CGFloat] {
                    context.move(to: CGPoint(x: c.x + dx, y: c.y - 1.6))
                    context.addLine(to: CGPoint(x: c.x + dx - 0.1, y: c.y - 0.4))
                }
                context.strokePath()
            }
        }
    }

    /// Two-bone inverse kinematics: where the middle joint sits so the leg reaches `target`.
    /// Out-of-reach targets get a straight, slightly stretched leg.
    private static func solveJoint(root: CGPoint, target: CGPoint, upper: CGFloat, lower: CGFloat, bend: CGFloat) -> CGPoint {
        let delta = target - root
        let distance = delta.length
        if distance >= upper + lower - 0.01 {
            return root + delta * (upper / (upper + lower))
        }
        let d = max(distance, abs(upper - lower) + 0.01)
        let cosine = (upper * upper + d * d - lower * lower) / (2 * upper * d)
        let angle = atan2(delta.dy, delta.dx) + bend * acos(min(1, max(-1, cosine)))
        return CGPoint(x: root.x + upper * cos(angle), y: root.y + upper * sin(angle))
    }

    private static func capsule(_ a: CGPoint, _ b: CGPoint, width: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: a)
        path.addLine(to: b)
        return path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 1)
    }

    private static func pawPath(_ paw: CGPoint, tilt: CGFloat = 0) -> CGPath {
        var transform = CGAffineTransform(translationX: paw.x, y: paw.y).rotated(by: tilt)
        return CGPath(ellipseIn: CGRect(x: -2.4, y: -1.6, width: 5.4, height: 3.3), transform: &transform)
    }

    // MARK: - Tail

    private static func tailPart(_ pose: RigPose, body: Body, colors: Colors) -> Part {
        let p0 = body.tailBase
        let p1 = p0 + pose.tail1, p2 = p0 + pose.tail2, p3 = p0 + pose.tailTip
        let samples = 60
        var points: [CGPoint] = []
        var normals: [CGVector] = []
        var tangents: [CGVector] = []
        for i in 0...samples {
            let t = CGFloat(i) / CGFloat(samples)
            let u = 1 - t
            let point = CGPoint(
                x: u * u * u * p0.x + 3 * u * u * t * p1.x + 3 * u * t * t * p2.x + t * t * t * p3.x,
                y: u * u * u * p0.y + 3 * u * u * t * p1.y + 3 * u * t * t * p2.y + t * t * t * p3.y
            )
            let tangent = CGVector(
                dx: 3 * u * u * (p1.x - p0.x) + 6 * u * t * (p2.x - p1.x) + 3 * t * t * (p3.x - p2.x),
                dy: 3 * u * u * (p1.y - p0.y) + 6 * u * t * (p2.y - p1.y) + 3 * t * t * (p3.y - p2.y)
            )
            points.append(point)
            tangents.append(tangent.normalized)
            normals.append(tangent.normalized.perpendicular)
        }
        // Thickens toward a fluffy, tufted end.
        let width = { (t: CGFloat) -> CGFloat in
            let taper = t > 0.75 ? 1 - pow((t - 0.75) / 0.25, 2) * 0.75 : 1
            return (3.8 + 2.6 * sin(.pi * t * 0.8)) * taper
        }
        func tuft(_ t: CGFloat, phase: CGFloat) -> CGFloat {
            guard t > 0.4 else { return 0 }
            let tooth = (t - 0.4) * 11 + phase
            return 0.9 * pow(tooth - floor(tooth), 1.5) * min(1, (t - 0.4) * 5)
        }
        let outline = CGMutablePath()
        for (i, point) in points.enumerated() {
            let t = CGFloat(i) / CGFloat(samples)
            let side = point + normals[i] * (width(t) / 2 + tuft(t, phase: 0)) + tangents[i] * tuft(t, phase: 0) * 0.6
            i == 0 ? outline.move(to: side) : outline.addLine(to: side)
        }
        outline.addQuadCurve(to: p3 - normals[samples] * (width(1) / 2), control: p3 + tangents[samples] * 2.4)
        for (i, point) in points.enumerated().reversed() {
            let t = CGFloat(i) / CGFloat(samples)
            outline.addLine(to: point - normals[i] * (width(t) / 2 + tuft(t, phase: 0.5)) + tangents[i] * tuft(t, phase: 0.5) * 0.6)
        }
        outline.closeSubpath()

        let stripes = colors.stripes
        return Part(paths: [outline], color: colors.fur, shadeShift: 1) { context in
            guard let stripes else { return }
            context.setStrokeColor(stripes)
            context.setLineWidth(1.5)
            for t in [0.3, 0.5, 0.7, 0.88] {
                let index = Int(t * Double(samples))
                let half = width(CGFloat(t)) / 2 + 1.5
                context.move(to: points[index] + normals[index] * half)
                context.addQuadCurve(to: points[index] - normals[index] * half, control: points[index] + tangents[index] * 1.2)
                context.strokePath()
            }
        }
    }

    // MARK: - Head

    /// A point given in the head's own coordinates, moved to where the head is drawn.
    private static func headPoint(_ local: CGPoint, of pose: RigPose) -> CGPoint {
        var point = CGPoint(x: local.x * headScale, y: local.y * headScale)
        if pose.headTurnedBack { point.x = -point.x }
        let angle = pose.headTilt * .pi / 180
        return CGPoint(
            x: pose.head.x + point.x * cos(angle) - point.y * sin(angle),
            y: pose.head.y + point.x * sin(angle) + point.y * cos(angle)
        )
    }

    private static func drawHead(_ pose: RigPose, colors: Colors, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: pose.head.x, y: pose.head.y)
        context.rotate(by: pose.headTilt * .pi / 180)
        if pose.headTurnedBack { context.scaleBy(x: -1, y: 1) }
        context.scaleBy(x: headScale, y: headScale)
        context.setLineWidth(line / headScale)

        let ears = [ear(side: -1, pose: pose), ear(side: 1, pose: pose)]
        let skull = furryEllipse(CGRect(x: -8.3, y: -7.3, width: 16.6, height: 13.9), tufts: [
            Tuft(from: 188, to: 252, count: 3, depth: 1.5, sweep: 0.5),
            Tuft(from: 318, to: 350, count: 2, depth: 0.9, sweep: -0.5),
            Tuft(from: 92, to: 112, count: 2, depth: 1.2, sweep: 0.5),
        ])
        let stripes = colors.stripes

        let parts = ears.map { ear in
            Part(paths: [ear.outer], color: colors.fur, shadeShift: 0) { context in
                drawInnerEar(ear, colors: colors, in: context)
            }
        } + [
            Part(paths: [skull], color: colors.fur, shadeShift: 0.6, highlight: true) { context in
                context.setFillColor(colors.belly)
                context.fillEllipse(in: CGRect(x: faceCenter - 2.3, y: -6.6, width: 4.6, height: 3.4))
                guard let stripes else { return }
                context.setStrokeColor(stripes)
                context.setLineWidth(0.7)
                for (top, bottom) in [((-1.8, 6.6), (-1.4, 4.9)), ((0.1, 6.9), (0.2, 5.2)), ((2, 6.6), (1.8, 4.9))] {
                    context.move(to: CGPoint(x: top.0, y: top.1))
                    context.addLine(to: CGPoint(x: bottom.0, y: bottom.1))
                    context.strokePath()
                }
                for y in [-1.4, -2.8] as [CGFloat] {
                    context.move(to: CGPoint(x: -8.4, y: y))
                    context.addLine(to: CGPoint(x: -6.6, y: y - 0.3))
                    context.strokePath()
                }
            },
        ]
        drawGroup(parts, colors: colors, in: context, lineWidth: line / headScale)

        drawFace(pose, colors: colors, in: context)
    }

    private struct Ear {
        let outer, inner, wisps: CGPath
    }

    /// A big, round-tipped kitten ear, mirrored about the face (`side` -1 left, 1 right).
    /// Spread swings it outward (flattened, "airplane" ears) or, negative, perks it up and in;
    /// the right ear can also twitch on its own.
    private static func ear(side: CGFloat, pose: RigPose) -> Ear {
        let spread = pose.earSpread + (side > 0 ? pose.earTwitch : 0)
        let flatten = 1 - 0.3 * min(1, max(0, spread) / 40)
        let pivot = CGPoint(x: faceCenter + side * 4.6, y: 4.4)
        let swing = -spread * .pi / 180, fold = pose.earTilt * .pi / 180
        // Drawn upright with +x pointing away from the face, then swung, mirrored, and folded back.
        func place(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let y = y * flatten
            let local = CGPoint(x: x * cos(swing) - y * sin(swing), y: x * sin(swing) + y * cos(swing))
            let d = CGVector(dx: side * local.x, dy: local.y)
            return CGPoint(x: pivot.x + d.dx * cos(fold) - d.dy * sin(fold), y: pivot.y + d.dx * sin(fold) + d.dy * cos(fold))
        }
        let outer = CGMutablePath()
        outer.move(to: place(3.7, -2.8))
        outer.addQuadCurve(to: place(2.2, 6.6), control: place(3.9, 2.4))
        outer.addQuadCurve(to: place(0.9, 6.7), control: place(1.6, 8))
        outer.addQuadCurve(to: place(-3.5, 1.4), control: place(-0.8, 4.6))
        outer.closeSubpath()

        let inner = CGMutablePath()
        inner.move(to: place(2.3, -0.6))
        inner.addQuadCurve(to: place(1.55, 5.4), control: place(2.7, 2.8))
        inner.addQuadCurve(to: place(-1.7, 1.8), control: place(-0.1, 3.8))
        inner.closeSubpath()

        let wisps = CGMutablePath()
        for (end, bend) in [((-0.9, 3.8), -0.6), ((0.5, 4.6), 0), ((1.8, 3.7), 0.6)] as [((CGFloat, CGFloat), CGFloat)] {
            wisps.move(to: place(0.4, 0.2))
            wisps.addQuadCurve(to: place(end.0, end.1), control: place(0.4 + bend, 2.2))
        }
        return Ear(outer: outer, inner: inner, wisps: wisps)
    }

    /// Pink inside with a few wisps of fur sticking out of the ear.
    private static func drawInnerEar(_ ear: Ear, colors: Colors, in context: CGContext) {
        context.addPath(ear.inner)
        context.setFillColor(colors.pink)
        context.fillPath()
        context.setStrokeColor(colors.belly)
        context.setLineWidth(0.45)
        context.addPath(ear.wisps)
        context.strokePath()
    }

    private struct Tuft {
        var from: CGFloat
        var to: CGFloat
        var count: Int
        var depth: CGFloat
        /// Leans the tips along the outline, counter-clockwise when positive.
        var sweep: CGFloat

        func progress(at degrees: CGFloat) -> CGFloat? {
            let span = (to - from + 360).truncatingRemainder(dividingBy: 360)
            let offset = (degrees - from + 360).truncatingRemainder(dividingBy: 360)
            return offset <= span ? offset / span : nil
        }
    }

    /// An ellipse whose outline breaks into pointed tufts of fur over the given arcs (degrees,
    /// counter-clockwise from the right).
    private static func furryEllipse(_ rect: CGRect, tufts: [Tuft]) -> CGPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2, ry = rect.height / 2
        let samples = 360
        let path = CGMutablePath()
        for i in 0..<samples {
            let degrees = CGFloat(i) * 360 / CGFloat(samples)
            let angle = degrees * .pi / 180
            var point = CGPoint(x: center.x + rx * cos(angle), y: center.y + ry * sin(angle))
            let normal = CGVector(dx: cos(angle) / rx, dy: sin(angle) / ry).normalized
            for tuft in tufts {
                guard let progress = tuft.progress(at: degrees) else { continue }
                let tooth = (tuft.sweep < 0 ? 1 - progress : progress) * CGFloat(tuft.count)
                let rise = tooth - floor(tooth)
                let height = tuft.depth * pow(rise, 1.8)
                point = point + normal * height + normal.perpendicular * (height * tuft.sweep)
            }
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private static func polygon(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points)
        path.closeSubpath()
        return path
    }

    private static func drawFace(_ pose: RigPose, colors: Colors, in context: CGContext) {
        // The face is mirrored about the nose's vertical line.
        let mid: CGFloat = faceCenter
        let eyeSize = CGSize(width: 4.5, height: 5.2)
        for side in [-1, 1] as [CGFloat] {
            let center = CGPoint(x: mid + side * 3.2, y: -0.9)
            drawEye(pose, center: center, size: eyeSize, side: side, colors: colors, in: context)
        }

        let pink = NSColor(cgColor: colors.pink) ?? .systemPink
        if let blush = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
            pink.withAlphaComponent(pose.blush ? 0.75 : 0.45).cgColor, pink.withAlphaComponent(0).cgColor,
        ] as CFArray, locations: [0, 1]) {
            for side in [-1, 1] as [CGFloat] {
                context.saveGState()
                context.translateBy(x: mid + side * 4.4, y: -4.6)
                context.scaleBy(x: 2, y: 1.15)
                context.drawRadialGradient(blush, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1, options: [])
                context.restoreGState()
            }
        }
        if pose.blush {
            context.setStrokeColor(pink.blended(withFraction: 0.35, of: .red)?.cgColor ?? colors.pink)
            context.setLineWidth(0.3)
            for side in [-1, 1] as [CGFloat] {
                for offset in [3.6, 4.4, 5.2] as [CGFloat] {
                    let x = mid + side * offset
                    context.move(to: CGPoint(x: x, y: -5.1))
                    context.addLine(to: CGPoint(x: x + 0.45, y: -4.2))
                }
            }
            context.strokePath()
        }

        let nose = CGPoint(x: mid, y: -4.1)
        let nosePath = CGMutablePath()
        nosePath.move(to: CGPoint(x: nose.x - 0.55, y: nose.y + 0.3))
        nosePath.addQuadCurve(to: CGPoint(x: nose.x + 0.55, y: nose.y + 0.3), control: CGPoint(x: nose.x, y: nose.y + 0.5))
        nosePath.addQuadCurve(to: CGPoint(x: nose.x, y: nose.y - 0.3), control: CGPoint(x: nose.x + 0.4, y: nose.y - 0.05))
        nosePath.addQuadCurve(to: CGPoint(x: nose.x - 0.55, y: nose.y + 0.3), control: CGPoint(x: nose.x - 0.4, y: nose.y - 0.05))
        context.addPath(nosePath)
        context.setFillColor(pink.blended(withFraction: 0.25, of: .brown)?.cgColor ?? colors.pink)
        context.fillPath()

        context.setStrokeColor(colors.ink)
        context.setLineWidth(0.4)
        switch pose.mouth {
        case .closed, .tongue:
            context.move(to: CGPoint(x: nose.x, y: nose.y - 0.3))
            context.addLine(to: CGPoint(x: nose.x, y: nose.y - 0.75))
            context.move(to: CGPoint(x: nose.x - 0.95, y: nose.y - 0.6))
            context.addQuadCurve(to: CGPoint(x: nose.x, y: nose.y - 0.75), control: CGPoint(x: nose.x - 0.5, y: nose.y - 1.35))
            context.addQuadCurve(to: CGPoint(x: nose.x + 0.95, y: nose.y - 0.6), control: CGPoint(x: nose.x + 0.5, y: nose.y - 1.35))
            context.strokePath()
            if pose.mouth == .tongue {
                context.setFillColor(colors.pink)
                context.fillEllipse(in: CGRect(x: nose.x - 0.45, y: nose.y - 2.1, width: 1.1, height: 1.3))
            }
        case .open, .wide:
            let depth: CGFloat = pose.mouth == .open ? 1.7 : 2.6
            let half: CGFloat = pose.mouth == .open ? 0.95 : 1.25
            let top = nose.y - 0.6
            let mouth = CGMutablePath()
            mouth.move(to: CGPoint(x: nose.x - half, y: top))
            mouth.addQuadCurve(to: CGPoint(x: nose.x + half, y: top), control: CGPoint(x: nose.x, y: top + 0.3))
            mouth.addCurve(to: CGPoint(x: nose.x - half, y: top), control1: CGPoint(x: nose.x + half, y: top - depth * 1.3), control2: CGPoint(x: nose.x - half, y: top - depth * 1.3))
            context.addPath(mouth)
            context.setFillColor(colors.mouth)
            context.fillPath()
            context.saveGState()
            context.addPath(mouth)
            context.clip()
            context.setFillColor(colors.pink)
            context.fillEllipse(in: CGRect(x: nose.x - half * 0.75, y: top - depth - 0.3, width: half * 1.5, height: depth * 0.75))
            context.setFillColor(NSColor.white.cgColor)
            for side in [-1, 1] as [CGFloat] {
                let x = nose.x + side * half * 0.62
                context.addPath(polygon([CGPoint(x: x - 0.3, y: top + 0.2), CGPoint(x: x + 0.3, y: top + 0.2), CGPoint(x: x, y: top - 0.75)]))
            }
            context.fillPath()
            context.restoreGState()
            context.addPath(mouth)
            context.strokePath()
        }

        context.setStrokeColor(NSColor(cgColor: colors.ink)?.withAlphaComponent(0.5).cgColor ?? colors.ink)
        context.setLineWidth(0.25)
        for side in [-1, 1] as [CGFloat] {
            let start = CGPoint(x: mid + side * 5.6, y: -4.3)
            for (reach, rise) in [(5.2, 1.3), (5.5, 0), (4.9, -1.3)] as [(CGFloat, CGFloat)] {
                let end = CGPoint(x: start.x + side * reach, y: start.y + rise)
                context.move(to: start)
                context.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2, y: end.y + 0.4))
            }
        }
        context.strokePath()
    }

    /// The x of the nose and mouth, which the eyes, blush, and whiskers mirror around.
    private static let faceCenter: CGFloat = 0.9

    /// Big glossy anime cat eyes: almond-shaped and tilted up at the outer corner, a gradient iris
    /// with a dark rim, a vertical cat pupil, catchlights, and a heavy upper lash line. `side` is
    /// -1 for the left eye and 1 for the right, so the pair mirror each other.
    private static func drawEye(_ pose: RigPose, center c: CGPoint, size: CGSize, side: CGFloat, colors: Colors, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: c.x, y: c.y)
        context.scaleBy(x: side, y: 1)
        let scale: CGFloat = pose.eyes == .wide ? 1.08 : 1
        let w = size.width * scale, h = size.height * scale
        // In here +x points away from the nose.
        let inner = CGPoint(x: -w / 2, y: -h * 0.06), outer = CGPoint(x: w / 2, y: h * 0.1)
        let top = (CGPoint(x: -w * 0.42, y: h * 0.66), CGPoint(x: w * 0.36, y: h * 0.66))
        let bottom = (CGPoint(x: w * 0.4, y: -h * 0.64), CGPoint(x: -w * 0.36, y: -h * 0.62))
        context.setStrokeColor(colors.lash)

        switch pose.eyes {
        case .open, .wide:
            let lid = min(1, max(0, pose.lid))
            func lerp(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * lid, y: a.y + (b.y - a.y) * lid) }
            let lidControls = (lerp(top.0, bottom.1), lerp(top.1, bottom.0))
            let visible = CGMutablePath()
            visible.move(to: inner)
            visible.addCurve(to: outer, control1: lidControls.0, control2: lidControls.1)
            visible.addCurve(to: inner, control1: bottom.0, control2: bottom.1)
            visible.closeSubpath()

            context.saveGState()
            context.addPath(visible)
            context.clip()
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [colors.irisDark, colors.iris, colors.irisLight] as CFArray, locations: [0, 0.45, 1]) {
                context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h * 0.5), end: CGPoint(x: 0, y: -h * 0.5), options: [])
            }
            let shift = CGPoint(x: pose.look.dx * side * w * 0.16, y: pose.look.dy * h * 0.1)
            context.setFillColor(colors.lash)
            let pupil = pose.eyes == .wide
                ? CGSize(width: w * 0.58, height: h * 0.6)
                : CGSize(width: w * 0.32, height: h * 0.74)
            context.fillEllipse(in: CGRect(x: shift.x - pupil.width / 2, y: shift.y - pupil.height / 2 + h * 0.03, width: pupil.width, height: pupil.height))
            // A dark rim around the iris.
            let rim = CGMutablePath()
            rim.move(to: inner)
            rim.addCurve(to: outer, control1: top.0, control2: top.1)
            rim.addCurve(to: inner, control1: bottom.0, control2: bottom.1)
            context.addPath(rim)
            context.setStrokeColor(colors.irisDark)
            context.setLineWidth(0.7)
            context.strokePath()
            // Lit from the upper left on both eyes, so mirror the catchlights back.
            context.scaleBy(x: side, y: 1)
            let glint = CGPoint(x: shift.x * side * 0.3, y: shift.y * 0.3)
            context.setFillColor(NSColor.white.withAlphaComponent(0.35).cgColor)
            context.fillEllipse(in: CGRect(x: -w * 0.3, y: -h * 0.42, width: w * 0.6, height: h * 0.2))
            context.setFillColor(NSColor.white.cgColor)
            context.fillEllipse(in: CGRect(x: glint.x - w * 0.36, y: glint.y + h * 0.04, width: w * 0.42, height: w * 0.42))
            context.fillEllipse(in: CGRect(x: glint.x + w * 0.12, y: glint.y - h * 0.26, width: w * 0.18, height: w * 0.18))
            context.fillEllipse(in: CGRect(x: glint.x + w * 0.2, y: glint.y + h * 0.18, width: w * 0.09, height: w * 0.09))
            context.restoreGState()

            context.setStrokeColor(NSColor(cgColor: colors.lash)?.withAlphaComponent(0.55).cgColor ?? colors.lash)
            context.setLineWidth(0.3)
            context.move(to: outer)
            context.addCurve(to: inner, control1: bottom.0, control2: bottom.1)
            context.strokePath()
            context.setStrokeColor(colors.lash)
            context.setLineWidth(0.95)
            context.move(to: CGPoint(x: inner.x - 0.1, y: inner.y))
            context.addCurve(to: outer, control1: lidControls.0, control2: lidControls.1)
            context.strokePath()
            context.setLineWidth(0.6)
            context.move(to: outer)
            context.addLine(to: CGPoint(x: outer.x + 0.75, y: outer.y + 0.4 - lid * 0.5))
            context.strokePath()
        case .half:
            drawContentEye(w: w, h: h, colors: colors, in: context)
        case .closed:
            context.setLineWidth(0.8)
            context.move(to: CGPoint(x: inner.x + w * 0.1, y: inner.y))
            context.addQuadCurve(to: CGPoint(x: outer.x - w * 0.05, y: outer.y - h * 0.1), control: CGPoint(x: 0, y: -h * 0.36))
            context.strokePath()
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: outer.x - w * 0.05, y: outer.y - h * 0.1))
            context.addLine(to: CGPoint(x: outer.x + 0.55, y: outer.y + 0.15))
            context.strokePath()
        case .happy:
            context.setLineWidth(0.8)
            context.move(to: CGPoint(x: -w * 0.42, y: -h * 0.18))
            context.addQuadCurve(to: CGPoint(x: w * 0.42, y: -h * 0.12), control: CGPoint(x: 0, y: h * 0.42))
            context.strokePath()
        }
    }

    /// A content, sleepy squint: a lowered, curved lid over a sliver of iris.
    private static func drawContentEye(w: CGFloat, h: CGFloat, colors: Colors, in context: CGContext) {
        let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
        let lidEnds = -h * 0.08, lidControl = -h * 0.5
        context.saveGState()
        context.addEllipse(in: rect)
        context.clip()
        let below = CGMutablePath()
        below.move(to: CGPoint(x: rect.minX - 1, y: lidEnds))
        below.addQuadCurve(to: CGPoint(x: rect.maxX + 1, y: lidEnds), control: CGPoint(x: 0, y: lidControl))
        below.addLine(to: CGPoint(x: rect.maxX + 1, y: rect.minY - 1))
        below.addLine(to: CGPoint(x: rect.minX - 1, y: rect.minY - 1))
        below.closeSubpath()
        context.addPath(below)
        context.clip()
        context.setFillColor(colors.iris)
        context.fill(rect)
        context.setFillColor(colors.irisLight)
        context.fillEllipse(in: CGRect(x: -w * 0.35, y: rect.minY, width: w * 0.7, height: h * 0.14))
        context.restoreGState()
        context.setStrokeColor(colors.lash)
        context.setLineWidth(0.85)
        context.move(to: CGPoint(x: rect.minX - 0.1, y: lidEnds))
        context.addQuadCurve(to: CGPoint(x: rect.maxX + 0.1, y: lidEnds), control: CGPoint(x: 0, y: lidControl))
        context.strokePath()
    }

    private static func drawZs(_ pose: RigPose, colors: Colors) {
        for index in 0..<pose.zCount {
            let size = 6 + CGFloat(index) * 2
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: size, weight: .heavy),
                .foregroundColor: NSColor(calibratedWhite: 0.15, alpha: 0.7),
            ]
            NSAttributedString(string: "z", attributes: attributes)
                .draw(at: NSPoint(x: pose.head.x + 5 + CGFloat(index) * 4, y: pose.head.y + 7 + CGFloat(index) * 5))
        }
    }
}

// MARK: - Vector math

private func + (point: CGPoint, vector: CGVector) -> CGPoint { CGPoint(x: point.x + vector.dx, y: point.y + vector.dy) }
private func - (point: CGPoint, vector: CGVector) -> CGPoint { CGPoint(x: point.x - vector.dx, y: point.y - vector.dy) }
private func - (a: CGPoint, b: CGPoint) -> CGVector { CGVector(dx: a.x - b.x, dy: a.y - b.y) }
private func * (vector: CGVector, scale: CGFloat) -> CGVector { CGVector(dx: vector.dx * scale, dy: vector.dy * scale) }
private prefix func - (vector: CGVector) -> CGVector { CGVector(dx: -vector.dx, dy: -vector.dy) }

private extension CGVector {
    var length: CGFloat { hypot(dx, dy) }
    var normalized: CGVector {
        let length = self.length
        return length > 0 ? CGVector(dx: dx / length, dy: dy / length) : CGVector(dx: 1, dy: 0)
    }
    /// Rotated a quarter turn counter-clockwise.
    var perpendicular: CGVector { CGVector(dx: -dy, dy: dx) }
}

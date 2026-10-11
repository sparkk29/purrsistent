import AppKit

/// A Ghibli-like side-view cat built on a small rig: a torso between hip and shoulder joints,
/// a three-quarter head, four two-segment legs whose knees are solved from the paw positions,
/// and a tapered tail. Animations are keyframed rig poses eased into in-between frames.
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
        var head = CGPoint(x: 47, y: 31)
        /// Degrees counter-clockwise; negative looks down.
        var headTilt: CGFloat = 0
        /// Degrees; positive folds the ears back.
        var earTilt: CGFloat = 0
        var frontNear = CGPoint(x: 41.5, y: ground)
        var frontFar = CGPoint(x: 37.5, y: ground)
        var backNear = CGPoint(x: 21, y: ground)
        var backFar = CGPoint(x: 17, y: ground)
        /// 1 bends the front wrists forward, -1 tucks the elbows back.
        var frontBend: CGFloat = 1
        var tail1 = CGVector(dx: -7, dy: 1)
        var tail2 = CGVector(dx: -12, dy: 10)
        var tailTip = CGVector(dx: -9, dy: 19)
        /// Raises the whole cat off the ground (the shadow stays put).
        var lift: CGFloat = 0
        var eyes: Eyes = .open
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
    private static let line: CGFloat = 0.9
    private static let rumpRadius: CGFloat = 7.2
    private static let chestRadius: CGFloat = 6.6
    private static let frontLengths: (CGFloat, CGFloat) = (7, 6.6)
    private static let hindLengths: (CGFloat, CGFloat) = (8.4, 8)

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
        case .walk: 10
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
        case .rollOver: 5
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
            var sway = RigPose()
            sway.tailTip = CGVector(dx: -7, dy: 20)
            return blink(tween([RigPose(), breathe, sway], steps: [4, 4, 4], loop: true), at: [9])
        case .walk:
            return walkCycle()
        case .sit:
            var twitch = sitting
            twitch.headTilt = 3
            twitch.tailTip.dy += 1.2
            return blink(tween([sitting, twitch], steps: [4, 4], loop: true), at: [6])
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
            return tween([dangling, sway], steps: [2, 2], loop: true)
        case .fall:
            var flail = falling
            flail.frontNear.y += 1.5
            flail.frontFar.y -= 1
            flail.backNear.y -= 1
            flail.backFar.y += 1.5
            flail.tailTip.dx -= 2
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
            var air = stand
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
            nuzzle.earTilt = 18
            nuzzle.eyes = .closed
            nuzzle.blush = true
            var curl = nuzzle
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
            wide.earTilt = 14
            wide.eyes = .closed
            wide.mouth = .wide
            wide.frontNear.x = 43
            return tween([RigPose(), start, wide, wide, RigPose()], steps: [3, 2, 3, 3], loop: false)
        case .groom:
            var lick = sitting
            lick.head = CGPoint(x: 42, y: 30.5)
            lick.headTilt = -14
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
            chew.head = CGPoint(x: 49, y: 13.5)
            chew.headTilt = -28
            chew.eyes = .happy
            chew.mouth = .open
            var bite = chew
            bite.mouth = .closed
            bite.head.y += 0.6
            bite.tailTip = CGVector(dx: -11, dy: 18)
            return tween([chew, bite], steps: [4, 4], loop: true)
        case .stretch:
            var bow = RigPose()
            bow.shoulder = CGPoint(x: 40, y: 13.5)
            bow.hip = CGPoint(x: 21, y: 23)
            bow.arch = -1.5
            bow.head = CGPoint(x: 50.5, y: 18.5)
            bow.headTilt = -6
            bow.earTilt = 10
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
            scratch.earTilt = 20
            scratch.eyes = .closed
            scratch.scratching = true
            scratch.frontNear = CGPoint(x: 38.5, y: ground)
            scratch.frontFar = CGPoint(x: 35.5, y: ground)
            let paws = [CGPoint(x: 31, y: 22.5), CGPoint(x: 32, y: 24.5), CGPoint(x: 31.3, y: 23), CGPoint(x: 32.3, y: 24.8)]
            return paws.map { paw in
                var pose = scratch
                pose.backNear = paw
                return pose
            }
        case .knead:
            var press = RigPose()
            press.hip = CGPoint(x: 20, y: 19.5)
            press.shoulder = CGPoint(x: 39, y: 17.5)
            press.head = CGPoint(x: 47.5, y: 27.5)
            press.eyes = .half
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
            var belly = RigPose()
            belly.upsideDown = true
            belly.hip = CGPoint(x: 22, y: 13)
            belly.shoulder = CGPoint(x: 40, y: 13.5)
            belly.arch = 0.5
            belly.head = CGPoint(x: 49.5, y: 15.5)
            belly.blush = true
            belly.frontNear = CGPoint(x: 45, y: 27)
            belly.frontFar = CGPoint(x: 42, y: 29.5)
            belly.backNear = CGPoint(x: 21.5, y: 27.5)
            belly.backFar = CGPoint(x: 25.5, y: 29)
            belly.tail1 = CGVector(dx: -5, dy: -2)
            belly.tail2 = CGVector(dx: -10, dy: -3)
            belly.tailTip = CGVector(dx: -13, dy: 0)
            var wiggle = belly
            wiggle.frontNear = CGPoint(x: 47, y: 25.5)
            wiggle.frontFar = CGPoint(x: 41, y: 30.5)
            wiggle.backNear = CGPoint(x: 19.5, y: 27)
            wiggle.backFar = CGPoint(x: 26.5, y: 30)
            wiggle.tailTip = CGVector(dx: -13, dy: 2)
            wiggle.eyes = .happy
            return tween([belly, wiggle], steps: [4, 4], loop: true)
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
            crouch.earTilt = -6
            crouch.eyes = .wide
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
            return tween([crouch, wiggle], steps: [2, 2], loop: true)
        case .leap:
            var flight = RigPose()
            flight.hip = CGPoint(x: 17, y: 21)
            flight.shoulder = CGPoint(x: 37, y: 28)
            flight.head = CGPoint(x: 45.5, y: 35.5)
            flight.headTilt = 8
            flight.eyes = .wide
            flight.mouth = .open
            flight.showShadow = false
            flight.frontNear = CGPoint(x: 52.5, y: 24.5)
            flight.frontFar = CGPoint(x: 50.5, y: 23)
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
        pose.earTilt = 10
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
        pose.earTilt = 0
        pose.eyes = .half
        pose.tail1 = CGVector(dx: -3, dy: -5.5)
        pose.tail2 = CGVector(dx: 10, dy: -7.5)
        pose.tailTip = CGVector(dx: 22, dy: -7)
        return pose
    }

    private static var dangling: RigPose {
        var pose = RigPose()
        pose.hip = CGPoint(x: 30, y: 21)
        pose.shoulder = CGPoint(x: 33, y: 38)
        pose.arch = 0
        pose.head = CGPoint(x: 35, y: 47.5)
        pose.headTilt = 4
        pose.earTilt = 12
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
        pose.earTilt = 14
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

    /// One stride carries the body 24 units, matching the walking speed at 10 fps, so planted
    /// paws stay put on the ground. Paws step in a lateral sequence: back, front, other back, other front.
    private static func walkCycle() -> [RigPose] {
        let base = RigPose()
        let stride: CGFloat = 12
        func paw(_ rest: CGPoint, phase: CGFloat) -> CGPoint {
            let q = phase.truncatingRemainder(dividingBy: 1)
            if q < 0.5 {
                return CGPoint(x: rest.x + stride / 2 - stride * 2 * q, y: ground)
            }
            let swing = (q - 0.5) / 0.5
            return CGPoint(x: rest.x - stride / 2 + stride * swing, y: ground + 3.2 * sin(.pi * swing))
        }
        return (0..<8).map { index in
            let phase = CGFloat(index) / 8
            var pose = base
            let bob = 0.4 * sin(4 * .pi * phase)
            pose.hip.y += bob
            pose.shoulder.y += bob
            pose.head.y += 0.5 * sin(4 * .pi * phase + 0.8)
            pose.backNear = paw(base.backNear, phase: phase)
            pose.frontNear = paw(base.frontNear, phase: phase + 0.25)
            pose.backFar = paw(base.backFar, phase: phase + 0.5)
            pose.frontFar = paw(base.frontFar, phase: phase + 0.75)
            pose.tailTip.dx += 1.5 * sin(2 * .pi * phase)
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

    private static func blink(_ frames: [RigPose], at indices: [Int], eyes: Eyes = .closed) -> [RigPose] {
        var frames = frames
        for index in indices where index < frames.count { frames[index].eyes = eyes }
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
        pose.frontNear = blend(a.frontNear, b.frontNear)
        pose.frontFar = blend(a.frontFar, b.frontFar)
        pose.backNear = blend(a.backNear, b.backNear)
        pose.backFar = blend(a.backFar, b.backFar)
        pose.tail1 = blend(a.tail1, b.tail1)
        pose.tail2 = blend(a.tail2, b.tail2)
        pose.tailTip = blend(a.tailTip, b.tailTip)
        pose.lift = blend(a.lift, b.lift)
        return pose
    }

    // MARK: - Drawing

    private struct Colors {
        let fur, belly, line, shade, highlight, far, iris, ink, pink, mouth: CGColor
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

    private static func drawGroup(_ parts: [Part], colors: Colors, in context: CGContext) {
        context.setStrokeColor(colors.line)
        context.setLineWidth(line * 2)
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
            return capsule(start, headPoint(CGPoint(x: -1, y: -2.5), of: pose), width: 8)
        }

        var haunch: CGPath {
            let center = pose.hip + axis * 1.2 - normal * 0.6
            var transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: atan2(axis.dy, axis.dx))
            return CGPath(ellipseIn: CGRect(x: -6, y: -7, width: 12, height: 14), transform: &transform)
        }

        var frontRoot: CGPoint { pose.shoulder - normal * 1.8 + axis * 0.5 }
        var hindRoot: CGPoint { pose.hip - normal * 1.2 + axis * 1 }

        func frontLeg(to paw: CGPoint) -> [CGPath] {
            let bend = pose.frontBend * (pose.upsideDown ? -1 : 1)
            return leg(from: frontRoot, to: paw, lengths: frontLengths, widths: (4.4, 3.2), bend: bend)
        }

        func hindLeg(to paw: CGPoint) -> [CGPath] {
            leg(from: hindRoot, to: paw, lengths: hindLengths, widths: (5, 3.2), bend: pose.upsideDown ? 1 : -1)
        }

        func farParts(_ colors: Colors) -> [Part] {
            var paths: [CGPath] = []
            if pose.hindFolded {
                paths.append(pawPath(pose.backFar))
            } else {
                paths += hindLeg(to: pose.backFar)
            }
            if !pose.frontTucked { paths += frontLeg(to: pose.frontFar) }
            return [Part(paths: paths, color: colors.far, shadeShift: 1.1)]
        }

        func nearParts(_ colors: Colors) -> [Part] {
            let stripes = colors.stripes
            var parts = [
                Part(paths: [torso], color: colors.fur, shadeShift: 2.2, highlight: true) { context in
                    belly(colors, in: context)
                    if let stripes { backStripes(stripes, in: context) }
                },
                Part(paths: [neck], color: colors.fur, shadeShift: 0),
                Part(paths: [haunch], color: colors.fur, shadeShift: 1.8, highlight: true) { context in
                    if let stripes { haunchStripes(stripes, in: context) }
                },
            ]
            if pose.hindFolded && !pose.scratching {
                parts.append(Part(paths: [pawPath(pose.backNear)], color: colors.fur, shadeShift: 1.1))
            } else if !pose.scratching {
                parts.append(Part(paths: hindLeg(to: pose.backNear), color: colors.fur, shadeShift: 1.1))
            }
            if pose.frontTucked {
                let paw = CGPoint(x: pose.shoulder.x + chestRadius * 0.7, y: ground)
                parts.append(Part(paths: [pawPath(paw)], color: colors.fur, shadeShift: 0.8))
            } else if !frontRaised {
                parts.append(Part(paths: frontLeg(to: pose.frontNear), color: colors.fur, shadeShift: 1.1))
            }
            return parts
        }

        /// A near paw lifted across the body would merge into its outline, so it gets its own on top.
        var frontRaised: Bool {
            !pose.frontTucked && !pose.upsideDown && pose.frontNear.y > pose.shoulder.y - chestRadius * 0.5
        }

        func raisedParts(_ colors: Colors) -> [Part] {
            var parts: [Part] = []
            if pose.scratching {
                parts.append(Part(paths: hindLeg(to: pose.backNear), color: colors.fur, shadeShift: 1.1))
            }
            if frontRaised {
                parts.append(Part(paths: frontLeg(to: pose.frontNear), color: colors.fur, shadeShift: 1.1))
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

    private static func leg(from root: CGPoint, to paw: CGPoint, lengths: (CGFloat, CGFloat), widths: (CGFloat, CGFloat), bend: CGFloat) -> [CGPath] {
        let joint = solveJoint(root: root, target: paw, upper: lengths.0, lower: lengths.1, bend: bend)
        return [capsule(root, joint, width: widths.0), capsule(joint, paw, width: widths.1), pawPath(paw)]
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

    private static func pawPath(_ paw: CGPoint) -> CGPath {
        CGPath(ellipseIn: CGRect(x: paw.x - 2, y: paw.y - 1.3, width: 4.6, height: 2.6), transform: nil)
    }

    // MARK: - Tail

    private static func tailPart(_ pose: RigPose, body: Body, colors: Colors) -> Part {
        let p0 = body.tailBase
        let p1 = p0 + pose.tail1, p2 = p0 + pose.tail2, p3 = p0 + pose.tailTip
        let samples = 20
        var points: [CGPoint] = []
        var normals: [CGVector] = []
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
            normals.append(tangent.normalized.perpendicular)
        }
        let width = { (t: CGFloat) in 4.4 - 2 * t }
        let outline = CGMutablePath()
        for (i, point) in points.enumerated() {
            let side = point + normals[i] * (width(CGFloat(i) / CGFloat(samples)) / 2)
            i == 0 ? outline.move(to: side) : outline.addLine(to: side)
        }
        for (i, point) in points.enumerated().reversed() {
            outline.addLine(to: point - normals[i] * (width(CGFloat(i) / CGFloat(samples)) / 2))
        }
        outline.closeSubpath()
        let tipRadius = width(1) / 2
        let tip = CGPath(ellipseIn: CGRect(x: p3.x - tipRadius, y: p3.y - tipRadius, width: tipRadius * 2, height: tipRadius * 2), transform: nil)

        let stripes = colors.stripes
        return Part(paths: [outline, tip], color: colors.fur, shadeShift: 1) { context in
            guard let stripes else { return }
            context.setStrokeColor(stripes)
            context.setLineWidth(1.4)
            for t in [0.35, 0.55, 0.75, 0.92] {
                let index = Int(t * Double(samples))
                let half = width(CGFloat(t)) / 2 + 1
                context.move(to: points[index] + normals[index] * half)
                context.addLine(to: points[index] - normals[index] * half)
                context.strokePath()
            }
        }
    }

    // MARK: - Head

    /// A point given in the head's own coordinates, moved to where the head is drawn.
    private static func headPoint(_ local: CGPoint, of pose: RigPose) -> CGPoint {
        var point = local
        if pose.headTurnedBack { point.x = -point.x }
        if pose.upsideDown { point.y = -point.y }
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
        if pose.upsideDown { context.scaleBy(x: 1, y: -1) }

        let farEar = ear([CGPoint(x: -6.4, y: 3), CGPoint(x: -5.6, y: 12), CGPoint(x: -1.2, y: 6.6)], tilt: pose.earTilt)
        let nearEar = ear([CGPoint(x: 0.4, y: 6.9), CGPoint(x: 4.4, y: 12.6), CGPoint(x: 6.9, y: 2.9)], tilt: pose.earTilt)
        let skull = CGPath(ellipseIn: CGRect(x: -7.6, y: -6.9, width: 15.2, height: 13.8), transform: nil)
        let muzzle = CGPath(ellipseIn: CGRect(x: 1.2, y: -5.3, width: 6.8, height: 5.2), transform: nil)
        let stripes = colors.stripes

        drawGroup([
            Part(paths: [farEar.outer], color: colors.far, shadeShift: 0) { context in
                context.addPath(farEar.inner)
                context.setFillColor(colors.pink)
                context.fillPath()
            },
            Part(paths: [skull], color: colors.fur, shadeShift: 1.6, highlight: true) { context in
                guard let stripes else { return }
                context.setStrokeColor(stripes)
                context.setLineWidth(1)
                for (top, bottom) in [((-2.6, 6.6), (-2, 3.8)), ((-0.4, 7.1), (-0.1, 4.2)), ((1.8, 6.8), (1.7, 4))] {
                    context.move(to: CGPoint(x: top.0, y: top.1))
                    context.addLine(to: CGPoint(x: bottom.0, y: bottom.1))
                    context.strokePath()
                }
            },
            Part(paths: [muzzle], color: colors.belly, shadeShift: 0.8),
            Part(paths: [nearEar.outer], color: colors.fur, shadeShift: 0) { context in
                context.addPath(nearEar.inner)
                context.setFillColor(colors.pink)
                context.fillPath()
            },
        ], colors: colors, in: context)

        drawFace(pose, colors: colors, in: context)
    }

    private static func ear(_ points: [CGPoint], tilt: CGFloat) -> (outer: CGPath, inner: CGPath) {
        let pivot = CGPoint(x: (points[0].x + points[2].x) / 2, y: (points[0].y + points[2].y) / 2)
        let angle = tilt * .pi / 180
        let turned = points.map { point -> CGPoint in
            let d = point - pivot
            return CGPoint(x: pivot.x + d.dx * cos(angle) - d.dy * sin(angle), y: pivot.y + d.dx * sin(angle) + d.dy * cos(angle))
        }
        let centroid = CGPoint(x: turned.map(\.x).reduce(0, +) / 3, y: turned.map(\.y).reduce(0, +) / 3)
        let insetPoints = turned.map { centroid + ($0 - centroid) * 0.5 - CGVector(dx: 0, dy: 0.4) }
        return (polygon(turned), polygon(insetPoints))
    }

    private static func polygon(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points)
        path.closeSubpath()
        return path
    }

    private static func drawFace(_ pose: RigPose, colors: Colors, in context: CGContext) {
        drawEye(pose.eyes, center: CGPoint(x: -2, y: 1.1), size: CGSize(width: 2.6, height: 3.9), colors: colors, in: context)
        drawEye(pose.eyes, center: CGPoint(x: 3.3, y: 0.9), size: CGSize(width: 3.2, height: 4.2), colors: colors, in: context)

        if pose.blush {
            context.setFillColor(NSColor(cgColor: colors.pink)?.withAlphaComponent(0.5).cgColor ?? colors.pink)
            context.fillEllipse(in: CGRect(x: 1.6, y: -3.2, width: 2.8, height: 1.3))
        }

        context.setStrokeColor(colors.ink)
        context.setLineWidth(0.55)
        switch pose.mouth {
        case .closed, .tongue:
            context.move(to: CGPoint(x: 7.4, y: -1.9))
            context.addLine(to: CGPoint(x: 7.3, y: -2.8))
            context.move(to: CGPoint(x: 6.1, y: -3.1))
            context.addQuadCurve(to: CGPoint(x: 7.3, y: -2.8), control: CGPoint(x: 6.7, y: -3.6))
            context.addQuadCurve(to: CGPoint(x: 8.3, y: -3.1), control: CGPoint(x: 7.9, y: -3.6))
            context.strokePath()
            if pose.mouth == .tongue {
                context.setFillColor(colors.pink)
                context.fillEllipse(in: CGRect(x: 7, y: -4.4, width: 1.8, height: 1.5))
            }
        case .open, .wide:
            let rect = pose.mouth == .open
                ? CGRect(x: 6.2, y: -4.6, width: 2.2, height: 2.1)
                : CGRect(x: 5.4, y: -6.2, width: 3.4, height: 4)
            context.setFillColor(colors.mouth)
            context.fillEllipse(in: rect)
            context.setFillColor(colors.pink)
            context.fillEllipse(in: CGRect(x: rect.minX + rect.width * 0.2, y: rect.minY + 0.2, width: rect.width * 0.6, height: rect.height * 0.4))
            context.addEllipse(in: rect)
            context.strokePath()
        }

        let nose = polygon([CGPoint(x: 6.7, y: -0.9), CGPoint(x: 8.2, y: -0.9), CGPoint(x: 7.45, y: -1.9)])
        context.addPath(nose)
        context.setFillColor(colors.pink)
        context.fillPath()

        context.setStrokeColor(NSColor(cgColor: colors.ink)?.withAlphaComponent(0.45).cgColor ?? colors.ink)
        context.setLineWidth(0.35)
        for end in [CGPoint(x: 12.2, y: -1.4), CGPoint(x: 12.4, y: -2.8), CGPoint(x: 11.8, y: -4.2)] {
            context.move(to: CGPoint(x: 7.4, y: -2.6))
            context.addLine(to: end)
        }
        context.strokePath()
    }

    private static func drawEye(_ eyes: Eyes, center c: CGPoint, size: CGSize, colors: Colors, in context: CGContext) {
        let w = size.width, h = size.height
        context.setStrokeColor(colors.ink)
        switch eyes {
        case .closed, .happy:
            let bulge: CGFloat = eyes == .closed ? -h * 0.35 : h * 0.4
            context.setLineWidth(0.9)
            context.move(to: CGPoint(x: c.x - w * 0.55, y: c.y))
            context.addQuadCurve(to: CGPoint(x: c.x + w * 0.55, y: c.y), control: CGPoint(x: c.x, y: c.y + bulge))
            context.strokePath()
        case .open, .half, .wide:
            let scale: CGFloat = eyes == .wide ? 1.15 : 1
            let rect = CGRect(x: c.x - w * scale / 2, y: c.y - h * scale / 2, width: w * scale, height: h * scale)
            context.saveGState()
            if eyes == .half { context.clip(to: CGRect(x: rect.minX - 1, y: rect.minY - 1, width: rect.width + 2, height: rect.height * 0.55 + 1)) }
            context.setFillColor(colors.iris)
            context.fillEllipse(in: rect)
            context.setFillColor(NSColor(calibratedWhite: 0.08, alpha: 1).cgColor)
            if eyes == .wide {
                context.fillEllipse(in: CGRect(x: c.x - w * 0.3, y: c.y - h * 0.3, width: w * 0.6, height: h * 0.6))
            } else {
                context.fillEllipse(in: CGRect(x: c.x - w * 0.14, y: c.y - h * 0.36, width: w * 0.32, height: h * 0.72))
            }
            context.setFillColor(NSColor.white.cgColor)
            context.fillEllipse(in: CGRect(x: c.x - w * 0.42, y: c.y + h * 0.02, width: w * 0.44, height: w * 0.44))
            context.fillEllipse(in: CGRect(x: c.x + w * 0.12, y: c.y - h * 0.32, width: w * 0.2, height: w * 0.2))
            context.setLineWidth(0.4)
            context.strokeEllipse(in: rect)
            context.restoreGState()

            context.setLineWidth(1)
            if eyes == .half {
                let y = rect.minY + rect.height * 0.55
                context.move(to: CGPoint(x: rect.minX - 0.3, y: y))
                context.addLine(to: CGPoint(x: rect.maxX + 0.4, y: y + 0.2))
            } else {
                context.move(to: CGPoint(x: rect.minX - 0.2, y: c.y + h * 0.1))
                context.addCurve(
                    to: CGPoint(x: rect.maxX + 0.5, y: c.y + h * 0.3),
                    control1: CGPoint(x: c.x - w * 0.3, y: rect.maxY + 0.5),
                    control2: CGPoint(x: c.x + w * 0.3, y: rect.maxY + 0.4)
                )
            }
            context.strokePath()
        }
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

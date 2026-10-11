import AppKit

/// An anime kitten built on a small rig: a chubby torso between hip and shoulder joints, a big
/// three-quarter head with glossy eyes and fluffy cheeks, four two-segment legs whose knees are
/// solved from the paw positions, and a fluffy tail.
/// This file draws a single `RigPose`; `AnimeCatClips` defines the poses and `AnimeCatAnimator`
/// brings them to life. All geometry is on a 64x64 unit canvas, facing right.
enum AnimeCatFactory {
    /// Open eyes close smoothly through `lid`; the other shapes are drawn as lines.
    enum Eyes { case open, half, closed, happy }

    enum Mouth {
        case closed, open, wide, tongue

        var openness: CGFloat {
            switch self {
            case .open: 0.6
            case .wide: 1
            case .closed, .tongue: 0
            }
        }
    }

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
        /// Extra degrees one ear swings outward on its own: twitches and lopsided ears.
        var earTwitchLeft: CGFloat = 0
        var earTwitchRight: CGFloat = 0
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
        /// How far open eyes are lidded, 0 (open) to 1 (shut).
        var lid: CGFloat = 0
        /// Extra lid on the left eye, or the right when negative, for lopsided sleepy blinks.
        var lidAsym: CGFloat = 0
        /// 0 to 1: rounder, bigger eyes with dilated pupils, for surprise and excitement.
        var wide: CGFloat = 0
        /// Where the pupils look, about -1...1 each way.
        var look = CGVector.zero
        var mouth: Mouth = .closed
        /// Opens the mouth this far (0 to 1) on top of its shape, for talking and in-betweens.
        var mouthOpen: CGFloat = 0
        /// Hind legs folded under the haunch, as when sitting or lying down.
        var hindFolded = false
        /// The near hind leg reaches up to scratch even while folded.
        var scratching = false
        /// Front legs tucked under the chest.
        var frontTucked = false
        /// The near front paw is held up in front of the chin or face, as when grooming, so it's
        /// drawn over the head even while it's still low.
        var pawToFace = false
        var tailInFront = false
        /// Lying on its back: belly and paws up.
        var upsideDown = false
        var headTurnedBack = false
        var flipped = false
        /// 0 to 1: rosy cheeks.
        var blush: CGFloat = 0
        /// 0 to 1: how far the cat has turned to face the viewer, as halfway through turning
        /// around. Centers the face on the head and tucks the tail in behind the body.
        var frontal: CGFloat = 0
        var showShadow = true
    }

    static let ground: CGFloat = 6.3
    static let canvas: CGFloat = 64

    private static let imageSize = NSSize(width: 128, height: 128)
    private static let line: CGFloat = 0.85
    private static let rumpRadius: CGFloat = 8
    private static let chestRadius: CGFloat = 7.4
    private static let headScale: CGFloat = 1.6
    private static let frontLengths: (CGFloat, CGFloat) = (6.2, 6.6)
    /// Thigh, shin, and the long foot bone that ends at the hock.
    private static let hindLengths: (CGFloat, CGFloat, CGFloat) = (5.4, 5.4, 4.4)

    // MARK: - Frames

    /// Pre-rendered frames for exporting sprites. The app itself animates the anime cat live.
    static func frames(for key: AnimationKey, appearance: CatAppearance) -> [NSImage] {
        let fps = framesPerSecond(for: key)
        let motion = AnimeMotion(key)
        var generator = SeededRandom(seed: 7)
        let animator = AnimeCatAnimator(random: { Double.random(in: 0..<1, using: &generator) })
        animator.start(motion)
        let count = max(1, Int((AnimeCatClips.clip(for: motion).exportLength * fps).rounded()))
        return (0..<count).map { index in
            let pose = animator.update(by: index == 0 ? 0 : 1 / fps)
            let particles = animator.particles
            return NSImage(size: imageSize, flipped: false) { rect in
                draw(pose, appearance: appearance, particles: particles, in: rect)
                return true
            }
        }
    }

    static func framesPerSecond(for key: AnimationKey) -> Double {
        key == .walk ? AnimeCatClips.walkFramesPerSecond : 12
    }

    // MARK: - Blending

    /// Continuous values blend; switches like folded legs take whichever pose is closer. Open eyes
    /// close through their lids on the way to a closed shape, so nothing pops.
    static func mix(_ a: RigPose, _ b: RigPose, _ t: CGFloat) -> RigPose {
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
        pose.earTwitchLeft = blend(a.earTwitchLeft, b.earTwitchLeft)
        pose.earTwitchRight = blend(a.earTwitchRight, b.earTwitchRight)
        pose.frontNear = blend(a.frontNear, b.frontNear)
        pose.frontFar = blend(a.frontFar, b.frontFar)
        pose.backNear = blend(a.backNear, b.backNear)
        pose.backFar = blend(a.backFar, b.backFar)
        pose.frontBend = blend(a.frontBend, b.frontBend)
        pose.tail1 = blend(a.tail1, b.tail1)
        pose.tail2 = blend(a.tail2, b.tail2)
        pose.tailTip = blend(a.tailTip, b.tailTip)
        pose.lift = blend(a.lift, b.lift)
        pose.lidAsym = blend(a.lidAsym, b.lidAsym)
        pose.wide = blend(a.wide, b.wide)
        pose.look = blend(a.look, b.look)
        pose.blush = blend(a.blush, b.blush)
        pose.frontal = blend(a.frontal, b.frontal)

        let mouthA = max(a.mouth.openness, a.mouthOpen), mouthB = max(b.mouth.openness, b.mouthOpen)
        pose.mouth = (t < 0.5 ? a.mouth : b.mouth) == .tongue ? .tongue : .closed
        pose.mouthOpen = blend(mouthA, mouthB)

        switch (a.eyes == .open, b.eyes == .open) {
        case (true, true):
            pose.eyes = .open
            pose.lid = blend(a.lid, b.lid)
        case (true, false):
            pose.eyes = t < 0.5 ? .open : b.eyes
            pose.lid = t < 0.5 ? a.lid + (1 - a.lid) * t * 2 : b.lid
        case (false, true):
            pose.eyes = t < 0.5 ? a.eyes : .open
            pose.lid = t < 0.5 ? a.lid : 1 + (b.lid - 1) * (t - 0.5) * 2
        case (false, false):
            pose.eyes = t < 0.5 ? a.eyes : b.eyes
            pose.lid = t < 0.5 ? a.lid : b.lid
        }
        return pose
    }

    // MARK: - Drawing

    private struct Colors {
        let fur, belly, line, shade, highlight, far, iris, irisDark, irisLight, lash, ink, innerEar, nose, mouth, tongue: CGColor
        let stripes, points, patches, sock, tailTip: CGColor?
        let fluff: CGFloat

        init(_ appearance: CatAppearance) {
            let fur = appearance.fur
            let outline = appearance.outline
            let brightness = fur.usingColorSpace(.deviceRGB)?.brightnessComponent ?? 1
            self.fur = fur.cgColor
            belly = appearance.cream.cgColor
            line = outline.cgColor
            shade = (fur.blended(withFraction: 0.28, of: outline) ?? fur).cgColor
            highlight = (fur.blended(withFraction: brightness < 0.4 ? 0.22 : 0.3, of: .white) ?? fur).cgColor
            far = (fur.blended(withFraction: 0.2, of: outline) ?? fur).cgColor
            iris = appearance.iris.cgColor
            irisDark = (appearance.iris.blended(withFraction: 0.6, of: .black) ?? appearance.iris).cgColor
            irisLight = (appearance.iris.blended(withFraction: 0.5, of: .white) ?? appearance.iris).cgColor
            lash = (outline.blended(withFraction: 0.6, of: .black) ?? .black).cgColor
            ink = (brightness < 0.4 ? fur.blended(withFraction: 0.65, of: .white) : outline.blended(withFraction: 0.3, of: .black))?.cgColor ?? line
            innerEar = appearance.innerEar.cgColor
            nose = appearance.nose.cgColor
            mouth = NSColor(calibratedRed: 0.45, green: 0.16, blue: 0.2, alpha: 1).cgColor
            tongue = NSColor(calibratedRed: 0.96, green: 0.6, blue: 0.64, alpha: 1).cgColor
            stripes = appearance.stripes?.cgColor
            points = appearance.points?.cgColor
            patches = appearance.patches?.cgColor
            sock = appearance.points?.cgColor ?? (appearance.creamSocks ? appearance.cream.cgColor : nil)
            tailTip = (appearance.points ?? appearance.patches ?? (appearance.creamTailTip ? appearance.cream : nil))?.cgColor
            fluff = appearance.fluff
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

    /// Draws the cat into `rect`. `mirrored` faces it left; particles stay upright either way.
    static func draw(
        _ pose: RigPose,
        appearance: CatAppearance,
        particles: [AnimeParticle] = [],
        mirrored: Bool = false,
        in rect: NSRect
    ) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let colors = Colors(appearance)
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width / canvas, y: rect.height / canvas)
        context.setLineJoin(.round)
        context.setLineCap(.round)

        context.saveGState()
        if mirrored {
            context.translateBy(x: canvas, y: 0)
            context.scaleBy(x: -1, y: 1)
        }
        if pose.flipped {
            context.translateBy(x: canvas, y: 0)
            context.scaleBy(x: -1, y: 1)
        }
        // One-sided markings stay on the same side of the screen when the cat turns around, as
        // a real cat's would when it turns through facing you, so they swap sides on the rig.
        let markingSide: CGFloat = mirrored != pose.flipped ? 1 : -1
        drawCat(pose, colors: colors, markingSide: markingSide, in: context)
        context.restoreGState()

        drawParticles(particles, mirrored: mirrored, colors: colors, in: context)
    }

    /// Draws just the particles into `rect`, for an overlay that can change without redrawing
    /// the cat beneath it.
    static func draw(particles: [AnimeParticle], appearance: CatAppearance, mirrored: Bool, in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width / canvas, y: rect.height / canvas)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        drawParticles(particles, mirrored: mirrored, colors: Colors(appearance), in: context)
    }

    private static func drawCat(_ pose: RigPose, colors: Colors, markingSide: CGFloat, in context: CGContext) {
        if pose.showShadow {
            let width = 36 * max(0.5, 1 - pose.lift / 16)
            let centerX = (pose.hip.x + pose.shoulder.x) / 2 + 2 * (1 - min(1, max(0, pose.frontal)))
            context.setFillColor(NSColor.black.withAlphaComponent(0.16 * max(0.4, 1 - pose.lift / 20)).cgColor)
            context.fillEllipse(in: CGRect(x: centerX - width / 2, y: 3, width: width, height: 4.5))
        }
        context.translateBy(x: 0, y: pose.lift)

        let body = Body(pose)
        drawGroup(body.farParts(colors), colors: colors, in: context)
        if !pose.tailInFront { drawGroup([tailPart(pose, body: body, colors: colors)], colors: colors, in: context) }
        drawGroup(body.nearParts(colors), colors: colors, in: context)
        if pose.tailInFront { drawGroup([tailPart(pose, body: body, colors: colors)], colors: colors, in: context) }
        drawHead(pose, colors: colors, markingSide: markingSide, in: context)
        for part in body.raisedParts(colors) { drawGroup([part], colors: colors, in: context) }
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
        guard shift != 0 else { return }
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

        /// The spine's direction for placing things along the body. It shrinks away as the cat
        /// turns to face the viewer, when the body is seen end-on, so the markings, chest, and
        /// haunch all line up down the middle.
        var along: CGVector { axis * (1 - min(1, max(0, pose.frontal))) }
        /// The spine's angle, for orienting markings, flattening out as the cat faces the viewer.
        var angle: CGFloat { atan2(axis.dy, axis.dx) * (1 - min(1, max(0, pose.frontal))) }

        var tailBase: CGPoint { pose.hip - along * 5.5 + normal * 1.5 }

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
            let start = pose.shoulder + along * 1.5 + normal * 2.5
            return capsule(start, headPoint(CGPoint(x: -1, y: -3), of: pose), width: 9.5)
        }

        /// A soft bib of fur on the front of the chest, its tufts pointing down toward the paws.
        func chestFluff(_ fluff: CGFloat) -> CGPath {
            let center = pose.shoulder + along * (chestRadius * 0.45) + normal * 0.5
            let grow = 0.85 + 0.15 * fluff
            let local = furryEllipse(CGRect(x: -4.2 * grow, y: -5.6 * grow, width: 8.4 * grow, height: 11.2 * grow), tufts: [
                Tuft(from: 300, to: 20, count: fluff > 1.3 ? 4 : 3, depth: 1 * fluff, sweep: -0.4),
            ])
            var transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle)
            return local.copy(using: &transform) ?? local
        }

        var haunch: CGPath {
            let center = pose.hip + along * 1.2 - normal * 0.6
            var transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle)
            return CGPath(ellipseIn: CGRect(x: -6.8, y: -7.8, width: 13.6, height: 15.6), transform: &transform)
        }

        var frontRoot: CGPoint { pose.shoulder - normal * 1.8 + along * 0.5 }
        var hindRoot: CGPoint { pose.hip - normal * 1.2 + along * 1 }

        /// Shoulder to elbow to paw, the elbow pointing back.
        func frontLeg(to paw: CGPoint) -> [CGPath] {
            let bend = (pose.frontBend < 0 ? -1 : 1) * (pose.upsideDown ? -1 : 1) as CGFloat
            let root = upright(frontRoot, over: paw)
            let elbow = solveJoint(root: root, target: paw, upper: frontLengths.0, lower: frontLengths.1, bend: bend)
            return limb([root, straightened(elbow, from: root, to: paw), paw], widths: [5.2, 4, 3.4]) + [pawPath(paw, tilt: pawTilt(paw))]
        }

        /// Hip to knee (pointing forward) to hock (pointing back) to paw: the springy zigzag of a
        /// cat's hind leg. The foot bone leans back from the paw toward the hip.
        func hindLeg(to paw: CGPoint) -> [CGPath] {
            let flip: CGFloat = pose.upsideDown ? -1 : 1
            let root = upright(hindRoot, over: paw)
            let toHip = (root - paw).normalized
            let lean = 0.5 * flip
            let foot = CGVector(dx: toHip.dx * cos(lean) - toHip.dy * sin(lean), dy: toHip.dx * sin(lean) + toHip.dy * cos(lean))
            let hock = paw + foot * hindLengths.2
            let knee = solveJoint(root: root, target: hock, upper: hindLengths.0, lower: hindLengths.1, bend: flip)
            let joints = [root, straightened(knee, from: root, to: paw), straightened(hock, from: root, to: paw), paw]
            return limb(joints, widths: [6, 4.6, 3.5, 3.3]) + [pawPath(paw, tilt: pawTilt(paw))]
        }

        /// Facing the viewer, a leg hangs straight down to its paw...
        private func upright(_ root: CGPoint, over paw: CGPoint) -> CGPoint {
            CGPoint(x: root.x + (paw.x - root.x) * frontal, y: root.y)
        }

        /// ...and its knees and elbows bend toward the viewer, out of sight, so they're drawn
        /// on the straight line from root to paw.
        private func straightened(_ joint: CGPoint, from root: CGPoint, to paw: CGPoint) -> CGPoint {
            guard frontal > 0, abs(paw.y - root.y) > 0.01 else { return joint }
            let t = min(1, max(0, (joint.y - root.y) / (paw.y - root.y)))
            let lineX = root.x + (paw.x - root.x) * t
            return CGPoint(x: lineX + (joint.x - lineX) * (1 - frontal), y: joint.y)
        }

        private var frontal: CGFloat { min(1, max(0, pose.frontal)) }

        /// Lifted paws point their toes down.
        private func pawTilt(_ paw: CGPoint) -> CGFloat {
            guard !pose.upsideDown else { return 0 }
            return -0.45 * min(1, max(0, paw.y - ground - 0.3) / 2.5)
        }

        /// How much darker the far legs are: they're in shadow from the side, but side by side
        /// with the near ones when the cat faces the viewer.
        private var farShade: CGFloat { 1 - frontal }

        func legPart(_ paths: [CGPath], paws: [CGPoint], color: CGColor, near: Bool, colors: Colors) -> Part {
            let sock = colors.sock.map { near ? $0 : (NSColor(cgColor: $0)?.blended(withFraction: 0.15 * farShade, of: NSColor(cgColor: colors.line) ?? .black)?.cgColor ?? $0) }
            return Part(paths: paths, color: color, shadeShift: 1.1) { context in
                if let sock {
                    context.setFillColor(sock)
                    for paw in paws {
                        context.fillEllipse(in: CGRect(x: paw.x - 3, y: paw.y - 2, width: 6.2, height: 4.6))
                    }
                }
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
            var color = colors.far
            if farShade < 1, let far = NSColor(cgColor: colors.far), let fur = NSColor(cgColor: colors.fur) {
                color = far.blended(withFraction: 1 - farShade, of: fur)?.cgColor ?? color
            }
            return [legPart(paths, paws: paws, color: color, near: false, colors: colors)]
        }

        func nearParts(_ colors: Colors) -> [Part] {
            var parts = [
                Part(paths: [torso], color: colors.fur, shadeShift: 2.2, highlight: true) { context in
                    belly(colors, in: context)
                    if let stripes = colors.stripes { backStripes(stripes, in: context) }
                    if let patches = colors.patches { backPatch(patches, in: context) }
                },
                Part(paths: [neck], color: colors.fur, shadeShift: 0),
                Part(paths: [haunch], color: colors.fur, shadeShift: 1.8, highlight: true) { context in
                    if let stripes = colors.stripes { haunchStripes(stripes, in: context) }
                },
                // After the haunch: the two meet when the cat faces the viewer, chest in front.
                Part(paths: [chestFluff(colors.fluff)], color: colors.belly, shadeShift: 0.8),
            ]
            if pose.hindFolded && !pose.scratching {
                parts.append(legPart([pawPath(pose.backNear)], paws: [pose.backNear], color: colors.fur, near: true, colors: colors))
            } else if !pose.scratching {
                parts.append(legPart(hindLeg(to: pose.backNear), paws: [pose.backNear], color: colors.fur, near: true, colors: colors))
            }
            if pose.frontTucked {
                let paw = CGPoint(x: pose.shoulder.x + chestRadius * 0.7, y: ground)
                parts.append(legPart([pawPath(paw)], paws: [paw], color: colors.fur, near: true, colors: colors))
            } else if !frontRaised {
                parts.append(legPart(frontLeg(to: pose.frontNear), paws: [pose.frontNear], color: colors.fur, near: true, colors: colors))
            }
            return parts
        }

        /// A near paw lifted across the body would merge into its outline, so it gets its own on top.
        var frontRaised: Bool {
            !pose.frontTucked && (pose.pawToFace || pose.frontNear.y > pose.shoulder.y - chestRadius * 0.5)
        }

        func raisedParts(_ colors: Colors) -> [Part] {
            var parts: [Part] = []
            if pose.scratching {
                parts.append(legPart(hindLeg(to: pose.backNear), paws: [pose.backNear], color: colors.fur, near: true, colors: colors))
            }
            if frontRaised {
                parts.append(legPart(frontLeg(to: pose.frontNear), paws: [pose.frontNear], color: colors.fur, near: true, colors: colors))
            }
            return parts
        }

        private func belly(_ colors: Colors, in context: CGContext) {
            let spots: [(center: CGPoint, size: CGSize)] = [
                (pose.shoulder - normal * 4.2 - along * 3, CGSize(width: 18, height: 7)),
                (pose.shoulder + along * 3.6 - normal * 0.6, CGSize(width: 7, height: 11)),
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
                context.addQuadCurve(to: top - normal * 5.5 - along * 1.2, control: top - normal * 2 + along * 1)
                context.strokePath()
            }
        }

        /// A soft saddle of color over the rump.
        private func backPatch(_ color: CGColor, in context: CGContext) {
            let center = pose.hip + (pose.shoulder - pose.hip) * 0.3 + normal * (rumpRadius - 0.5)
            var transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle + 0.15 * (1 - min(1, max(0, pose.frontal))))
            context.addPath(CGPath(ellipseIn: CGRect(x: -6.5, y: -3.6, width: 13, height: 7.2), transform: &transform))
            context.setFillColor(color)
            context.fillPath()
        }

        private func haunchStripes(_ color: CGColor, in context: CGContext) {
            let center = pose.hip + along * 1.2 - normal * 0.6
            context.setStrokeColor(color)
            context.setLineWidth(1.4)
            for offset in [-2.5, 0.5] as [CGFloat] {
                let start = center + along * offset + normal * 7.5
                context.move(to: start)
                context.addQuadCurve(to: start - normal * 5 - along * 2.5, control: start - normal * 3 + along * 1.2)
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
                context.setFillColor(colors.innerEar)
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
        let samples = 48
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
        let thickness = 0.88 + 0.12 * colors.fluff
        let width = { (t: CGFloat) -> CGFloat in
            let taper = t > 0.75 ? 1 - pow((t - 0.75) / 0.25, 2) * 0.75 : 1
            return (3.8 + 2.6 * sin(.pi * t * 0.8)) * taper * thickness
        }
        func tuft(_ t: CGFloat, phase: CGFloat) -> CGFloat {
            guard t > 0.4 else { return 0 }
            let tooth = (t - 0.4) * 11 + phase
            return 0.9 * colors.fluff * pow(tooth - floor(tooth), 1.5) * min(1, (t - 0.4) * 5)
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

        return Part(paths: [outline], color: colors.fur, shadeShift: 1) { context in
            if let tip = colors.tailTip, let gradient = fade(to: tip) {
                let start = points[Int(0.6 * CGFloat(samples))]
                context.drawLinearGradient(gradient, start: start, end: p3 + tangents[samples] * 1.5, options: [.drawsAfterEndLocation])
            }
            guard let stripes = colors.stripes else { return }
            context.setStrokeColor(stripes)
            context.setLineWidth(1.5)
            for t in [0.3, 0.5, 0.7] {
                let index = Int(t * Double(samples))
                let half = width(CGFloat(t)) / 2 + 1.5
                context.move(to: points[index] + normals[index] * half)
                context.addQuadCurve(to: points[index] - normals[index] * half, control: points[index] + tangents[index] * 1.2)
                context.strokePath()
            }
        }
    }

    /// Transparent to `color`, reaching full strength a little past halfway.
    private static func fade(to color: CGColor) -> CGGradient? {
        CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [color.copy(alpha: 0) ?? color, color, color] as CFArray,
            locations: [0, 0.55, 1]
        )
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

    private static func drawHead(_ pose: RigPose, colors: Colors, markingSide: CGFloat, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: pose.head.x, y: pose.head.y)
        context.rotate(by: pose.headTilt * .pi / 180)
        if pose.headTurnedBack { context.scaleBy(x: -1, y: 1) }
        context.scaleBy(x: headScale, y: headScale)
        context.setLineWidth(line / headScale)

        let fluff = colors.fluff
        // The back cheek's ruff is fuller, until the cat faces the viewer and both cheeks show.
        let front = min(1, max(0, pose.frontal))
        let skull = furryEllipse(CGRect(x: -8.3, y: -7.3, width: 16.6, height: 13.9), tufts: [
            Tuft(from: 188, to: 252, count: fluff > 1.3 ? 4 : 3, depth: (1.5 - 0.3 * front) * fluff, sweep: 0.5),
            Tuft(from: 300, to: 350, count: fluff > 1.3 ? 3 : 2, depth: (0.9 + 0.3 * front) * fluff, sweep: -0.5),
            Tuft(from: 92, to: 112, count: 2, depth: 1.2, sweep: 0.5),
        ])

        let ears = [ear(side: -1, pose: pose), ear(side: 1, pose: pose)]
        let parts = ears.map { ear in
            Part(paths: [ear.outer], color: earColor(side: ear.side, markingSide: markingSide, colors: colors), shadeShift: 0) { context in
                drawInnerEar(ear, colors: colors, in: context)
            }
        } + [
            Part(paths: [skull], color: colors.fur, shadeShift: 0.6, highlight: true) { context in
                drawFaceMarkings(colors, mid: faceCenter(pose), side: markingSide, in: context)
            },
        ]
        drawGroup(parts, colors: colors, in: context, lineWidth: line / headScale)

        drawFace(pose, colors: colors, in: context)
    }

    private static func earColor(side: CGFloat, markingSide: CGFloat, colors: Colors) -> CGColor {
        if let points = colors.points { return points }
        if side == markingSide, let patches = colors.patches { return patches }
        return colors.fur
    }

    /// Markings painted onto the skull, inside its outline: the cream muzzle, tabby stripes,
    /// a colorpoint mask, or a soft crown patch. One-sided markings go on `side` (-1 or 1).
    private static func drawFaceMarkings(_ colors: Colors, mid: CGFloat, side: CGFloat, in context: CGContext) {
        if let points = colors.points, let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [points.copy(alpha: 0.7) ?? points, points.copy(alpha: 0) ?? points] as CFArray,
            locations: [0.2, 1]
        ) {
            context.saveGState()
            context.translateBy(x: mid, y: -3.6)
            context.scaleBy(x: 1.25, y: 1)
            context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 5.6, options: [])
            context.restoreGState()
        }
        if let patches = colors.patches {
            context.saveGState()
            context.translateBy(x: 3.6 * side, y: 4.6)
            context.rotate(by: -0.35 * side)
            context.setFillColor(patches)
            context.fillEllipse(in: CGRect(x: -4.6, y: -2.6, width: 9.2, height: 5.6))
            context.restoreGState()
        }

        context.setFillColor(colors.belly)
        for puff in [-1, 1] as [CGFloat] {
            context.fillEllipse(in: CGRect(x: mid + puff * 1.25 - 2.15, y: -6.4, width: 4.3, height: 3.2))
        }
        context.fillEllipse(in: CGRect(x: mid - 1.6, y: -7.2, width: 3.2, height: 2))

        guard let stripes = colors.stripes else { return }
        context.setStrokeColor(stripes)
        context.setLineWidth(0.7)
        let flip = -side
        for (top, bottom) in [((-1.8, 6.6), (-1.4, 4.9)), ((0.1, 6.9), (0.2, 5.2)), ((2, 6.6), (1.8, 4.9))] as [((CGFloat, CGFloat), (CGFloat, CGFloat))] {
            context.move(to: CGPoint(x: top.0 * flip, y: top.1))
            context.addLine(to: CGPoint(x: bottom.0 * flip, y: bottom.1))
            context.strokePath()
        }
        for y in [-1.4, -2.8] as [CGFloat] {
            context.move(to: CGPoint(x: 8.4 * side, y: y))
            context.addLine(to: CGPoint(x: 6.6 * side, y: y - 0.3))
            context.strokePath()
        }
    }

    private struct Ear {
        let side: CGFloat
        let outer, inner, wisps: CGPath
    }

    /// A big, round-tipped kitten ear, mirrored about the face (`side` -1 left, 1 right).
    /// Spread swings it outward (flattened, "airplane" ears) or, negative, perks it up and in;
    /// each ear can also twitch on its own.
    private static func ear(side: CGFloat, pose: RigPose) -> Ear {
        let spread = pose.earSpread + (side > 0 ? pose.earTwitchRight : pose.earTwitchLeft)
        let flatten = 1 - 0.3 * min(1, max(0, spread) / 40)
        let pivot = CGPoint(x: faceCenter(pose) + side * 4.6, y: 4.4)
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
        return Ear(side: side, outer: outer, inner: inner, wisps: wisps)
    }

    /// Pink inside with a few wisps of fur sticking out of the ear.
    private static func drawInnerEar(_ ear: Ear, colors: Colors, in context: CGContext) {
        context.addPath(ear.inner)
        context.setFillColor(colors.innerEar)
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
        let samples = 240
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
        let mid = faceCenter(pose)
        let eyeSize = CGSize(width: 4.9, height: 5.6)
        for side in [-1, 1] as [CGFloat] {
            let center = CGPoint(x: mid + side * 3.3, y: -0.6)
            drawEye(pose, center: center, size: eyeSize, side: side, colors: colors, in: context)
        }

        let pink = NSColor(cgColor: colors.tongue) ?? .systemPink
        let blush = min(1, max(0, pose.blush))
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
            pink.withAlphaComponent(0.42 + 0.33 * blush).cgColor, pink.withAlphaComponent(0).cgColor,
        ] as CFArray, locations: [0, 1]) {
            for side in [-1, 1] as [CGFloat] {
                context.saveGState()
                context.translateBy(x: mid + side * 4.5, y: -4.5)
                context.scaleBy(x: 2, y: 1.15)
                context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1, options: [])
                context.restoreGState()
            }
        }
        if blush > 0.3 {
            let hatch = pink.blended(withFraction: 0.35, of: .red) ?? pink
            context.setStrokeColor(hatch.withAlphaComponent(min(1, (blush - 0.3) / 0.4)).cgColor)
            context.setLineWidth(0.3)
            for side in [-1, 1] as [CGFloat] {
                for offset in [3.7, 4.5, 5.3] as [CGFloat] {
                    let x = mid + side * offset
                    context.move(to: CGPoint(x: x, y: -5))
                    context.addLine(to: CGPoint(x: x + 0.45, y: -4.1))
                }
            }
            context.strokePath()
        }

        let nose = CGPoint(x: mid, y: -4.1)
        let nosePath = CGMutablePath()
        nosePath.move(to: CGPoint(x: nose.x - 0.65, y: nose.y + 0.35))
        nosePath.addQuadCurve(to: CGPoint(x: nose.x + 0.65, y: nose.y + 0.35), control: CGPoint(x: nose.x, y: nose.y + 0.6))
        nosePath.addQuadCurve(to: CGPoint(x: nose.x, y: nose.y - 0.3), control: CGPoint(x: nose.x + 0.45, y: nose.y - 0.05))
        nosePath.addQuadCurve(to: CGPoint(x: nose.x - 0.65, y: nose.y + 0.35), control: CGPoint(x: nose.x - 0.45, y: nose.y - 0.05))
        context.addPath(nosePath)
        context.setFillColor(colors.nose)
        context.fillPath()
        context.setFillColor(NSColor.white.withAlphaComponent(0.55).cgColor)
        context.fillEllipse(in: CGRect(x: nose.x - 0.35, y: nose.y + 0.12, width: 0.4, height: 0.22))

        context.setStrokeColor(colors.ink)
        context.setLineWidth(0.4)
        let openness = max(pose.mouth.openness, pose.mouthOpen)
        if openness < 0.08 {
            context.move(to: CGPoint(x: nose.x, y: nose.y - 0.3))
            context.addLine(to: CGPoint(x: nose.x, y: nose.y - 0.75))
            context.move(to: CGPoint(x: nose.x - 0.95, y: nose.y - 0.6))
            context.addQuadCurve(to: CGPoint(x: nose.x, y: nose.y - 0.75), control: CGPoint(x: nose.x - 0.5, y: nose.y - 1.35))
            context.addQuadCurve(to: CGPoint(x: nose.x + 0.95, y: nose.y - 0.6), control: CGPoint(x: nose.x + 0.5, y: nose.y - 1.35))
            context.strokePath()
            if pose.mouth == .tongue {
                context.setFillColor(colors.tongue)
                context.fillEllipse(in: CGRect(x: nose.x - 0.45, y: nose.y - 2.1, width: 1.1, height: 1.3))
            }
        } else {
            let depth = 0.5 + 2.1 * openness
            let half = 0.7 + 0.55 * openness
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
            context.setFillColor(colors.tongue)
            context.fillEllipse(in: CGRect(x: nose.x - half * 0.75, y: top - depth - 0.3, width: half * 1.5, height: depth * 0.75))
            if openness > 0.45 {
                context.setFillColor(NSColor.white.cgColor)
                for side in [-1, 1] as [CGFloat] {
                    let x = nose.x + side * half * 0.62
                    context.addPath(polygon([CGPoint(x: x - 0.3, y: top + 0.2), CGPoint(x: x + 0.3, y: top + 0.2), CGPoint(x: x, y: top - 0.75)]))
                }
                context.fillPath()
            }
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

    /// The x of the nose and mouth, which the eyes, blush, and whiskers mirror around: a little
    /// toward the way the cat faces, or dead center when it faces the viewer.
    private static func faceCenter(_ pose: RigPose) -> CGFloat {
        0.9 * (1 - min(1, max(0, pose.frontal)))
    }

    /// Big glossy anime cat eyes: almond-shaped and tilted up at the outer corner, a layered iris
    /// (dark top under the lid's shadow, a glowing lower half, a dark rim), a cat pupil that rounds
    /// out when the eyes go wide, catchlights, and a heavy upper lash line. The upper lid closes
    /// continuously. `side` is -1 for the left eye and 1 for the right, so the pair mirror.
    private static func drawEye(_ pose: RigPose, center c: CGPoint, size: CGSize, side: CGFloat, colors: Colors, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: c.x, y: c.y)
        context.scaleBy(x: side, y: 1)
        let wide = min(1, max(0, pose.wide))
        let scale = 1 + 0.1 * wide
        let w = size.width * scale, h = size.height * scale
        // In here +x points away from the nose.
        let inner = CGPoint(x: -w / 2, y: -h * 0.06), outer = CGPoint(x: w / 2, y: h * 0.1)
        let top = (CGPoint(x: -w * 0.42, y: h * 0.66), CGPoint(x: w * 0.36, y: h * 0.66))
        let bottom = (CGPoint(x: w * 0.4, y: -h * 0.64), CGPoint(x: -w * 0.36, y: -h * 0.62))
        context.setStrokeColor(colors.lash)

        switch pose.eyes {
        case .open:
            // Half closed, the lid's edge runs straight across (unimpressed); further down it sags
            // into a curve over a crescent of iris (sleepy, content).
            let lid = min(1, max(0, pose.lid - side * pose.lidAsym))
            func lerp(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * lid, y: a.y + (b.y - a.y) * lid) }
            let lidControls = (lerp(top.0, bottom.1), lerp(top.1, bottom.0))
            let visible = CGMutablePath()
            visible.move(to: inner)
            visible.addCurve(to: outer, control1: lidControls.0, control2: lidControls.1)
            visible.addCurve(to: inner, control1: bottom.0, control2: bottom.1)
            visible.closeSubpath()

            if lid < 0.97 {
                context.saveGState()
                context.addPath(visible)
                context.clip()
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [colors.irisDark, colors.iris, colors.irisLight] as CFArray, locations: [0.05, 0.5, 1]) {
                    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h * 0.5), end: CGPoint(x: 0, y: -h * 0.55), options: [])
                }
                let shift = CGPoint(x: pose.look.dx * side * w * 0.16, y: pose.look.dy * h * 0.12)
                if let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
                    colors.irisLight.copy(alpha: 0.85) ?? colors.irisLight, colors.irisLight.copy(alpha: 0) ?? colors.irisLight,
                ] as CFArray, locations: [0, 1]) {
                    let center = CGPoint(x: shift.x, y: shift.y - h * 0.26)
                    context.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: w * 0.42, options: [])
                }
                let pupil = CGSize(width: w * (0.34 + 0.26 * wide), height: h * (0.7 - 0.06 * wide))
                context.setFillColor(colors.lash)
                context.fillEllipse(in: CGRect(x: shift.x - pupil.width / 2, y: shift.y - pupil.height / 2 + h * 0.03, width: pupil.width, height: pupil.height))
                // The upper lid's soft shadow across the top of the iris.
                context.setStrokeColor(NSColor.black.withAlphaComponent(0.24).cgColor)
                context.setLineWidth(h * 0.34)
                context.move(to: inner)
                context.addCurve(to: outer, control1: lidControls.0, control2: lidControls.1)
                context.strokePath()
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
                context.setFillColor(NSColor.white.withAlphaComponent(0.3).cgColor)
                context.fillEllipse(in: CGRect(x: -w * 0.3, y: -h * 0.44, width: w * 0.6, height: h * 0.2))
                context.setFillColor(NSColor.white.cgColor)
                let big = w * (0.42 + 0.06 * wide)
                context.fillEllipse(in: CGRect(x: glint.x - w * 0.38, y: glint.y + h * 0.04, width: big, height: big))
                context.fillEllipse(in: CGRect(x: glint.x + w * 0.12, y: glint.y - h * 0.26, width: w * 0.18, height: w * 0.18))
                context.fillEllipse(in: CGRect(x: glint.x + w * 0.2, y: glint.y + h * 0.18, width: w * 0.09, height: w * 0.09))
                context.restoreGState()
            }

            context.setStrokeColor(NSColor(cgColor: colors.lash)?.withAlphaComponent(0.55).cgColor ?? colors.lash)
            context.setLineWidth(0.3)
            context.move(to: outer)
            context.addCurve(to: inner, control1: bottom.0, control2: bottom.1)
            context.strokePath()
            context.setStrokeColor(colors.lash)
            context.setLineWidth(0.95 - 0.15 * lid)
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
            context.setLineWidth(0.85)
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

    // MARK: - Particles

    /// Sleep Zs, hearts, and a question mark, drawn as stickers (a dark outline around a light
    /// fill) so they read on any desktop. They're positioned in the right-facing canvas and
    /// mirrored with the cat, but never drawn backwards.
    private static func drawParticles(_ particles: [AnimeParticle], mirrored: Bool, colors: Colors, in context: CGContext) {
        for particle in particles where particle.alpha > 0.01 {
            let x = mirrored ? canvas - particle.position.x : particle.position.x
            context.saveGState()
            context.translateBy(x: x, y: particle.position.y)
            context.scaleBy(x: particle.scale, y: particle.scale)
            context.setAlpha(particle.alpha)
            switch particle.kind {
            case .z:
                let path = CGMutablePath()
                path.move(to: CGPoint(x: -1, y: 1))
                path.addLine(to: CGPoint(x: 1, y: 1))
                path.addLine(to: CGPoint(x: -1, y: -1))
                path.addLine(to: CGPoint(x: 1, y: -1))
                sticker(path, fill: nil, light: NSColor.white.cgColor, colors: colors, in: context)
            case .heart:
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0, y: -1.1))
                path.addCurve(to: CGPoint(x: 0, y: 0.6), control1: CGPoint(x: -1.9, y: 0.1), control2: CGPoint(x: -1, y: 1.5))
                path.addCurve(to: CGPoint(x: 0, y: -1.1), control1: CGPoint(x: 1, y: 1.5), control2: CGPoint(x: 1.9, y: 0.1))
                path.closeSubpath()
                sticker(path, fill: NSColor(calibratedRed: 1, green: 0.48, blue: 0.6, alpha: 1).cgColor, light: nil, colors: colors, in: context)
            case .question:
                let path = CGMutablePath()
                path.move(to: CGPoint(x: -0.9, y: 0.7))
                path.addCurve(to: CGPoint(x: 0.9, y: 0.6), control1: CGPoint(x: -0.8, y: 1.8), control2: CGPoint(x: 0.9, y: 1.7))
                path.addCurve(to: CGPoint(x: 0, y: -0.5), control1: CGPoint(x: 0.9, y: 0), control2: CGPoint(x: 0, y: 0))
                path.move(to: CGPoint(x: 0, y: -1.25))
                path.addLine(to: CGPoint(x: 0, y: -1.3))
                sticker(path, fill: nil, light: NSColor.white.cgColor, colors: colors, in: context)
            }
            context.restoreGState()
        }
    }

    private static func sticker(_ path: CGPath, fill: CGColor?, light: CGColor?, colors: Colors, in context: CGContext) {
        context.setLineJoin(.round)
        context.setLineCap(.round)
        if let fill {
            context.addPath(path)
            context.setStrokeColor(colors.line)
            context.setLineWidth(0.5)
            context.setFillColor(fill)
            context.drawPath(using: .fillStroke)
            context.setFillColor(NSColor.white.withAlphaComponent(0.6).cgColor)
            context.fillEllipse(in: CGRect(x: -0.95, y: 0.35, width: 0.45, height: 0.35))
        }
        if let light {
            context.addPath(path)
            context.setStrokeColor(colors.line)
            context.setLineWidth(1.05)
            context.strokePath()
            context.addPath(path)
            context.setStrokeColor(light)
            context.setLineWidth(0.5)
            context.strokePath()
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

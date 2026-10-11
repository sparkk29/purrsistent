import AppKit

/// Draws the built-in placeholder cat. All geometry is in a 64x64 unit canvas, facing right.
enum SpriteFactory {
    enum EyeStyle { case open, blink, closed, happy, wide }
    enum MouthStyle { case smile, open, small, yawn }

    struct Pose {
        var lift: CGFloat = 0
        var squashX: CGFloat = 1
        var squashY: CGFloat = 1
        var eyes: EyeStyle = .open
        var mouth: MouthStyle = .smile
        var backFootLift: CGFloat = 0
        var frontFootLift: CGFloat = 0
        var dangling = false
        var armsUp = false
        var blush = false
        var zCount = 0
        var showShadow = true
        var tailWag: CGFloat = 0
        /// When set, a front paw is raised to the face, lifted by this amount.
        var pawRaised: CGFloat?
    }

    struct Palette {
        var fur: NSColor
        var belly: NSColor
        var outline: NSColor
        /// Line work drawn on top of the fur: closed eyes, mouth.
        var ink: NSColor
        /// Iris color for open eyes; nil draws solid dark eyes.
        var iris: NSColor?

        static let orange = Palette(
            fur: NSColor(calibratedRed: 0.96, green: 0.68, blue: 0.38, alpha: 1),
            belly: NSColor(calibratedRed: 0.99, green: 0.86, blue: 0.68, alpha: 1),
            outline: NSColor(calibratedRed: 0.45, green: 0.27, blue: 0.12, alpha: 1),
            ink: NSColor(calibratedWhite: 0.15, alpha: 1)
        )
        static let midnight = Palette(
            fur: NSColor(calibratedRed: 0.2, green: 0.2, blue: 0.24, alpha: 1),
            belly: NSColor(calibratedRed: 0.32, green: 0.32, blue: 0.37, alpha: 1),
            outline: NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.09, alpha: 1),
            ink: NSColor(calibratedWhite: 0.9, alpha: 1),
            iris: NSColor(calibratedRed: 0.98, green: 0.8, blue: 0.25, alpha: 1)
        )
        static let silver = Palette(
            fur: NSColor(calibratedRed: 0.72, green: 0.74, blue: 0.78, alpha: 1),
            belly: NSColor(calibratedRed: 0.91, green: 0.92, blue: 0.94, alpha: 1),
            outline: NSColor(calibratedRed: 0.3, green: 0.32, blue: 0.36, alpha: 1),
            ink: NSColor(calibratedWhite: 0.15, alpha: 1),
            iris: NSColor(calibratedRed: 0.35, green: 0.62, blue: 0.88, alpha: 1)
        )
        static let snowball = Palette(
            fur: NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.97, alpha: 1),
            belly: NSColor(calibratedRed: 0.95, green: 0.91, blue: 0.86, alpha: 1),
            outline: NSColor(calibratedRed: 0.5, green: 0.5, blue: 0.56, alpha: 1),
            ink: NSColor(calibratedWhite: 0.2, alpha: 1),
            iris: NSColor(calibratedRed: 0.45, green: 0.72, blue: 0.42, alpha: 1)
        )

        static func forCoat(_ coat: Coat) -> Palette {
            switch coat {
            case .orange, .custom: .orange
            case .midnight: .midnight
            case .silver: .silver
            case .snowball: .snowball
            }
        }
    }

    private static let canvas: CGFloat = 64
    private static let imageSize = NSSize(width: 128, height: 128)

    private static let pink = NSColor(calibratedRed: 0.98, green: 0.6, blue: 0.64, alpha: 1)
    private static let pupil = NSColor(calibratedWhite: 0.1, alpha: 1)
    private static let mouthInside = NSColor(calibratedRed: 0.5, green: 0.18, blue: 0.22, alpha: 1)
    private static let snoreInk = NSColor(calibratedWhite: 0.15, alpha: 0.7)

    static func poses(for key: AnimationKey) -> [Pose] {
        switch key {
        case .idle:
            let breath: [CGFloat] = [0, 0.01, 0.02, 0.02, 0.01, 0]
            let wag: [CGFloat] = [0, 1, 2, 2, 1, 0]
            return (0..<6).map { i in
                var pose = Pose()
                pose.squashY = 1 + breath[i]
                pose.tailWag = wag[i]
                pose.eyes = i == 5 ? .blink : .open
                return pose
            }
        case .walk:
            let lifts: [CGFloat] = [0, 1.5, 0, 1.5]
            return (0..<4).map { i in
                var pose = Pose()
                pose.lift = lifts[i]
                pose.backFootLift = i == 0 ? 2.5 : 0
                pose.frontFootLift = i == 2 ? 2.5 : 0
                pose.tailWag = i.isMultiple(of: 2) ? 0 : 2
                return pose
            }
        case .sit:
            return (0..<4).map { i in
                var pose = Pose()
                pose.squashX = 1.08
                pose.squashY = 0.92
                pose.tailWag = i < 2 ? 3 : 4
                pose.eyes = i == 3 ? .blink : .open
                return pose
            }
        case .sleep:
            let breath: [CGFloat] = [0.82, 0.84, 0.85, 0.83]
            return (0..<4).map { i in
                var pose = Pose()
                pose.squashX = 1.12
                pose.squashY = breath[i]
                pose.eyes = .closed
                pose.mouth = .small
                pose.zCount = [1, 2, 3, 2][i]
                return pose
            }
        case .drag:
            return (0..<2).map { i in
                var pose = Pose()
                pose.squashX = 0.88
                pose.squashY = 1.15
                pose.eyes = .wide
                pose.mouth = .open
                pose.dangling = true
                pose.armsUp = true
                pose.showShadow = false
                pose.backFootLift = i == 0 ? -1.5 : 0
                pose.frontFootLift = i == 1 ? -1.5 : 0
                return pose
            }
        case .fall:
            return [1.05, 1.08].map { squash in
                var pose = Pose()
                pose.squashY = squash
                pose.eyes = .wide
                pose.mouth = .open
                pose.dangling = true
                pose.armsUp = true
                pose.showShadow = false
                return pose
            }
        case .happy:
            let lifts: [CGFloat] = [0, 5, 8, 4]
            return (0..<4).map { i in
                var pose = Pose()
                pose.lift = lifts[i]
                pose.eyes = .happy
                pose.mouth = .open
                pose.blush = true
                pose.tailWag = i == 1 || i == 2 ? 4 : 2
                return pose
            }
        case .petted:
            return (0..<2).map { i in
                var pose = Pose()
                pose.squashX = 1.04
                pose.squashY = i == 0 ? 0.95 : 0.97
                pose.eyes = .closed
                pose.blush = true
                pose.tailWag = i == 0 ? 3 : 5
                return pose
            }
        case .yawn:
            let stretch: [CGFloat] = [1, 1.06, 1.1, 1.1, 1.06, 1]
            let mouths: [MouthStyle] = [.smile, .open, .yawn, .yawn, .open, .smile]
            return (0..<6).map { i in
                var pose = Pose()
                pose.squashX = 2 - stretch[i]
                pose.squashY = stretch[i]
                pose.eyes = i == 0 || i == 5 ? .open : .closed
                pose.mouth = mouths[i]
                pose.tailWag = stretch[i] * 3
                return pose
            }
        case .groom:
            return (0..<4).map { i in
                var pose = Pose()
                pose.squashX = 1.04
                pose.squashY = 0.96
                pose.eyes = .closed
                pose.mouth = .small
                pose.pawRaised = i.isMultiple(of: 2) ? 0 : 2
                pose.tailWag = i < 2 ? 2 : 3
                return pose
            }
        case .eat:
            return (0..<4).map { i in
                var pose = Pose()
                pose.squashX = 1.06
                pose.squashY = i.isMultiple(of: 2) ? 0.92 : 0.95
                pose.eyes = .happy
                pose.mouth = i.isMultiple(of: 2) ? .open : .small
                pose.tailWag = i.isMultiple(of: 2) ? 3 : 5
                return pose
            }
        }
    }

    static func frames(for key: AnimationKey, palette: Palette = .orange) -> [NSImage] {
        poses(for: key).map { pose in
            NSImage(size: imageSize, flipped: false) { rect in
                draw(pose, palette: palette, in: rect)
                return true
            }
        }
    }

    static func exportPNGs(to directory: URL, palette: Palette = .orange, pixelSize: Int = 256) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for key in AnimationKey.allCases {
            for (index, pose) in poses(for: key).enumerated() {
                guard let rep = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: pixelSize,
                    pixelsHigh: pixelSize,
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .deviceRGB,
                    bytesPerRow: 0,
                    bitsPerPixel: 0
                ) else { continue }

                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                draw(pose, palette: palette, in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
                NSGraphicsContext.restoreGraphicsState()

                if let data = rep.representation(using: .png, properties: [:]) {
                    try data.write(to: directory.appendingPathComponent("\(key.rawValue)_\(index).png"))
                }
            }
        }
    }

    static func draw(_ pose: Pose, palette: Palette = .orange, in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width / canvas, y: rect.height / canvas)
        defer { context.restoreGState() }

        let bodyWidth = 40 * pose.squashX
        let bodyHeight = 30 * pose.squashY
        let body = NSRect(x: 32 - bodyWidth / 2, y: 8 + pose.lift, width: bodyWidth, height: bodyHeight)

        if pose.showShadow {
            let width = 34 * max(0.5, 1 - pose.lift / 16)
            NSColor.black.withAlphaComponent(0.18).setFill()
            NSBezierPath(ovalIn: NSRect(x: 32 - width / 2, y: 3, width: width, height: 5)).fill()
        }

        drawTail(body: body, wag: pose.tailWag, palette: palette)
        drawFeet(body: body, pose: pose, palette: palette)
        if pose.armsUp { drawArms(body: body, palette: palette) }
        drawEars(body: body, palette: palette)

        let bodyPath = NSBezierPath(ovalIn: body)
        palette.fur.setFill()
        bodyPath.fill()
        palette.belly.setFill()
        NSBezierPath(ovalIn: NSRect(
            x: body.midX - bodyWidth * 0.22 + 2,
            y: body.minY + 2,
            width: bodyWidth * 0.44,
            height: bodyHeight * 0.4
        )).fill()
        palette.outline.setStroke()
        bodyPath.lineWidth = 1.5
        bodyPath.stroke()

        drawFace(body: body, pose: pose, palette: palette)
        if let pawLift = pose.pawRaised { drawRaisedPaw(body: body, lift: pawLift, palette: palette) }
        if pose.zCount > 0 { drawZs(count: pose.zCount) }
    }

    private static func fillAndOutline(_ path: NSBezierPath, _ palette: Palette) {
        palette.fur.setFill()
        path.fill()
        palette.outline.setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    private static func drawTail(body: NSRect, wag: CGFloat, palette: Palette) {
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: body.minX + 5, y: body.minY + 8))
        tail.curve(
            to: NSPoint(x: body.minX - 4 - wag * 0.6, y: body.minY + 22 + wag),
            controlPoint1: NSPoint(x: body.minX - 6, y: body.minY + 5),
            controlPoint2: NSPoint(x: body.minX - 9, y: body.minY + 15)
        )
        tail.lineCapStyle = .round
        tail.lineWidth = 6.5
        palette.outline.setStroke()
        tail.stroke()
        tail.lineWidth = 3.5
        palette.fur.setStroke()
        tail.stroke()
    }

    private static func drawFeet(body: NSRect, pose: Pose, palette: Palette) {
        let baseY = body.minY - (pose.dangling ? 5 : 2)
        let feet: [(x: CGFloat, lift: CGFloat)] = [
            (body.midX - 9, pose.backFootLift),
            (body.midX + 9, pose.frontFootLift),
        ]
        for foot in feet {
            fillAndOutline(NSBezierPath(ovalIn: NSRect(x: foot.x - 5, y: baseY + foot.lift, width: 10, height: 6)), palette)
        }
    }

    private static func drawArms(body: NSRect, palette: Palette) {
        for x in [body.minX - 2, body.maxX - 6] {
            fillAndOutline(NSBezierPath(ovalIn: NSRect(x: x, y: body.midY + 2, width: 8, height: 11)), palette)
        }
    }

    private static func drawRaisedPaw(body: NSRect, lift: CGFloat, palette: Palette) {
        let eyeY = body.minY + body.height * 0.58
        fillAndOutline(NSBezierPath(ovalIn: NSRect(x: body.midX + 9, y: eyeY - 11 + lift, width: 8, height: 9)), palette)
    }

    private static func drawEars(body: NSRect, palette: Palette) {
        let top = body.maxY
        let ears: [[NSPoint]] = [
            [NSPoint(x: body.midX - 16, y: top - 8), NSPoint(x: body.midX - 12, y: top + 8), NSPoint(x: body.midX - 3, y: top - 2)],
            [NSPoint(x: body.midX + 3, y: top - 2), NSPoint(x: body.midX + 12, y: top + 8), NSPoint(x: body.midX + 16, y: top - 8)],
        ]
        for points in ears {
            let outer = polygon(points)
            outer.lineJoinStyle = .round
            fillAndOutline(outer, palette)

            let centroid = NSPoint(
                x: points.map(\.x).reduce(0, +) / 3,
                y: points.map(\.y).reduce(0, +) / 3
            )
            let inner = points.map { NSPoint(x: centroid.x + ($0.x - centroid.x) * 0.5, y: centroid.y + ($0.y - centroid.y) * 0.5) }
            pink.setFill()
            polygon(inner).fill()
        }
    }

    private static func drawFace(body: NSRect, pose: Pose, palette: Palette) {
        let eyeY = body.minY + body.height * 0.58
        let eyeXs = [body.midX - 3, body.midX + 9]

        for x in eyeXs {
            switch pose.eyes {
            case .open:
                let eye = NSRect(x: x - 2.2, y: eyeY - 3, width: 4.4, height: 6)
                if let iris = palette.iris {
                    iris.setFill()
                    NSBezierPath(ovalIn: eye).fill()
                    pupil.setFill()
                    NSBezierPath(ovalIn: NSRect(x: x - 0.75, y: eyeY - 2.4, width: 1.5, height: 4.8)).fill()
                } else {
                    pupil.setFill()
                    NSBezierPath(ovalIn: eye).fill()
                }
                NSColor.white.setFill()
                NSBezierPath(ovalIn: NSRect(x: x - 0.6, y: eyeY + 0.6, width: 1.6, height: 1.6)).fill()
            case .blink, .closed:
                let lid = NSBezierPath()
                lid.move(to: NSPoint(x: x - 3, y: eyeY))
                lid.curve(to: NSPoint(x: x + 3, y: eyeY), controlPoint1: NSPoint(x: x - 1, y: eyeY - 2), controlPoint2: NSPoint(x: x + 1, y: eyeY - 2))
                stroke(lid, palette.ink, width: 1.4)
            case .happy:
                let arc = NSBezierPath()
                arc.move(to: NSPoint(x: x - 3, y: eyeY - 1.5))
                arc.line(to: NSPoint(x: x, y: eyeY + 1.5))
                arc.line(to: NSPoint(x: x + 3, y: eyeY - 1.5))
                arc.lineJoinStyle = .round
                stroke(arc, palette.ink, width: 1.4)
            case .wide:
                let white = NSBezierPath(ovalIn: NSRect(x: x - 3.5, y: eyeY - 3.5, width: 7, height: 7))
                NSColor.white.setFill()
                white.fill()
                stroke(white, pupil, width: 1)
                pupil.setFill()
                NSBezierPath(ovalIn: NSRect(x: x - 1.2, y: eyeY - 1.5, width: 2.6, height: 2.6)).fill()
            }
        }

        if pose.blush {
            pink.withAlphaComponent(0.6).setFill()
            NSBezierPath(ovalIn: NSRect(x: eyeXs[0] - 6, y: eyeY - 6, width: 5, height: 3)).fill()
            NSBezierPath(ovalIn: NSRect(x: eyeXs[1] + 1.5, y: eyeY - 6, width: 5, height: 3)).fill()
        }

        let mouthX = body.midX + 3
        let mouthY = eyeY - 5.5
        switch pose.mouth {
        case .smile:
            let mouth = NSBezierPath()
            mouth.move(to: NSPoint(x: mouthX - 3, y: mouthY + 1))
            mouth.curve(to: NSPoint(x: mouthX, y: mouthY + 0.5), controlPoint1: NSPoint(x: mouthX - 2.5, y: mouthY - 1), controlPoint2: NSPoint(x: mouthX - 0.5, y: mouthY - 1))
            mouth.curve(to: NSPoint(x: mouthX + 3, y: mouthY + 1), controlPoint1: NSPoint(x: mouthX + 0.5, y: mouthY - 1), controlPoint2: NSPoint(x: mouthX + 2.5, y: mouthY - 1))
            mouth.lineCapStyle = .round
            stroke(mouth, palette.ink, width: 1.2)
        case .open:
            mouthInside.setFill()
            NSBezierPath(ovalIn: NSRect(x: mouthX - 1.6, y: mouthY - 2, width: 3.2, height: 3.5)).fill()
        case .small:
            palette.ink.setFill()
            NSBezierPath(ovalIn: NSRect(x: mouthX - 1, y: mouthY - 0.5, width: 2, height: 2)).fill()
        case .yawn:
            mouthInside.setFill()
            NSBezierPath(ovalIn: NSRect(x: mouthX - 3, y: mouthY - 5, width: 6, height: 7)).fill()
            pink.setFill()
            NSBezierPath(ovalIn: NSRect(x: mouthX - 1.8, y: mouthY - 4.5, width: 3.6, height: 2.8)).fill()
        }
    }

    private static func drawZs(count: Int) {
        for index in 0..<count {
            let size = 7 + CGFloat(index) * 2
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: size, weight: .heavy),
                .foregroundColor: snoreInk,
            ]
            NSAttributedString(string: "z", attributes: attributes)
                .draw(at: NSPoint(x: 45 + CGFloat(index) * 5, y: 38 + CGFloat(index) * 7))
        }
    }

    /// The treat: a little fish on a 32x32 unit canvas.
    static func drawFish(in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width / 32, y: rect.height / 32)
        defer { context.restoreGState() }

        let scales = NSColor(calibratedRed: 0.55, green: 0.76, blue: 0.95, alpha: 1)
        let outline = NSColor(calibratedRed: 0.2, green: 0.35, blue: 0.55, alpha: 1)

        NSColor.black.withAlphaComponent(0.15).setFill()
        NSBezierPath(ovalIn: NSRect(x: 5, y: 1.5, width: 22, height: 3)).fill()

        let fish = NSBezierPath(ovalIn: NSRect(x: 3, y: 5, width: 19, height: 11))
        fish.append(polygon([NSPoint(x: 20, y: 10.5), NSPoint(x: 29, y: 16), NSPoint(x: 29, y: 5)]))
        fish.append(polygon([NSPoint(x: 10, y: 15), NSPoint(x: 13.5, y: 19), NSPoint(x: 16, y: 15)]))
        scales.setFill()
        fish.fill()
        stroke(fish, outline, width: 1.2)

        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 6, y: 9, width: 4, height: 4)).fill()
        pupil.setFill()
        NSBezierPath(ovalIn: NSRect(x: 6.8, y: 10, width: 1.8, height: 1.8)).fill()
    }

    private static func polygon(_ points: [NSPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: points[0])
        points.dropFirst().forEach { path.line(to: $0) }
        path.close()
        return path
    }

    private static func stroke(_ path: NSBezierPath, _ color: NSColor, width: CGFloat) {
        color.setStroke()
        path.lineWidth = width
        path.stroke()
    }
}

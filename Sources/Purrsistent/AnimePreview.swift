import AppKit

/// Renders contact sheets of the live anime cat for docs and visual review:
/// every coat, every motion, and frame-by-frame strips of the main transitions.
enum AnimePreview {
    private static let cell: CGFloat = 200

    static func export(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let coats: [(String, CatAppearance)] = Coat.allCases.filter { $0 != .custom }.map { ($0.title, .forCoat($0)) }
        try write(sheet(columns: coats.count, cells: coats.map { title, appearance in
            (title, appearance, settled(.sit, for: 1.2, look: CGPoint(x: 60, y: 40)))
        }), to: directory.appendingPathComponent("anime-coats.png"))

        let motions: [(String, AnimeMotion, TimeInterval)] = [
            ("Idle", .idle, 1), ("Curious", .curious, 1), ("Happy", .happy, 0.42), ("Petted", .petted, 1),
            ("Sleep", .sleep, 2.4), ("Waking", .waking, 1.2), ("Stretch", .stretch, 0.9), ("Groom", .groom, 1.3),
            ("Startled", .startled, 0.2), ("Annoyed", .annoyed, 1), ("Yawn", .yawn, 0.7), ("Loaf", .loaf, 1),
            ("Walk", .walk, 0.3), ("Knead", .knead, 0.4), ("Roll over", .rollOver, 1), ("Pounce", .pounce, 0.5),
        ]
        try write(sheet(columns: 4, cells: motions.map { title, motion, time in
            (title, .orange, settled(motion, for: time))
        }), to: directory.appendingPathComponent("anime-states.png"))

        let strips: [(name: String, coat: CatAppearance, from: AnimeMotion, to: AnimeMotion, step: TimeInterval, count: Int)] = [
            ("transition-sleep", .cream, .idle, .sleep, 0.2, 8),
            ("transition-waking", .midnight, .sleep, .waking, 0.25, 8),
            ("transition-stretch", .orange, .idle, .stretch, 0.25, 8),
            ("transition-groom", .silver, .sit, .groom, 0.2, 8),
            ("transition-startled", .snowball, .idle, .startled, 0.1, 8),
        ]
        for strip in strips {
            let animator = AnimeCatAnimator(random: seeded())
            animator.start(strip.from)
            animator.update(by: 0.5)
            animator.setMotion(strip.to)
            var cells: [(String, CatAppearance, Snapshot)] = []
            for index in 0..<strip.count {
                if index > 0 { advance(animator, by: strip.step) }
                cells.append((String(format: "%.2fs", Double(index) * strip.step), strip.coat, Snapshot(animator)))
            }
            try write(sheet(columns: strip.count, cells: cells), to: directory.appendingPathComponent("\(strip.name).png"))
        }

        let blink = AnimeCatAnimator(random: seeded())
        blink.start(.idle)
        var frames: [(String, CatAppearance, Snapshot)] = []
        var time: TimeInterval = 0
        while frames.count < 8, time < 12 {
            advance(blink, by: 1.0 / 60)
            time += 1.0 / 60
            if blink.pose.lid > 0.05 || !frames.isEmpty {
                if frames.isEmpty || Int(time * 60) % 2 == 0 {
                    frames.append((String(format: "lid %.2f", blink.pose.lid), .orange, Snapshot(blink)))
                }
            }
        }
        try write(sheet(columns: frames.count, cells: frames), to: directory.appendingPathComponent("blink.png"))
    }

    private struct Snapshot {
        var pose: AnimeCatFactory.RigPose
        var particles: [AnimeParticle]

        init(_ animator: AnimeCatAnimator) {
            pose = animator.pose
            particles = animator.particles
        }
    }

    private static func seeded() -> () -> Double {
        var generator = SeededRandom(seed: 42)
        return { Double.random(in: 0..<1, using: &generator) }
    }

    private static func advance(_ animator: AnimeCatAnimator, by time: TimeInterval) {
        var remaining = time
        while remaining > 0 {
            animator.update(by: min(remaining, 1.0 / 60))
            remaining -= 1.0 / 60
        }
    }

    private static func settled(_ motion: AnimeMotion, for time: TimeInterval, look: CGPoint? = nil) -> Snapshot {
        let animator = AnimeCatAnimator(random: seeded())
        animator.attention = look
        animator.start(motion)
        advance(animator, by: time)
        return Snapshot(animator)
    }

    private static func sheet(columns: Int, cells: [(title: String, appearance: CatAppearance, snapshot: Snapshot)]) -> NSBitmapImageRep? {
        let rows = (cells.count + columns - 1) / columns
        let label: CGFloat = 26
        let width = Int(cell) * columns, height = Int(cell + label) * rows
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.97, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor(calibratedWhite: 0.3, alpha: 1),
        ]
        for (index, entry) in cells.enumerated() {
            let column = index % columns, row = index / columns
            let origin = NSPoint(x: CGFloat(column) * cell, y: CGFloat(height) - CGFloat(row + 1) * (cell + label))
            AnimeCatFactory.draw(entry.snapshot.pose, appearance: entry.appearance, particles: entry.snapshot.particles, in: NSRect(x: origin.x, y: origin.y + label, width: cell, height: cell))
            let text = entry.title as NSString
            let size = text.size(withAttributes: attributes)
            text.draw(at: NSPoint(x: origin.x + (cell - size.width) / 2, y: origin.y + 6), withAttributes: attributes)
        }
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func write(_ rep: NSBitmapImageRep?, to url: URL) throws {
        guard let data = rep?.representation(using: .png, properties: [:]) else { return }
        try data.write(to: url)
    }
}

import AppKit

/// Draws the app icon: the placeholder cat on a macOS-style rounded tile, laid out on a 1024x1024 canvas.
enum IconFactory {
    private static let canvas: CGFloat = 1024
    private static let iconsetSizes: [(points: Int, scale: Int)] = [
        (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
    ]

    private static let tileTop = NSColor(calibratedRed: 0.62, green: 0.56, blue: 1.0, alpha: 1)
    private static let tileBottom = NSColor(calibratedRed: 0.36, green: 0.29, blue: 0.84, alpha: 1)

    /// Writes an `.iconset` folder that `iconutil -c icns` can turn into an `.icns` file.
    static func exportIconset(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for size in iconsetSizes {
            let suffix = size.scale == 1 ? "" : "@\(size.scale)x"
            let name = "icon_\(size.points)x\(size.points)\(suffix).png"
            if let data = png(pixelSize: size.points * size.scale) {
                try data.write(to: directory.appendingPathComponent(name))
            }
        }
    }

    static func png(pixelSize: Int) -> Data? {
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
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }

    static func draw(in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let scale = rect.width / canvas
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: scale, y: scale)
        defer { context.restoreGState() }

        let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)

        // Shadows ignore the current transform, so they're scaled by hand.
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowBlurRadius = 24 * scale
        shadow.shadowOffset = NSSize(width: 0, height: -10 * scale)
        shadow.set()
        tileBottom.setFill()
        tile.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState()
        tile.addClip()
        NSGradient(starting: tileBottom, ending: tileTop)?.draw(in: tile, angle: 90)

        NSColor.white.withAlphaComponent(0.14).setFill()
        NSBezierPath(ovalIn: NSRect(x: 222, y: 240, width: 580, height: 580)).fill()

        var pose = SpriteFactory.Pose()
        pose.eyes = .happy
        pose.blush = true
        pose.tailWag = 3

        let catScale: CGFloat = 12
        let catCenter = NSPoint(x: 27.5, y: 24.5)
        SpriteFactory.draw(pose, palette: .orange, in: NSRect(
            x: 512 - catCenter.x * catScale,
            y: 500 - catCenter.y * catScale,
            width: 64 * catScale,
            height: 64 * catScale
        ))
        NSGraphicsContext.restoreGraphicsState()
    }
}

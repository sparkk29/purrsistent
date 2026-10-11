import AppKit

/// Rasterizes the live anime cat at the screen's backing scale: the cat itself, which `PetView`
/// also uses for pixel hit-testing, and a separate overlay of floating Zs, hearts and question
/// marks, so those can drift along without redrawing the cat.
@MainActor
final class AnimeCatRenderer {
    /// Changes smaller than this, in pixels, are not worth redrawing: a resting cat's breathing
    /// would otherwise cost a full redraw every frame for an invisible difference.
    static let minimumVisibleChange: CGFloat = 0.5

    private let catCanvas = Canvas()
    private let particleCanvas = Canvas()
    private var drawn: AnimeCatFactory.RigPose?
    private var drawnMirrored = false

    /// Makes the next `renderCat` draw even if the cat hasn't moved, e.g. after the coat changed
    /// or something else was shown in the view.
    func invalidate() {
        drawn = nil
    }

    /// Returns a fresh image of the cat, or nil if it looks the same as in the last one.
    func renderCat(_ animator: AnimeCatAnimator, appearance: CatAppearance, size: NSSize, scale: CGFloat) -> NSImage? {
        if catCanvas.resize(to: size, scale: scale) { drawn = nil }
        if let drawn,
           animator.mirrored == drawnMirrored,
           Self.visibleChange(from: drawn, to: animator.pose) * catCanvas.pixelsPerUnit < Self.minimumVisibleChange {
            return nil
        }
        drawn = animator.pose
        drawnMirrored = animator.mirrored

        return catCanvas.image(size: size) { rect in
            AnimeCatFactory.draw(animator.pose, appearance: appearance, mirrored: animator.mirrored, in: rect)
        }
    }

    /// The particles floating around the cat right now, or nil if there are none.
    func renderParticles(_ animator: AnimeCatAnimator, appearance: CatAppearance, size: NSSize, scale: CGFloat) -> NSImage? {
        guard !animator.particles.isEmpty else { return nil }
        particleCanvas.resize(to: size, scale: scale)
        return particleCanvas.image(size: size) { rect in
            AnimeCatFactory.draw(particles: animator.particles, appearance: appearance, mirrored: animator.mirrored, in: rect)
        }
    }

    /// Roughly how far, in canvas units, anything on the cat moves between two poses. Angles and
    /// fractions are weighted by the size of the part they move; a change of shape is infinite.
    nonisolated static func visibleChange(from a: AnimeCatFactory.RigPose, to b: AnimeCatFactory.RigPose) -> CGFloat {
        guard a.eyes == b.eyes, a.mouth == b.mouth,
              a.hindFolded == b.hindFolded, a.scratching == b.scratching, a.frontTucked == b.frontTucked,
              a.tailInFront == b.tailInFront, a.upsideDown == b.upsideDown,
              a.headTurnedBack == b.headTurnedBack, a.flipped == b.flipped, a.showShadow == b.showShadow
        else { return .infinity }

        func moved(_ p: CGPoint, _ q: CGPoint) -> CGFloat { hypot(p.x - q.x, p.y - q.y) }
        func moved(_ p: CGVector, _ q: CGVector) -> CGFloat { hypot(p.dx - q.dx, p.dy - q.dy) }
        let degree: CGFloat = 0.2
        return [
            moved(a.hip, b.hip), moved(a.shoulder, b.shoulder), moved(a.head, b.head),
            moved(a.frontNear, b.frontNear), moved(a.frontFar, b.frontFar),
            moved(a.backNear, b.backNear), moved(a.backFar, b.backFar),
            moved(a.tail1, b.tail1), moved(a.tail2, b.tail2), moved(a.tailTip, b.tailTip),
            0.75 * abs(a.arch - b.arch), 0.75 * abs(a.sag - b.sag), abs(a.lift - b.lift),
            5 * abs(a.frontBend - b.frontBend),
            degree * abs(a.headTilt - b.headTilt), degree * abs(a.earTilt - b.earTilt),
            degree * abs(a.earSpread - b.earSpread),
            degree * abs(a.earTwitchLeft - b.earTwitchLeft), degree * abs(a.earTwitchRight - b.earTwitchRight),
            9 * abs(a.lid - b.lid), 9 * abs(a.lidAsym - b.lidAsym),
            3 * abs(a.wide - b.wide), 2 * moved(a.look, b.look),
            3 * abs(a.mouthOpen - b.mouthOpen), 4 * abs(a.blush - b.blush), 6 * abs(a.frontal - b.frontal),
        ].max() ?? 0
    }
}

/// A reusable sRGB bitmap.
@MainActor
private final class Canvas {
    private var context: CGContext?
    private var pixelSize = (width: 0, height: 0)

    var pixelsPerUnit: CGFloat { CGFloat(pixelSize.width) / AnimeCatFactory.canvas }

    /// Returns true if the bitmap had to be recreated.
    @discardableResult
    func resize(to size: NSSize, scale: CGFloat) -> Bool {
        let width = max(1, Int((size.width * scale).rounded()))
        let height = max(1, Int((size.height * scale).rounded()))
        guard context == nil || pixelSize != (width, height) else { return false }
        context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        pixelSize = (width, height)
        return true
    }

    func image(size: NSSize, drawing: (NSRect) -> Void) -> NSImage? {
        guard let context else { return nil }
        let rect = NSRect(x: 0, y: 0, width: pixelSize.width, height: pixelSize.height)
        context.clear(rect)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        drawing(rect)
        NSGraphicsContext.restoreGraphicsState()
        guard let image = context.makeImage() else { return nil }
        return NSImage(cgImage: image, size: size)
    }
}

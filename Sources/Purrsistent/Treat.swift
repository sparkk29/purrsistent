import AppKit

/// A fish treat that drops to the floor and waits to be eaten. It ignores the mouse entirely.
@MainActor
final class Treat {
    private let window: PetWindow
    var velocityY: CGFloat = 0
    private(set) var hasLanded = false

    init(size: CGFloat, origin: NSPoint) {
        window = PetWindow(size: size)
        window.contentView = TreatView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        window.ignoresMouseEvents = true
        window.setFrameOrigin(origin)
        window.orderFrontRegardless()
    }

    var frame: NSRect { window.frame }

    func fall(_ dt: CGFloat, gravity: CGFloat) {
        guard !hasLanded else { return }
        velocityY -= gravity * dt
        var origin = window.frame.origin
        origin.y += velocityY * dt
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        let ground = screen?.visibleFrame.minY ?? 0
        if origin.y <= ground {
            origin.y = ground
            hasLanded = true
        }
        window.setFrameOrigin(origin)
    }

    func remove() {
        window.orderOut(nil)
    }
}

private final class TreatView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        SpriteFactory.drawFish(in: bounds)
    }
}

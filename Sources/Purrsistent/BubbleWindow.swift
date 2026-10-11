import AppKit

/// A speech bubble that floats above the pet. Click it to dismiss.
@MainActor
final class BubbleWindow {
    private let window = PetWindow(size: 10)
    private let view = BubbleView()
    private var hideAt: TimeInterval = 0

    private(set) var isShowing = false

    init() {
        window.contentView = view
        view.onClick = { [weak self] in self?.hide() }
    }

    func show(_ text: String, above petFrame: NSRect, for duration: TimeInterval = 8) {
        view.text = text
        window.setContentSize(view.fittingSize)
        hideAt = ProcessInfo.processInfo.systemUptime + duration
        isShowing = true
        follow(petFrame)
        window.orderFrontRegardless()
    }

    func hide() {
        guard isShowing else { return }
        isShowing = false
        window.orderOut(nil)
    }

    /// Keeps the bubble above the pet's head and inside the screen, and hides it when time is up.
    func follow(_ petFrame: NSRect) {
        guard isShowing else { return }
        if ProcessInfo.processInfo.systemUptime >= hideAt {
            hide()
            return
        }

        let size = window.frame.size
        let headTop = petFrame.minY + petFrame.height * 0.75
        var origin = NSPoint(x: petFrame.midX - size.width / 2, y: headTop)
        let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: petFrame.midX, y: petFrame.midY)) } ?? NSScreen.main
        if let bounds = screen?.visibleFrame {
            origin.x = min(max(origin.x, bounds.minX + 4), bounds.maxX - size.width - 4)
        }
        view.tailX = petFrame.midX - origin.x
        if window.frame.origin != origin {
            window.setFrameOrigin(origin)
        }
    }
}

private final class BubbleView: NSView {
    var onClick: (() -> Void)?

    var text = "" {
        didSet { needsDisplay = true }
    }

    var tailX: CGFloat = 0 {
        didSet {
            if tailX != oldValue { needsDisplay = true }
        }
    }

    private static let font = NSFont.systemFont(ofSize: 13, weight: .medium)
    private static let padding = NSSize(width: 12, height: 8)
    private static let tailHeight: CGFloat = 9
    private static let maxTextWidth: CGFloat = 220

    private var attributes: [NSAttributedString.Key: Any] {
        [.font: Self.font, .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1)]
    }

    override var fittingSize: NSSize {
        let textSize = (text as NSString).boundingRect(
            with: NSSize(width: Self.maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attributes
        ).size
        return NSSize(
            width: ceil(textSize.width) + Self.padding.width * 2 + 2,
            height: ceil(textSize.height) + Self.padding.height * 2 + Self.tailHeight + 2
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let body = NSRect(
            x: 1,
            y: Self.tailHeight + 1,
            width: bounds.width - 2,
            height: bounds.height - Self.tailHeight - 2
        )
        let tipX = min(max(tailX, body.minX + 14), body.maxX - 14)

        let path = NSBezierPath(roundedRect: body, xRadius: 12, yRadius: 12)
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: tipX - 7, y: body.minY + 1))
        tail.line(to: NSPoint(x: tipX, y: 1))
        tail.line(to: NSPoint(x: tipX + 7, y: body.minY + 1))
        tail.close()
        path.append(tail)

        NSColor.white.setFill()
        path.fill()
        NSColor(calibratedWhite: 0, alpha: 0.18).setStroke()
        path.lineWidth = 1
        path.stroke()

        let textRect = body.insetBy(dx: Self.padding.width, dy: Self.padding.height)
        (text as NSString).draw(with: textRect, options: [.usesLineFragmentOrigin], attributes: attributes)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

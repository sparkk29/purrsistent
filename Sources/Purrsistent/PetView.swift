import AppKit

@MainActor
protocol PetViewDelegate: AnyObject {
    func petViewMouseDown(_ view: PetView, at screenPoint: NSPoint)
    func petViewMouseDragged(_ view: PetView, to screenPoint: NSPoint)
    func petViewMouseUp(_ view: PetView, at screenPoint: NSPoint)
    func petViewContextMenu(_ view: PetView) -> NSMenu?
}

final class PetView: NSView {
    weak var delegate: PetViewDelegate?

    var image: NSImage? {
        didSet {
            if image !== oldValue { needsDisplay = true }
        }
    }

    private static let opaqueAlphaThreshold: UInt8 = 70

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .high
        image?.draw(in: bounds)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return isOpaque(at: local) ? self : nil
    }

    func isOpaque(atScreenPoint screenPoint: NSPoint) -> Bool {
        guard let window else { return false }
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        return isOpaque(at: convert(windowPoint, from: nil))
    }

    func isOpaque(at point: NSPoint) -> Bool {
        guard bounds.contains(point), let image else { return false }

        var pixel: [UInt8] = [0, 0, 0, 0]
        pixel.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }

            context.translateBy(x: -point.x, y: -point.y)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            image.draw(in: bounds)
            NSGraphicsContext.restoreGraphicsState()
        }
        return pixel[3] > Self.opaqueAlphaThreshold
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            showContextMenu(for: event)
            return
        }
        delegate?.petViewMouseDown(self, at: NSEvent.mouseLocation)
    }

    override func mouseDragged(with event: NSEvent) {
        delegate?.petViewMouseDragged(self, to: NSEvent.mouseLocation)
    }

    override func mouseUp(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { return }
        delegate?.petViewMouseUp(self, at: NSEvent.mouseLocation)
    }

    override func rightMouseDown(with event: NSEvent) {
        showContextMenu(for: event)
    }

    private func showContextMenu(for event: NSEvent) {
        guard let menu = delegate?.petViewContextMenu(self) else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

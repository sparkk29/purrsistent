import AppKit

/// Turns a vector drawing into chunky pixel art. The drawing is rendered at a higher resolution,
/// each block becomes one pixel of its most prominent color, and the shape gets a 1-pixel outline.
enum PixelArt {
    private static let supersample = 4
    /// Fraction of a block that must be covered for it to become a solid pixel.
    private static let coverage = 0.4
    private static let shadowAlpha: UInt8 = 46

    private enum Cell: Equatable {
        case empty
        case shadow
        case color(r: Double, g: Double, b: Double)
    }

    /// `keyColor` is the main fill; colors that differ from it (eyes, mouth, belly) win ties
    /// so small details survive the downsampling.
    static func render(gridSize: Int, outline: NSColor, keyColor: NSColor, draw: (NSRect) -> Void) -> NSImage {
        let size = gridSize * supersample
        guard let source = makeBitmap(size: size), let output = makeBitmap(size: gridSize),
              let src = source.bitmapData, let dst = output.bitmapData else { return NSImage() }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: source)
        NSColor.clear.set()
        NSRect(x: 0, y: 0, width: size, height: size).fill(using: .copy)
        draw(NSRect(x: 0, y: 0, width: size, height: size))
        NSGraphicsContext.restoreGraphicsState()

        let key = components(keyColor)
        let blockArea = supersample * supersample
        var cells = [Cell](repeating: .empty, count: gridSize * gridSize)

        for cy in 0..<gridSize {
            for cx in 0..<gridSize {
                var buckets: [Int: (weight: Double, r: Double, g: Double, b: Double, count: Double)] = [:]
                var opaque = 0
                var alphaSum = 0
                for py in 0..<supersample {
                    for px in 0..<supersample {
                        let i = (cy * supersample + py) * source.bytesPerRow + (cx * supersample + px) * 4
                        let alpha = Int(src[i + 3])
                        alphaSum += alpha
                        guard alpha >= 128 else { continue }
                        opaque += 1
                        let r = min(1, Double(src[i]) / Double(alpha))
                        let g = min(1, Double(src[i + 1]) / Double(alpha))
                        let b = min(1, Double(src[i + 2]) / Double(alpha))
                        let bucketKey = Int(r * 15) << 8 | Int(g * 15) << 4 | Int(b * 15)
                        let distance = (abs(r - key.r) + abs(g - key.g) + abs(b - key.b)) / 3
                        var bucket = buckets[bucketKey] ?? (0, 0, 0, 0, 0)
                        bucket.weight += 1 + 3 * distance
                        bucket.r += r
                        bucket.g += g
                        bucket.b += b
                        bucket.count += 1
                        buckets[bucketKey] = bucket
                    }
                }
                let index = cy * gridSize + cx
                if Double(opaque) >= Double(blockArea) * coverage,
                   let best = buckets.values.max(by: { $0.weight < $1.weight }) {
                    cells[index] = .color(r: best.r / best.count, g: best.g / best.count, b: best.b / best.count)
                } else if alphaSum > blockArea * 12 {
                    cells[index] = .shadow
                }
            }
        }

        let line = components(outline)
        var outlined = cells
        for cy in 0..<gridSize {
            for cx in 0..<gridSize where !isSolid(cells[cy * gridSize + cx]) {
                let neighbors = [(cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)]
                let touchesShape = neighbors.contains { x, y in
                    x >= 0 && y >= 0 && x < gridSize && y < gridSize && isSolid(cells[y * gridSize + x])
                }
                if touchesShape { outlined[cy * gridSize + cx] = .color(r: line.r, g: line.g, b: line.b) }
            }
        }

        for cy in 0..<gridSize {
            for cx in 0..<gridSize {
                let i = cy * output.bytesPerRow + cx * 4
                switch outlined[cy * gridSize + cx] {
                case .empty:
                    dst[i] = 0; dst[i + 1] = 0; dst[i + 2] = 0; dst[i + 3] = 0
                case .shadow:
                    dst[i] = 0; dst[i + 1] = 0; dst[i + 2] = 0; dst[i + 3] = shadowAlpha
                case .color(let r, let g, let b):
                    dst[i] = UInt8(r * 255); dst[i + 1] = UInt8(g * 255); dst[i + 2] = UInt8(b * 255); dst[i + 3] = 255
                }
            }
        }

        let image = NSImage(size: NSSize(width: gridSize, height: gridSize))
        image.addRepresentation(output)
        return image
    }

    private static func isSolid(_ cell: Cell) -> Bool {
        if case .color = cell { return true }
        return false
    }

    private static func components(_ color: NSColor) -> (r: Double, g: Double, b: Double) {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        return (Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent))
    }

    private static func makeBitmap(size: Int) -> NSBitmapImageRep? {
        NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    }
}

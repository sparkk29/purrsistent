import AppKit

/// How the anime cat looks: colors, markings, and fluffiness. The rig and its animations are shared
/// by every appearance, so a new coat is just another value here.
struct CatAppearance {
    enum Markings {
        case none
        /// Mackerel tabby stripes on the back, haunch, tail, forehead, and cheeks.
        case tabby(NSColor)
        /// Darker ears, face mask, paws, and tail, like a colorpoint.
        case points(NSColor)
        /// Soft patches on the crown, one ear, the back, and the tail tip.
        case patches(NSColor)
    }

    var fur: NSColor
    /// Muzzle, chest, and belly.
    var cream: NSColor
    var outline: NSColor
    var markings: Markings = .none
    var iris: NSColor
    var innerEar = NSColor(calibratedRed: 0.97, green: 0.64, blue: 0.68, alpha: 1)
    var nose = NSColor(calibratedRed: 0.9, green: 0.52, blue: 0.55, alpha: 1)
    /// Cream paws, like white socks.
    var creamSocks = false
    var creamTailTip = false
    /// Scales the fur tufts on the cheeks, chest, and tail: 1 is a short coat.
    var fluff: CGFloat = 1

    static let orange = CatAppearance(
        fur: NSColor(calibratedRed: 0.96, green: 0.66, blue: 0.36, alpha: 1),
        cream: NSColor(calibratedRed: 1, green: 0.89, blue: 0.74, alpha: 1),
        outline: NSColor(calibratedRed: 0.45, green: 0.26, blue: 0.12, alpha: 1),
        markings: .tabby(NSColor(calibratedRed: 0.85, green: 0.47, blue: 0.2, alpha: 1)),
        iris: NSColor(calibratedRed: 0.96, green: 0.7, blue: 0.2, alpha: 1),
        creamSocks: true,
        creamTailTip: true
    )

    static let midnight = CatAppearance(
        fur: NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.21, alpha: 1),
        cream: NSColor(calibratedRed: 0.26, green: 0.26, blue: 0.31, alpha: 1),
        outline: NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.08, alpha: 1),
        iris: NSColor(calibratedRed: 0.98, green: 0.8, blue: 0.25, alpha: 1),
        innerEar: NSColor(calibratedRed: 0.95, green: 0.58, blue: 0.66, alpha: 1),
        nose: NSColor(calibratedRed: 0.62, green: 0.4, blue: 0.46, alpha: 1)
    )

    static let silver = CatAppearance(
        fur: NSColor(calibratedRed: 0.72, green: 0.74, blue: 0.78, alpha: 1),
        cream: NSColor(calibratedRed: 0.93, green: 0.94, blue: 0.96, alpha: 1),
        outline: NSColor(calibratedRed: 0.3, green: 0.32, blue: 0.36, alpha: 1),
        markings: .tabby(NSColor(calibratedRed: 0.5, green: 0.52, blue: 0.58, alpha: 1)),
        iris: NSColor(calibratedRed: 0.35, green: 0.62, blue: 0.9, alpha: 1),
        creamSocks: true,
        fluff: 1.15
    )

    static let snowball = CatAppearance(
        fur: NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.97, alpha: 1),
        cream: NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.9, alpha: 1),
        outline: NSColor(calibratedRed: 0.48, green: 0.49, blue: 0.56, alpha: 1),
        markings: .patches(NSColor(calibratedRed: 0.74, green: 0.76, blue: 0.8, alpha: 1)),
        iris: NSColor(calibratedRed: 0.45, green: 0.72, blue: 0.42, alpha: 1),
        fluff: 1.2
    )

    static let cream = CatAppearance(
        fur: NSColor(calibratedRed: 0.97, green: 0.91, blue: 0.8, alpha: 1),
        cream: NSColor(calibratedRed: 1, green: 0.97, blue: 0.92, alpha: 1),
        outline: NSColor(calibratedRed: 0.48, green: 0.41, blue: 0.36, alpha: 1),
        markings: .points(NSColor(calibratedRed: 0.56, green: 0.53, blue: 0.54, alpha: 1)),
        iris: NSColor(calibratedRed: 0.36, green: 0.64, blue: 0.97, alpha: 1),
        fluff: 1.5
    )

    static func forCoat(_ coat: Coat) -> CatAppearance {
        switch coat {
        case .orange, .custom: .orange
        case .midnight: .midnight
        case .silver: .silver
        case .snowball: .snowball
        case .cream: .cream
        }
    }

    var stripes: NSColor? {
        if case .tabby(let color) = markings { return color }
        return nil
    }

    var points: NSColor? {
        if case .points(let color) = markings { return color }
        return nil
    }

    var patches: NSColor? {
        if case .patches(let color) = markings { return color }
        return nil
    }
}

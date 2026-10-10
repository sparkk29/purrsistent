import AppKit

enum Facing {
    case left, right
}

enum AnimationKey: String, CaseIterable {
    case idle, walk, sit, sleep, drag, fall, happy

    var framesPerSecond: Double {
        switch self {
        case .idle: 4
        case .walk: 8
        case .sit: 2
        case .sleep: 1.5
        case .drag: 6
        case .fall: 6
        case .happy: 8
        }
    }
}

extension PetState {
    var animationKey: AnimationKey {
        switch self {
        case .idle: .idle
        case .walkLeft, .walkRight: .walk
        case .sit: .sit
        case .sleep: .sleep
        case .dragged: .drag
        case .falling: .fall
        case .happy: .happy
        }
    }
}

/// Frames are looked up as `<key>_0.png, <key>_1.png, ...` or as a horizontal strip `<key>.png`
/// made of square frames. Artwork faces right; left-facing frames are mirrored automatically.
@MainActor
final class SpriteAnimator {
    private var frames: [AnimationKey: [NSImage]] = [:]
    private var mirroredFrames: [AnimationKey: [NSImage]] = [:]
    private(set) var current: AnimationKey = .idle
    private var frameIndex = 0
    private var elapsed: TimeInterval = 0

    init(spriteDirectories: [URL] = SpriteAnimator.defaultSpriteDirectories()) {
        for key in AnimationKey.allCases {
            let images = Self.loadFrames(for: key, from: spriteDirectories) ?? SpriteFactory.frames(for: key)
            frames[key] = images
            mirroredFrames[key] = images.map(Self.mirrored)
        }
    }

    func play(_ key: AnimationKey) {
        guard key != current else { return }
        current = key
        frameIndex = 0
        elapsed = 0
    }

    func advance(by dt: TimeInterval) {
        let count = frames[current]?.count ?? 1
        let interval = 1 / current.framesPerSecond
        elapsed += dt
        while elapsed >= interval {
            elapsed -= interval
            frameIndex = (frameIndex + 1) % max(count, 1)
        }
    }

    func currentFrame(facing: Facing) -> NSImage? {
        let set = facing == .right ? frames[current] : mirroredFrames[current]
        guard let set, !set.isEmpty else { return nil }
        return set[frameIndex % set.count]
    }

    nonisolated static func defaultSpriteDirectories() -> [URL] {
        var directories: [URL] = []
        if let resources = Bundle.main.resourceURL {
            directories.append(resources.appendingPathComponent("Sprites", isDirectory: true))
        }
        let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        directories.append(workingDirectory.appendingPathComponent("Resources/Sprites", isDirectory: true))
        return directories
    }

    private static func loadFrames(for key: AnimationKey, from directories: [URL]) -> [NSImage]? {
        for directory in directories {
            var sequence: [NSImage] = []
            while let image = NSImage(contentsOf: directory.appendingPathComponent("\(key.rawValue)_\(sequence.count).png")) {
                sequence.append(image)
            }
            if !sequence.isEmpty { return sequence }

            if let sheet = NSImage(contentsOf: directory.appendingPathComponent("\(key.rawValue).png")),
               let sliced = slice(sheet), !sliced.isEmpty {
                return sliced
            }
        }
        return nil
    }

    private static func slice(_ sheet: NSImage) -> [NSImage]? {
        guard let cgImage = sheet.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let side = cgImage.height
        guard side > 0, cgImage.width >= side else { return nil }
        return (0..<(cgImage.width / side)).compactMap { index in
            cgImage.cropping(to: CGRect(x: index * side, y: 0, width: side, height: side)).map {
                NSImage(cgImage: $0, size: NSSize(width: side, height: side))
            }
        }
    }

    private static func mirrored(_ image: NSImage) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            let transform = NSAffineTransform()
            transform.translateX(by: rect.width, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
            transform.concat()
            image.draw(in: rect)
            return true
        }
    }
}

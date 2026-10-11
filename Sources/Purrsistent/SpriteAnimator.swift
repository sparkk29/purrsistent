import AppKit

enum Facing {
    case left, right
}

enum AnimationKey: String, CaseIterable {
    case idle, walk, sit, sleep, drag, fall, happy, petted, yawn, groom, eat

    var framesPerSecond: Double {
        switch self {
        case .eat: 6
        case .yawn: 5
        case .groom: 4
        case .idle: 4
        case .walk: 8
        case .sit: 2
        case .sleep: 1.5
        case .drag: 6
        case .fall: 6
        case .happy: 8
        case .petted: 3
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
        case .petted: .petted
        case .yawn: .yawn
        case .groom: .groom
        case .eating: .eat
        }
    }
}

/// The `.custom` coat loads frames from the sprite directories, as `<key>_0.png, <key>_1.png, ...`
/// or a horizontal strip `<key>.png` of square frames; anything missing falls back to the built-in cat.
/// Artwork faces right; left-facing frames are mirrored automatically.
@MainActor
final class SpriteAnimator {
    private let spriteDirectories: [URL]
    private var frames: [AnimationKey: [NSImage]] = [:]
    private var mirroredFrames: [AnimationKey: [NSImage]] = [:]
    private(set) var coat: Coat?
    private(set) var current: AnimationKey = .idle
    private var frameIndex = 0
    private var elapsed: TimeInterval = 0

    init(coat: Coat, spriteDirectories: [URL] = SpriteAnimator.defaultSpriteDirectories()) {
        self.spriteDirectories = spriteDirectories
        load(coat: coat)
    }

    func load(coat: Coat) {
        guard coat != self.coat else { return }
        self.coat = coat
        let palette = SpriteFactory.Palette.forCoat(coat)
        for key in AnimationKey.allCases {
            let custom = coat == .custom ? Self.loadFrames(for: key, from: spriteDirectories) : nil
            let images = custom ?? SpriteFactory.frames(for: key, palette: palette)
            frames[key] = images
            mirroredFrames[key] = images.map(Self.mirrored)
        }
    }

    nonisolated static func hasCustomSprites(in directories: [URL] = defaultSpriteDirectories()) -> Bool {
        directories.contains { directory in
            let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            return files.contains { $0.lowercased().hasSuffix(".png") }
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

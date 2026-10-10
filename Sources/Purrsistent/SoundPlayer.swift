import AVFoundation

enum SoundEffect: String, CaseIterable {
    case meow, chirp, thud, purr
}

/// Sounds are looked up as `<name>.<ext>` or variations `<name>_0.<ext>, <name>_1.<ext>, ...`
/// (one is picked at random). Missing sounds fall back to the synthesized placeholders.
@MainActor
final class SoundPlayer {
    private static let extensions = ["wav", "aiff", "aif", "caf", "mp3", "m4a"]

    private var clips: [SoundEffect: [Data]] = [:]
    private var activePlayers: [AVAudioPlayer] = []
    private var loopPlayer: AVAudioPlayer?
    private var loopEffect: SoundEffect?
    private var loopVolume: Float = 1

    var isEnabled = true {
        didSet {
            if !isEnabled { stopLoop() }
        }
    }

    var masterVolume: Float = 0.6 {
        didSet { loopPlayer?.volume = loopVolume * masterVolume }
    }

    init(soundDirectories: [URL] = SoundPlayer.defaultSoundDirectories()) {
        for effect in SoundEffect.allCases {
            clips[effect] = Self.loadClips(for: effect, from: soundDirectories) ?? SoundFactory.clips(for: effect)
        }
    }

    func play(_ effect: SoundEffect, volume: Float = 1) {
        guard isEnabled,
              let data = clips[effect]?.randomElement(),
              let player = try? AVAudioPlayer(data: data) else { return }
        activePlayers.removeAll { !$0.isPlaying }
        player.volume = volume * masterVolume
        player.play()
        activePlayers.append(player)
    }

    func startLoop(_ effect: SoundEffect, volume: Float = 1) {
        guard isEnabled else { return }
        if loopEffect == effect, loopPlayer?.isPlaying == true { return }
        stopLoop()
        guard let data = clips[effect]?.randomElement(),
              let player = try? AVAudioPlayer(data: data) else { return }
        player.numberOfLoops = -1
        player.volume = 0
        player.play()
        player.setVolume(volume * masterVolume, fadeDuration: 1.5)
        loopPlayer = player
        loopEffect = effect
        loopVolume = volume
    }

    func stopLoop() {
        loopPlayer?.stop()
        loopPlayer = nil
        loopEffect = nil
    }

    nonisolated static func defaultSoundDirectories() -> [URL] {
        var directories: [URL] = []
        if let resources = Bundle.main.resourceURL {
            directories.append(resources.appendingPathComponent("Sounds", isDirectory: true))
        }
        let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        directories.append(workingDirectory.appendingPathComponent("Resources/Sounds", isDirectory: true))
        return directories
    }

    private static func loadClips(for effect: SoundEffect, from directories: [URL]) -> [Data]? {
        for directory in directories {
            var found: [Data] = []
            for ext in extensions {
                if let data = try? Data(contentsOf: directory.appendingPathComponent("\(effect.rawValue).\(ext)")) {
                    found.append(data)
                }
                var index = 0
                while let data = try? Data(contentsOf: directory.appendingPathComponent("\(effect.rawValue)_\(index).\(ext)")) {
                    found.append(data)
                    index += 1
                }
            }
            if !found.isEmpty { return found }
        }
        return nil
    }
}

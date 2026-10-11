import AVFoundation

enum SoundEffect: String, CaseIterable {
    case meow, chirp, thud, purr
}

/// Sounds are looked up as `<name>.<ext>` or variations `<name>_0.<ext>, <name>_1.<ext>, ...`
/// (one is picked at random), first in the voice's folder, then in the shared sounds folder.
/// Missing sounds fall back to the synthesized placeholders.
@MainActor
final class SoundPlayer {
    private nonisolated static let extensions = ["wav", "aiff", "aif", "caf", "mp3", "m4a"]

    private let soundDirectories: [URL]
    private var voice: Voice?
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

    init(voice: Voice, soundDirectories: [URL] = SoundPlayer.defaultSoundDirectories()) {
        self.soundDirectories = soundDirectories
        load(voice: voice)
    }

    func load(voice: Voice) {
        guard voice != self.voice else { return }
        self.voice = voice
        let directories = soundDirectories.map { $0.appendingPathComponent(voice.folder, isDirectory: true) } + soundDirectories
        for effect in SoundEffect.allCases {
            clips[effect] = Self.loadClips(for: effect, from: directories) ?? SoundFactory.clips(for: effect)
        }
    }

    nonisolated static func hasCustomVoice(in directories: [URL] = defaultSoundDirectories()) -> Bool {
        directories.contains { directory in
            let folder = directory.appendingPathComponent(Voice.custom.folder, isDirectory: true)
            let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            return files.contains { extensions.contains(($0 as NSString).pathExtension.lowercased()) }
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

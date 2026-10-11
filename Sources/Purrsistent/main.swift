import AppKit

let arguments = CommandLine.arguments

/// Handles `--<flag> [path]` asset-export commands, exiting the process when the flag is present.
func runExport(flag: String, defaultPath: String, label: String, _ export: (URL) throws -> Void) {
    guard let index = arguments.firstIndex(of: flag) else { return }
    let path = index + 1 < arguments.count ? arguments[index + 1] : defaultPath
    let url = URL(fileURLWithPath: path)
    do {
        try export(url)
        print("Exported \(label) to \(url.path)")
        exit(0)
    } catch {
        FileHandle.standardError.write("Failed to export \(label): \(error)\n".data(using: .utf8)!)
        exit(1)
    }
}

/// The value following `flag`, if any.
func option(_ flag: String) -> String? {
    arguments.firstIndex(of: flag).flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
}

runExport(flag: "--export-sprites", defaultPath: "Resources/Sprites", label: "placeholder sprites") { url in
    let coat = option("--coat").flatMap(Coat.init(rawValue:)) ?? .orange
    let style = option("--style").flatMap(ArtStyle.init(rawValue:)) ?? .cartoon
    try SpriteFactory.exportPNGs(to: url, coat: coat, style: style)
}
runExport(flag: "--export-anime-preview", defaultPath: "AnimePreview", label: "anime preview sheets") {
    try AnimePreview.export(to: $0)
}
runExport(flag: "--export-sounds", defaultPath: "SynthesizedSounds", label: "synthesized sounds") {
    try SoundFactory.exportWAVs(to: $0)
}
runExport(flag: "--export-iconset", defaultPath: "AppIcon.iconset", label: "app iconset") {
    try IconFactory.exportIconset(to: $0)
}
runExport(flag: "--export-logo", defaultPath: "assets/logo.png", label: "logo") { url in
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try IconFactory.png(pixelSize: 512)?.write(to: url)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}

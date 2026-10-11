import AppKit
import ServiceManagement

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let pet: PetController
    private let settings: Settings

    init(pet: PetController, settings: Settings) {
        self.pet = pet
        self.settings = settings
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Purrsistent")
            image?.isTemplate = true
            button.image = image
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        populate(menu)
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        populate(menu)
    }

    private func populate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false

        menu.addItem(item(pet.isVisible ? "Hide Pet" : "Show Pet") { [pet] in pet.setVisible(!pet.isVisible) })
        menu.addItem(.separator())

        let mood = NSMenuItem(title: "Mood: \(pet.moodLabel)", action: nil, keyEquivalent: "")
        mood.isEnabled = false
        menu.addItem(mood)
        let treat = item("Give Treat") { [pet] in pet.giveTreat() }
        treat.isEnabled = pet.isVisible && !pet.hasTreat
        menu.addItem(treat)
        menu.addItem(.separator())

        let coats = Coat.allCases.filter { $0 != .custom || SpriteAnimator.hasCustomSprites() || settings.coat == .custom }
        menu.addItem(choices("Coat", coats, selected: settings.coat, title: \.title) { [settings] in settings.coat = $0 })
        let style = choices("Style", ArtStyle.allCases, selected: settings.style, title: \.title) { [settings] in settings.style = $0 }
        style.isEnabled = settings.coat != .custom
        menu.addItem(style)
        menu.addItem(choices("Size", PetSize.allCases, selected: settings.size, title: \.title) { [settings] in settings.size = $0 })
        menu.addItem(choices("Speed", PetSpeed.allCases, selected: settings.speed, title: \.title) { [settings] in settings.speed = $0 })
        menu.addItem(toggle("Stay Still", isOn: settings.stayStill) { [settings] in settings.stayStill.toggle() })
        menu.addItem(.separator())

        menu.addItem(toggle("Sounds", isOn: settings.soundEnabled) { [settings] in settings.soundEnabled.toggle() })
        let voices = Voice.allCases.filter { $0 != .custom || SoundPlayer.hasCustomVoice() || settings.voice == .custom }
        menu.addItem(choices("Voice", voices, selected: settings.voice, title: \.title) { [settings, pet] in
            settings.voice = $0
            pet.previewSound()
        })
        menu.addItem(choices("Volume", SoundVolume.allCases, selected: settings.soundVolume, title: \.title) { [settings, pet] in
            settings.soundVolume = $0
            pet.previewSound()
        })
        menu.addItem(.separator())

        menu.addItem(choices("Break Reminders", BreakInterval.allCases, selected: settings.breakInterval, title: \.title) { [settings] in
            settings.breakInterval = $0
        })
        menu.addItem(.separator())

        menu.addItem(toggle("Launch at Login", isOn: SMAppService.mainApp.status == .enabled) { [weak self] in
            self?.toggleLaunchAtLogin()
        })
        menu.addItem(.separator())
        menu.addItem(item("Quit Purrsistent", key: "q") { NSApp.terminate(nil) })
    }

    // MARK: - Item builders

    /// Holds a menu item's handler, since `NSMenuItem` only supports target/selector actions.
    private final class Action: NSObject {
        let handler: () -> Void
        init(_ handler: @escaping () -> Void) { self.handler = handler }
    }

    private func item(_ title: String, key: String = "", _ handler: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(runAction(_:)), keyEquivalent: key)
        item.target = self
        item.representedObject = Action(handler)
        return item
    }

    private func toggle(_ title: String, isOn: Bool, _ handler: @escaping () -> Void) -> NSMenuItem {
        let item = item(title, handler)
        item.state = isOn ? .on : .off
        return item
    }

    private func choices<Option: Equatable>(
        _ title: String,
        _ options: [Option],
        selected: Option,
        title optionTitle: (Option) -> String,
        _ select: @escaping (Option) -> Void
    ) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for option in options {
            submenu.addItem(toggle(optionTitle(option), isOn: option == selected) { select(option) })
        }
        parent.submenu = submenu
        return parent
    }

    @objc private func runAction(_ sender: NSMenuItem) {
        (sender.representedObject as? Action)?.handler()
    }

    private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            pet.showConfusion()
            let alert = NSAlert()
            alert.messageText = "Couldn't update Launch at Login"
            alert.informativeText = "\(error.localizedDescription)\n\nLaunch at Login only works when running the bundled Purrsistent.app."
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}

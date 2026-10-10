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

        menu.addItem(item(pet.isVisible ? "Hide Pet" : "Show Pet", action: #selector(toggleVisibility)))
        menu.addItem(.separator())

        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for size in PetSize.allCases {
            let option = item(size.title, action: #selector(selectSize(_:)))
            option.representedObject = size.rawValue
            option.state = settings.size == size ? .on : .off
            sizeMenu.addItem(option)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let speedItem = NSMenuItem(title: "Speed", action: nil, keyEquivalent: "")
        let speedMenu = NSMenu()
        for speed in PetSpeed.allCases {
            let option = item(speed.title, action: #selector(selectSpeed(_:)))
            option.representedObject = speed.rawValue
            option.state = settings.speed == speed ? .on : .off
            speedMenu.addItem(option)
        }
        speedItem.submenu = speedMenu
        menu.addItem(speedItem)

        let stayStill = item("Stay Still", action: #selector(toggleStayStill))
        stayStill.state = settings.stayStill ? .on : .off
        menu.addItem(stayStill)

        menu.addItem(.separator())

        let sounds = item("Sounds", action: #selector(toggleSounds))
        sounds.state = settings.soundEnabled ? .on : .off
        menu.addItem(sounds)

        let volumeItem = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
        let volumeMenu = NSMenu()
        for volume in SoundVolume.allCases {
            let option = item(volume.title, action: #selector(selectVolume(_:)))
            option.representedObject = volume.rawValue
            option.state = settings.soundVolume == volume ? .on : .off
            volumeMenu.addItem(option)
        }
        volumeItem.submenu = volumeMenu
        menu.addItem(volumeItem)

        menu.addItem(.separator())

        let launchAtLogin = item("Launch at Login", action: #selector(toggleLaunchAtLogin))
        launchAtLogin.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchAtLogin)

        menu.addItem(.separator())
        menu.addItem(item("Quit Purrsistent", action: #selector(quit), key: "q"))
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func toggleVisibility() {
        pet.setVisible(!pet.isVisible)
    }

    @objc private func selectSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let size = PetSize(rawValue: raw) else { return }
        settings.size = size
    }

    @objc private func selectSpeed(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let speed = PetSpeed(rawValue: raw) else { return }
        settings.speed = speed
    }

    @objc private func toggleStayStill() {
        settings.stayStill.toggle()
    }

    @objc private func toggleSounds() {
        settings.soundEnabled.toggle()
    }

    @objc private func selectVolume(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let volume = SoundVolume(rawValue: raw) else { return }
        settings.soundVolume = volume
        pet.previewSound()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't update Launch at Login"
            alert.informativeText = "\(error.localizedDescription)\n\nLaunch at Login only works when running the bundled Purrsistent.app."
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

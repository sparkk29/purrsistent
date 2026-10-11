import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pet: PetController?
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = Settings.shared
        let pet = PetController(settings: settings)
        let menuBar = MenuBarController(pet: pet, settings: settings)
        pet.contextMenuProvider = { [weak menuBar] in menuBar?.makeMenu() }
        pet.start()

        self.pet = pet
        self.menuBar = menuBar
    }

    func applicationWillTerminate(_ notification: Notification) {
        pet?.saveState()
    }
}

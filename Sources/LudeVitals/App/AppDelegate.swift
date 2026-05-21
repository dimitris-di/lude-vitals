import AppKit
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    let scheduler = SamplingScheduler(interval: 2.0)
    let settings = AppSettings.shared
    var statusController: StatusItemController?
    lazy var prefsController = PreferencesWindowController(settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        scheduler.cpuSampler     = CPUSampler()
        scheduler.memorySampler  = MemorySampler()
        scheduler.networkSampler = NetworkSampler()
        scheduler.batterySampler = BatterySampler()
        scheduler.thermalSampler = ThermalSampler()
        scheduler.setInterval(settings.sampleInterval)
        statusController = StatusItemController(scheduler: scheduler, settings: settings)
        scheduler.start()
        installMainMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        scheduler.stop()
    }

    private func installMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About LudeVitals", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let prefs = NSMenuItem(title: "Settings…", action: #selector(openPreferences), keyEquivalent: ",")
        prefs.target = self
        appMenu.addItem(prefs)
        appMenu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit LudeVitals", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quit)
        appItem.submenu = appMenu
        main.addItem(appItem)
        NSApp.mainMenu = main
    }

    @objc func openPreferences() {
        prefsController.show()
    }
}

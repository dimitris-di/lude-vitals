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
        statusController = StatusItemController(scheduler: scheduler, settings: settings)
        scheduler.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        scheduler.stop()
    }
}

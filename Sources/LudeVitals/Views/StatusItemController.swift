import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let scheduler: SamplingScheduler
    private let settings: AppSettings
    private let popover: NSPopover
    private let host: NSHostingView<MenuBarLabel>
    private var cancellables: Set<AnyCancellable> = []

    init(scheduler: SamplingScheduler, settings: AppSettings) {
        self.scheduler = scheduler
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        pop.contentSize = NSSize(width: 400, height: 580)
        pop.contentViewController = NSHostingController(
            rootView: PopoverRoot(scheduler: scheduler, settings: settings)
        )
        self.popover = pop

        self.host = NSHostingView(rootView: MenuBarLabel(scheduler: scheduler, settings: settings))
        super.init()

        if let button = statusItem.button {
            button.image = nil
            host.frame = NSRect(x: 0, y: 0, width: 60, height: NSStatusBar.system.thickness)
            button.addSubview(host)
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        scheduler.$latest
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.resize() }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.resize() }
            }
            .store(in: &cancellables)

        resize()
    }

    private func resize() {
        host.layoutSubtreeIfNeeded()
        let fitting = host.fittingSize
        let width = max(28, ceil(fitting.width))
        let height = NSStatusBar.system.thickness
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        statusItem.length = width
        if let button = statusItem.button {
            button.frame = NSRect(x: 0, y: 0, width: width, height: height)
        }
    }

    @objc private func handleClick(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            scheduler.setInterval(2.0)
        } else {
            scheduler.setInterval(1.0)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let prefs = NSMenuItem(title: "Preferences…", action: #selector(openPrefs), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit LudeVitals", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openPrefs() {
        (NSApp.delegate as? AppDelegate)?.prefsController.show()
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

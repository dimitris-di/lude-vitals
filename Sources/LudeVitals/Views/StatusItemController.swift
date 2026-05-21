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
    private var lastWidth: CGFloat = -1
    private let popoverSampleInterval: TimeInterval = 1.0

    init(scheduler: SamplingScheduler, settings: AppSettings) {
        self.scheduler = scheduler
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem.behavior = .removalAllowed
        self.statusItem.autosaveName = "LudeVitalsStatusItem"

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
        popover.delegate = self

        if let button = statusItem.button {
            button.image = nil
            host.frame = NSRect(x: 0, y: 0, width: 60, height: NSStatusBar.system.thickness)
            button.addSubview(host)
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "LudeVitals"
        }

        scheduler.$latest
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.resize()
                self?.updateButtonAccessibility()
            }
            .store(in: &cancellables)

        settings.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.resize()
                    self?.updateButtonAccessibility()
                    self?.applySavedIntervalIfPopoverClosed()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.applySavedIntervalIfPopoverClosed() }
            .store(in: &cancellables)

        resize()
        updateButtonAccessibility()
        applySavedIntervalIfPopoverClosed()
    }

    private func resize() {
        host.layoutSubtreeIfNeeded()
        let fitting = host.fittingSize
        let width = max(28, ceil(fitting.width))
        if width == lastWidth { return }
        lastWidth = width
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
        } else {
            scheduler.setInterval(popoverSampleInterval)
            setPopoverSamplingEnabled(true)
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func applySavedIntervalIfPopoverClosed() {
        guard !popover.isShown else { return }
        scheduler.setInterval(settings.sampleInterval)
    }

    private func cleanupAfterPopoverClosed() {
        setPopoverSamplingEnabled(false)
        scheduler.setInterval(settings.sampleInterval)
    }

    private func setPopoverSamplingEnabled(_ enabled: Bool) {
        scheduler.popoverIsOpen = enabled
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let prefs = NSMenuItem(title: "Settings…", action: #selector(openPrefs), keyEquivalent: ",")
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

    private func updateButtonAccessibility() {
        guard let button = statusItem.button else { return }
        let value = accessibilitySummary()
        button.toolTip = value
        button.setAccessibilityLabel("LudeVitals")
        button.setAccessibilityValue(value)
        button.setAccessibilityHelp("Press to open details. Right-click for Settings and Quit.")
    }

    private func accessibilitySummary() -> String {
        let s = scheduler.latest
        if s.timestamp == .distantPast { return "LudeVitals loading system vitals" }

        let cpu = Int((s.cpu.totalUsage * 100).rounded())
        let memory = Int((s.memory.usagePercent * 100).rounded())
        var parts = ["CPU \(cpu) percent", "memory \(memory) percent"]
        if let c = s.thermal.cpuTemperature, c > 3 {
            let temp = Int(settings.tempUnit.convert(c).rounded())
            parts.append("temperature \(temp) \(settings.tempUnit.symbol)")
        }
        return "LudeVitals, " + parts.joined(separator: ", ")
    }
}

extension StatusItemController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        cleanupAfterPopoverClosed()
    }
}

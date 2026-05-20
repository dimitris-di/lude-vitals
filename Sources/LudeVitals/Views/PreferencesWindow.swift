import AppKit
import SwiftUI
import ServiceManagement

@MainActor
final class PreferencesWindowController {
    private var window: NSWindow?
    private let settings: AppSettings

    init(settings: AppSettings) { self.settings = settings }

    func show() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let root = PreferencesView(settings: settings)
        let host = NSHostingController(rootView: root)
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "LudeVitals Preferences"
        w.contentViewController = host
        w.isReleasedWhenClosed = false
        w.center()
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct PreferencesView: View {
    @ObservedObject var settings: AppSettings
    @State private var launchAtLoginRegistered: Bool = false

    var body: some View {
        Form {
            Section("Menu bar display") {
                Picker("Mode", selection: $settings.displayMode) {
                    ForEach(DisplayMode.allCases) { Text($0.label).tag($0) }
                }
                if settings.displayMode == .custom {
                    Toggle("Show CPU",         isOn: customBinding(\.showCPU))
                    Toggle("Show Memory",      isOn: customBinding(\.showMemory))
                    Toggle("Show Temperature", isOn: customBinding(\.showTemperature))
                    Toggle("Show Network",     isOn: customBinding(\.showNetwork))
                    Toggle("Show Sparkline",   isOn: customBinding(\.showSparkline))
                }
            }
            Section("Units & sampling") {
                Picker("Temperature unit", selection: $settings.tempUnit) {
                    ForEach(TempUnit.allCases) { Text($0.symbol).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)

                HStack {
                    Text("Sample interval")
                    Slider(value: $settings.sampleInterval, in: 1.0...5.0, step: 0.5)
                    Text("\(settings.sampleInterval, specifier: "%.1f")s")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { v in
                        settings.launchAtLogin = v
                        applyLaunchAtLogin(v)
                    }
                ))
            }
            Section {
                HStack {
                    Text("LudeVitals 0.1.0")
                    Spacer()
                    Button("Quit") { NSApp.terminate(nil) }
                }
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 420)
        .onAppear { launchAtLoginRegistered = settings.launchAtLogin }
    }

    private func customBinding(_ key: WritableKeyPath<CustomDisplayOptions, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings.customOptions[keyPath: key] },
            set: { settings.customOptions[keyPath: key] = $0 }
        )
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        let svc = SMAppService.mainApp
        do {
            if enabled {
                if svc.status != .enabled { try svc.register() }
            } else {
                if svc.status == .enabled { try svc.unregister() }
            }
        } catch {
            // surface in console; do not crash
            NSLog("LudeVitals: launch-at-login toggle failed: \(error.localizedDescription)")
        }
    }
}

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
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = "LudeVitals Settings"
        w.minSize = NSSize(width: 420, height: 420)
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
    @State private var launchAtLoginMessage: String?
    @State private var launchAtLoginMessageIsError = false

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

                VStack(alignment: .leading, spacing: 6) {
                    Text("Sample interval")
                    HStack(spacing: 12) {
                        Slider(value: $settings.sampleInterval, in: 1.0...5.0, step: 0.5)
                            .accessibilityLabel("Sample interval")
                            .accessibilityValue(sampleIntervalAccessibilityValue)
                            .accessibilityHint("Adjusts how often LudeVitals samples system metrics.")
                        Text(sampleIntervalDisplayValue)
                            .monospacedDigit()
                            .frame(minWidth: 48, alignment: .trailing)
                            .accessibilityHidden(true)
                    }
                }
            }
            Section("Startup") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Launch at login", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { applyLaunchAtLogin($0) }
                    ))
                    .accessibilityHint("Starts LudeVitals automatically when you sign in.")

                    if let launchAtLoginMessage {
                        Text(launchAtLoginMessage)
                            .font(.footnote)
                            .foregroundColor(launchAtLoginMessageIsError ? .red : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel(launchAtLoginMessageIsError ? "Launch at login error" : "Launch at login status")
                    }
                }
            }
            Section {
                HStack {
                    Text("LudeVitals \(appVersionString)")
                    Spacer()
                    Button("Quit") { NSApp.terminate(nil) }
                }
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(
            minWidth: 420,
            idealWidth: 460,
            maxWidth: 640,
            minHeight: 420,
            idealHeight: 460,
            maxHeight: 720
        )
        .onAppear { refreshLaunchAtLoginStatus() }
    }

    private var appVersionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (s?, b?) where s != b: return "\(s) (\(b))"
        case let (s?, _): return s
        case (_, let b?): return b
        default: return "(unknown)"
        }
    }

    private var sampleIntervalDisplayValue: String {
        String(format: "%.1fs", settings.sampleInterval)
    }

    private var sampleIntervalAccessibilityValue: String {
        String(format: "%.1f seconds", settings.sampleInterval)
    }

    private func customBinding(_ key: WritableKeyPath<CustomDisplayOptions, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings.customOptions[keyPath: key] },
            set: { settings.customOptions[keyPath: key] = $0 }
        )
    }

    private func refreshLaunchAtLoginStatus() {
        let status = settings.refreshLaunchAtLoginStatus()
        setLaunchAtLoginMessage(for: status, requestedEnabled: nil)
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            let status = try settings.setLaunchAtLogin(enabled)
            setLaunchAtLoginMessage(for: status, requestedEnabled: enabled)
        } catch {
            _ = settings.refreshLaunchAtLoginStatus()
            launchAtLoginMessage = "Could not \(enabled ? "enable" : "disable") launch at login. \(error.localizedDescription)"
            launchAtLoginMessageIsError = true
            NSLog("LudeVitals: launch-at-login toggle failed: \(error.localizedDescription)")
        }
    }

    private func setLaunchAtLoginMessage(for status: SMAppService.Status, requestedEnabled: Bool?) {
        switch status {
        case .enabled:
            if requestedEnabled == false {
                launchAtLoginMessage = "Launch at login is still enabled in System Settings."
                launchAtLoginMessageIsError = true
            } else {
                launchAtLoginMessage = nil
                launchAtLoginMessageIsError = false
            }
        case .requiresApproval:
            launchAtLoginMessage = "Allow LudeVitals in System Settings to finish enabling launch at login."
            launchAtLoginMessageIsError = true
        case .notRegistered:
            if requestedEnabled == true {
                launchAtLoginMessage = "Launch at login did not enable. Try again from System Settings."
                launchAtLoginMessageIsError = true
            } else {
                launchAtLoginMessage = nil
                launchAtLoginMessageIsError = false
            }
        case .notFound:
            launchAtLoginMessage = "Launch at login is unavailable for this app bundle."
            launchAtLoginMessageIsError = true
        @unknown default:
            launchAtLoginMessage = "Launch at login status could not be confirmed."
            launchAtLoginMessageIsError = true
        }
    }
}

import Combine
import Foundation
import SwiftUI

enum DisplayMode: String, CaseIterable, Codable, Identifiable {
    case minimal, balanced, full, custom
    var id: String { rawValue }
    var label: String {
        switch self {
        case .minimal:  return "Minimal — Temp only"
        case .balanced: return "Balanced — Temp + RAM"
        case .full:     return "Full — CPU · RAM · Temp · Net"
        case .custom:   return "Custom"
        }
    }
}

struct CustomDisplayOptions: Codable, Equatable {
    var showCPU: Bool = true
    var showMemory: Bool = true
    var showTemperature: Bool = true
    var showNetwork: Bool = false
    var showSparkline: Bool = false
}

enum TempUnit: String, CaseIterable, Codable, Identifiable {
    case celsius, fahrenheit
    var id: String { rawValue }
    var symbol: String { self == .celsius ? "°C" : "°F" }
    func convert(_ celsius: Double) -> Double {
        self == .celsius ? celsius : celsius * 9 / 5 + 32
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("displayMode") var displayMode: DisplayMode = .balanced
    @AppStorage("sampleInterval") var sampleInterval: Double = 2.0
    @AppStorage("tempUnit") var tempUnit: TempUnit = .celsius
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    @Published var customOptions: CustomDisplayOptions

    private var cancellables = Set<AnyCancellable>()

    private init() {
        if let data = UserDefaults.standard.data(forKey: "customOptions"),
           let decoded = try? JSONDecoder().decode(CustomDisplayOptions.self, from: data) {
            self.customOptions = decoded
        } else {
            self.customOptions = CustomDisplayOptions()
        }

        $customOptions
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] options in self?.persist(options) }
            .store(in: &cancellables)
    }

    private func persist(_ opts: CustomDisplayOptions) {
        if let data = try? JSONEncoder().encode(opts) {
            UserDefaults.standard.set(data, forKey: "customOptions")
        }
    }
}

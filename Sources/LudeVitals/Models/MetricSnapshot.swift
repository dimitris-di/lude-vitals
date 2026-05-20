import Foundation

struct MetricSnapshot: Sendable {
    let timestamp: Date
    let cpu: CPUMetrics
    let memory: MemoryMetrics
    let thermal: ThermalMetrics
    let network: NetworkMetrics
    let battery: BatteryMetrics?
}

// MARK: - CPU

struct CPUMetrics: Sendable {
    let totalUsage: Double          // 0...1
    let userUsage: Double
    let systemUsage: Double
    let idleUsage: Double
    let perCore: [CoreUsage]
    let pCoreAverage: Double?
    let eCoreAverage: Double?
    let loadAverage: LoadAverage
    let topProcesses: [ProcessUsage]

    static let zero = CPUMetrics(
        totalUsage: 0, userUsage: 0, systemUsage: 0, idleUsage: 1,
        perCore: [], pCoreAverage: nil, eCoreAverage: nil,
        loadAverage: .init(one: 0, five: 0, fifteen: 0),
        topProcesses: []
    )
}

struct CoreUsage: Sendable, Identifiable {
    let id: Int
    let usage: Double               // 0...1
    let type: CoreType
}

enum CoreType: Sendable { case performance, efficiency, unknown }

struct LoadAverage: Sendable {
    let one: Double
    let five: Double
    let fifteen: Double
}

struct ProcessUsage: Sendable, Identifiable {
    let id: Int32                   // pid
    let name: String
    let cpu: Double                 // 0...1
    let memoryBytes: UInt64
}

// MARK: - Memory

struct MemoryMetrics: Sendable {
    let total: UInt64
    let used: UInt64
    let app: UInt64
    let wired: UInt64
    let compressed: UInt64
    let cached: UInt64
    let free: UInt64
    let swapUsed: UInt64
    let swapTotal: UInt64
    let pressure: MemoryPressure

    var usagePercent: Double { total == 0 ? 0 : Double(used) / Double(total) }

    static let zero = MemoryMetrics(
        total: 0, used: 0, app: 0, wired: 0, compressed: 0,
        cached: 0, free: 0, swapUsed: 0, swapTotal: 0, pressure: .normal
    )
}

enum MemoryPressure: Sendable { case normal, warning, critical }

// MARK: - Thermal

struct ThermalMetrics: Sendable {
    let cpuTemperature: Double?     // °C
    let gpuTemperature: Double?
    let batteryTemperature: Double?
    let peripheralTemperature: Double?
    let fans: [FanReading]
    let thermalPressure: ThermalPressure

    static let zero = ThermalMetrics(
        cpuTemperature: nil, gpuTemperature: nil, batteryTemperature: nil,
        peripheralTemperature: nil, fans: [], thermalPressure: .nominal
    )
}

struct FanReading: Sendable, Identifiable {
    let id: Int
    let label: String
    let rpm: Int
    let minRPM: Int
    let maxRPM: Int
}

enum ThermalPressure: Sendable { case nominal, fair, serious, critical }

// MARK: - Network

struct NetworkMetrics: Sendable {
    let bytesInPerSec: UInt64
    let bytesOutPerSec: UInt64
    let totalBytesIn: UInt64
    let totalBytesOut: UInt64
    let primaryInterface: String?

    static let zero = NetworkMetrics(
        bytesInPerSec: 0, bytesOutPerSec: 0,
        totalBytesIn: 0, totalBytesOut: 0, primaryInterface: nil
    )
}

// MARK: - Battery

struct BatteryMetrics: Sendable {
    let percentage: Double          // 0...1
    let isCharging: Bool
    let isPluggedIn: Bool
    let timeRemainingMinutes: Int?
    let cycleCount: Int?
    let health: Double?             // 0...1
    let wattage: Double?            // signed: negative = discharging
}

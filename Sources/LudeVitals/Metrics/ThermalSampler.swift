import Foundation
import IOKit
import Darwin

final class ThermalSampler: AnySampler {
    typealias Output = ThermalMetrics

    private let hid = IOHIDThermalReader()
    private let smc = SMCFanReader()

    func sample() -> ThermalMetrics {
        let readings = hid.read()

        func avg(_ predicate: (String) -> Bool) -> Double? {
            let vals = readings.filter { predicate($0.name) }.map(\.value)
            guard !vals.isEmpty else { return nil }
            return vals.reduce(0, +) / Double(vals.count)
        }

        let cpu = avg { n in
            let l = n
            return l.contains("pACC") || l.contains("eACC") || l.contains("CPU") || l.contains("PMU tdie")
        } ?? avg { $0.contains("tdie") }

        let gpu = avg { $0.contains("GPU") || $0.contains("gACC") }
        let battery = readings.first { $0.name.lowercased().contains("battery") }?.value
        let peripheral = avg { $0.contains("airflow") || $0.contains("NAND") }

        return ThermalMetrics(
            cpuTemperature: cpu,
            gpuTemperature: gpu,
            batteryTemperature: battery,
            peripheralTemperature: peripheral,
            fans: smc.readFans(),
            thermalPressure: Self.pressure()
        )
    }

    private static func pressure() -> ThermalPressure {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:  return .nominal
        case .fair:     return .fair
        case .serious:  return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }
}

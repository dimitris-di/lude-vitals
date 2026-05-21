import Foundation
import IOKit
import Darwin

@MainActor
final class ThermalSampler: AnySampler {
    typealias Output = ThermalMetrics

    private let hid = IOHIDThermalReader()
    private let smc = SMCFanReader()

    func sample(context: SamplingContext) async -> ThermalMetrics {
        let readings = hid.read()

        var cpuSum = 0.0, cpuCount = 0
        var tdieSum = 0.0, tdieCount = 0
        var gpuSum = 0.0, gpuCount = 0
        var periphSum = 0.0, periphCount = 0
        var battery: Double?

        for r in readings {
            let n = r.name
            if n.contains("pACC") || n.contains("eACC") || n.contains("CPU") || n.contains("PMU tdie") {
                cpuSum += r.value; cpuCount += 1
            }
            if n.contains("tdie") {
                tdieSum += r.value; tdieCount += 1
            }
            if n.contains("GPU") || n.contains("gACC") {
                gpuSum += r.value; gpuCount += 1
            }
            if n.contains("airflow") || n.contains("NAND") {
                periphSum += r.value; periphCount += 1
            }
            if battery == nil, n.lowercased().contains("battery") {
                battery = r.value
            }
        }

        let cpu: Double? = cpuCount > 0 ? cpuSum / Double(cpuCount)
            : (tdieCount > 0 ? tdieSum / Double(tdieCount) : nil)
        let gpu: Double? = gpuCount > 0 ? gpuSum / Double(gpuCount) : nil
        let peripheral: Double? = periphCount > 0 ? periphSum / Double(periphCount) : nil

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

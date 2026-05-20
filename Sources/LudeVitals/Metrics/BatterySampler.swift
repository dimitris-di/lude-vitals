import Foundation
import IOKit
import IOKit.ps

final class BatterySampler: AnySampler {
    typealias Output = BatteryMetrics?

    func sample() -> BatteryMetrics? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let info = IOPSGetPowerSourceDescription(blob, first)?.takeUnretainedValue() as? [String: Any] else {
            return nil
        }
        guard (info[kIOPSTypeKey as String] as? String) == kIOPSInternalBatteryType else { return nil }

        let current = info[kIOPSCurrentCapacityKey as String] as? Int ?? 0
        let maxCap  = info[kIOPSMaxCapacityKey as String]     as? Int ?? 100
        let percentage = maxCap > 0 ? Double(current) / Double(maxCap) : 0
        let isCharging = info[kIOPSIsChargingKey as String] as? Bool ?? false
        let powerState = info[kIOPSPowerSourceStateKey as String] as? String
        let isPluggedIn = powerState == (kIOPSACPowerValue as String)

        var timeRemaining: Int? = nil
        if isCharging, let m = info[kIOPSTimeToFullChargeKey as String] as? Int, m >= 0 {
            timeRemaining = m
        } else if let m = info[kIOPSTimeToEmptyKey as String] as? Int, m >= 0 {
            timeRemaining = m
        }

        var cycleCount: Int? = nil
        var health: Double? = nil
        var wattage: Double? = nil
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            defer { IOObjectRelease(service) }
            if let cc = property(service, "CycleCount") as? Int { cycleCount = cc }
            if let design = property(service, "DesignCapacity") as? Int,
               let rawMax = (property(service, "AppleRawMaxCapacity") ?? property(service, "MaxCapacity")) as? Int,
               design > 0 {
                health = min(1.0, Double(rawMax) / Double(design))
            }
            if let amp = property(service, "InstantAmperage") as? Int,
               let volt = property(service, "Voltage") as? Int {
                wattage = Double(amp) * Double(volt) / 1_000_000.0
            }
        }

        return BatteryMetrics(
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            timeRemainingMinutes: timeRemaining,
            cycleCount: cycleCount,
            health: health,
            wattage: wattage
        )
    }

    private func property(_ service: io_service_t, _ key: String) -> Any? {
        // CF Create Rule: takeRetainedValue balances the +1 from IORegistryEntryCreateCFProperty.
        let result = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)
        guard let cf = result?.takeRetainedValue() else { return nil }
        return cf as Any
    }
}

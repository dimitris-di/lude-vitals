import Foundation
import Darwin
import QuartzCore
import SystemConfiguration

@MainActor
final class NetworkSampler: AnySampler {
    typealias Output = NetworkMetrics

    private var lastIn: UInt64 = 0
    private var lastOut: UInt64 = 0
    private var lastSampleTime: TimeInterval = 0

    private lazy var store: SCDynamicStore? = SCDynamicStoreCreate(nil, "LudeVitals" as CFString, nil, nil)
    private var cachedPrimary: String?
    private var cachedPrimaryAge: Int = 0
    private let primaryRefreshInterval = 5

    func sample() -> NetworkMetrics {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else { return .zero }
        defer { freeifaddrs(ifap) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let p = cursor {
            defer { cursor = p.pointee.ifa_next }
            guard let nameRaw = p.pointee.ifa_name else { continue }
            let name = String(cString: nameRaw)
            if name.hasPrefix("lo") { continue }
            let flags = Int32(p.pointee.ifa_flags)
            if (flags & IFF_UP) == 0 { continue }
            guard let sa = p.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_LINK) else { continue }
            guard let data = p.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) else { continue }
            totalIn  += UInt64(data.pointee.ifi_ibytes)
            totalOut += UInt64(data.pointee.ifi_obytes)
        }

        let now = CACurrentMediaTime()
        let elapsed = lastSampleTime == 0 ? 0 : (now - lastSampleTime)
        let deltaIn  = lastIn  == 0 ? 0 : (totalIn  > lastIn  ? totalIn  - lastIn  : 0)
        let deltaOut = lastOut == 0 ? 0 : (totalOut > lastOut ? totalOut - lastOut : 0)
        let inRate:  UInt64 = elapsed > 0 ? UInt64(Double(deltaIn)  / elapsed) : 0
        let outRate: UInt64 = elapsed > 0 ? UInt64(Double(deltaOut) / elapsed) : 0
        lastIn = totalIn
        lastOut = totalOut
        lastSampleTime = now

        return NetworkMetrics(
            bytesInPerSec: inRate,
            bytesOutPerSec: outRate,
            totalBytesIn: totalIn,
            totalBytesOut: totalOut,
            primaryInterface: primaryInterface()
        )
    }

    private func primaryInterface() -> String? {
        if cachedPrimary != nil && cachedPrimaryAge < primaryRefreshInterval {
            cachedPrimaryAge += 1
            return cachedPrimary
        }
        cachedPrimaryAge = 0
        guard let store,
              let dict = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let iface = dict["PrimaryInterface"] as? String else {
            cachedPrimary = nil
            return nil
        }
        cachedPrimary = iface
        return iface
    }
}

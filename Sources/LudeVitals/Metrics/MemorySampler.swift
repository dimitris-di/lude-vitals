import Foundation
import Darwin

@MainActor
final class MemorySampler: AnySampler {
    typealias Output = MemoryMetrics

    private let totalBytes: UInt64
    private let pageSize: UInt64

    init() {
        self.totalBytes = Self.sysctlUInt64("hw.memsize") ?? 0
        var ps: vm_size_t = 0
        let kr = host_page_size(mach_host_self(), &ps)
        self.pageSize = UInt64(kr == KERN_SUCCESS && ps > 0 ? ps : 4096)
    }

    func sample(context: SamplingContext) async -> MemoryMetrics {
        var stats = vm_statistics64()
        let expectedCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var count = expectedCount
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, ptr, &count)
            }
        }
        guard kr == KERN_SUCCESS, count >= expectedCount else { return .zero }

        let ps = pageSize
        let wired      = UInt64(stats.wire_count) * ps
        let compressed = UInt64(stats.compressor_page_count) * ps
        let active     = UInt64(stats.active_count) * ps
        let cached     = UInt64(stats.external_page_count) * ps
        let speculative = UInt64(stats.speculative_count) * ps
        let freeRaw    = UInt64(stats.free_count) * ps
        let free       = freeRaw > speculative ? freeRaw - speculative : 0
        let used       = active + wired + compressed

        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        var swapUsed: UInt64 = 0
        var swapTotal: UInt64 = 0
        if sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0,
           swapSize >= MemoryLayout<xsw_usage>.size {
            swapUsed  = swap.xsu_used
            swapTotal = swap.xsu_total
        }

        var pressureRaw: Int32 = 0
        var pSize = MemoryLayout<Int32>.size
        let ok = sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureRaw, &pSize, nil, 0) == 0
            && pSize >= MemoryLayout<Int32>.size
        let pressure: MemoryPressure
        if ok {
            switch pressureRaw {
            case 4: pressure = .critical
            case 2: pressure = .warning
            default: pressure = .normal
            }
        } else {
            pressure = .normal
        }

        return MemoryMetrics(
            total: totalBytes,
            used: used,
            app: active,
            wired: wired,
            compressed: compressed,
            cached: cached,
            free: free,
            swapUsed: swapUsed,
            swapTotal: swapTotal,
            pressure: pressure
        )
    }

    private static func sysctlUInt64(_ name: String) -> UInt64? {
        var v: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        return name.withCString {
            sysctlbyname($0, &v, &size, nil, 0) == 0 && size >= MemoryLayout<UInt64>.size ? v : nil
        }
    }
}

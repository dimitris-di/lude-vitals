import Foundation
import IOKit

// AppleSMC userclient still exposes fan keys on Apple Silicon Macs that have fans.
// MacBook Air (no fans) returns FNum=0 or fails to open — we silently report no fans.
final class SMCFanReader {
    private var connection: io_connect_t = 0
    private var attempted = false
    private var cachedFanCount: Int?
    private var cachedFanRanges: [(min: Int, max: Int)] = []

    private struct SMCKeyData {
        var key: UInt32 = 0
        var versMajor: UInt8 = 0
        var versMinor: UInt8 = 0
        var versBuild: UInt8 = 0
        var versReserved: UInt8 = 0
        var versRelease: UInt16 = 0
        var pLimitVersion: UInt16 = 0
        var pLimitLength: UInt16 = 0
        var pLimitCpu: UInt32 = 0
        var pLimitGpu: UInt32 = 0
        var pLimitMem: UInt32 = 0
        var keyInfoDataSize: UInt32 = 0
        var keyInfoDataType: UInt32 = 0
        var keyInfoDataAttributes: UInt8 = 0
        var keyInfoPad0: UInt8 = 0
        var keyInfoPad1: UInt8 = 0
        var keyInfoPad2: UInt8 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var pad8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,
                    UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,
                    UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,
                    UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8) =
            (0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0)
    }

    deinit {
        if connection != 0 { IOServiceClose(connection) }
    }

    private func ensureOpen() -> Bool {
        assert(MemoryLayout<SMCKeyData>.stride == 80, "SMCKeyData layout drift — SMC reads will fail silently")
        if connection != 0 { return true }
        if attempted { return false }
        attempted = true
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        var conn: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == kIOReturnSuccess else { return false }
        connection = conn
        return true
    }

    private func fourCC(_ s: String) -> UInt32 {
        let bytes = Array(s.utf8)
        guard bytes.count == 4 else { return 0 }
        return (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
    }

    private func call(_ input: inout SMCKeyData, _ output: inout SMCKeyData) -> Bool {
        let inSize = MemoryLayout<SMCKeyData>.stride
        var outSize = inSize
        let kr = withUnsafePointer(to: &input) { inPtr -> kern_return_t in
            withUnsafeMutablePointer(to: &output) { outPtr in
                IOConnectCallStructMethod(connection, 2, inPtr, inSize, outPtr, &outSize)
            }
        }
        return kr == kIOReturnSuccess
    }

    private func readKey(_ key: String) -> SMCKeyData? {
        guard ensureOpen() else { return nil }
        var input = SMCKeyData()
        input.key = fourCC(key)
        input.data8 = 9
        var info = SMCKeyData()
        if !call(&input, &info) || info.result != 0 { return nil }
        var read = SMCKeyData()
        var readInput = SMCKeyData()
        readInput.key = fourCC(key)
        readInput.keyInfoDataSize = info.keyInfoDataSize
        readInput.keyInfoDataType = info.keyInfoDataType
        readInput.data8 = 5
        if !call(&readInput, &read) || read.result != 0 { return nil }
        read.keyInfoDataType = info.keyInfoDataType
        read.keyInfoDataSize = info.keyInfoDataSize
        return read
    }

    private func decodeRPM(_ d: SMCKeyData) -> Double? {
        let type = d.keyInfoDataType
        let fpe2 = fourCC("fpe2")
        let flt  = fourCC("flt ")
        return withUnsafeBytes(of: d.bytes) { raw -> Double? in
            if type == fpe2 {
                let v = (UInt16(raw[0]) << 8) | UInt16(raw[1])
                return Double(v) / 4.0
            } else if type == flt {
                let v = (UInt32(raw[0]) << 24) | (UInt32(raw[1]) << 16) | (UInt32(raw[2]) << 8) | UInt32(raw[3])
                return Double(Float(bitPattern: v))
            }
            return nil
        }
    }

    func readFans() -> [FanReading] {
        guard ensureOpen() else { return [] }
        let n: Int
        if let cached = cachedFanCount {
            n = cached
        } else {
            guard let countData = readKey("FNum") else { return [] }
            let first = withUnsafeBytes(of: countData.bytes) { $0[0] }
            n = Int(first)
            cachedFanCount = n
            if n > 0 {
                var ranges: [(min: Int, max: Int)] = []
                ranges.reserveCapacity(n)
                for i in 0..<n {
                    let mn = readKey("F\(i)Mn").flatMap(decodeRPM) ?? 0
                    let mx = readKey("F\(i)Mx").flatMap(decodeRPM) ?? 0
                    ranges.append((Int(mn), Int(mx)))
                }
                cachedFanRanges = ranges
            }
        }
        if n == 0 { return [] }
        var out: [FanReading] = []
        out.reserveCapacity(n)
        for i in 0..<n {
            let ac = readKey("F\(i)Ac").flatMap(decodeRPM) ?? 0
            let range: (min: Int, max: Int) = i < cachedFanRanges.count ? cachedFanRanges[i] : (min: 0, max: 0)
            out.append(FanReading(id: i, label: "Fan \(i + 1)", rpm: Int(ac), minRPM: range.min, maxRPM: range.max))
        }
        return out
    }
}

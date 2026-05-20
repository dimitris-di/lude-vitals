import Foundation
import Darwin
import QuartzCore

final class CPUSampler: AnySampler {
    typealias Output = CPUMetrics

    private struct CoreTicks { var user: UInt32; var system: UInt32; var idle: UInt32; var nice: UInt32 }

    var collectTopProcesses: Bool = false

    private var previousTicks: [CoreTicks] = []
    private var previousPidTicks: [Int32: UInt64] = [:]
    private var previousProcSample: TimeInterval = 0
    private let coreLayout: [CoreType]
    private let pCoreCount: Int
    private let eCoreCount: Int

    init() {
        let p = Self.sysctlInt("hw.perflevel0.physicalcpu") ?? 0
        let e = Self.sysctlInt("hw.perflevel1.physicalcpu") ?? 0
        self.pCoreCount = p
        self.eCoreCount = e
        let total = ProcessInfo.processInfo.activeProcessorCount
        if p > 0, p + e == total {
            self.coreLayout = Array(repeating: .performance, count: p)
                            + Array(repeating: .efficiency, count: e)
        } else {
            self.coreLayout = Array(repeating: .unknown, count: total)
        }
    }

    func sample() -> CPUMetrics {
        var numCpu: natural_t = 0
        var infoPtr: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let kr = host_processor_info(mach_host_self(),
                                     PROCESSOR_CPU_LOAD_INFO,
                                     &numCpu, &infoPtr, &infoCount)
        guard kr == KERN_SUCCESS, let infoPtr = infoPtr else { return .zero }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: infoPtr),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size))
        }

        let states = Int(CPU_STATE_MAX)
        var current: [CoreTicks] = []
        current.reserveCapacity(Int(numCpu))
        for i in 0..<Int(numCpu) {
            let base = i * states
            current.append(CoreTicks(
                user:   UInt32(bitPattern: infoPtr[base + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: infoPtr[base + Int(CPU_STATE_SYSTEM)]),
                idle:   UInt32(bitPattern: infoPtr[base + Int(CPU_STATE_IDLE)]),
                nice:   UInt32(bitPattern: infoPtr[base + Int(CPU_STATE_NICE)])
            ))
        }

        if previousTicks.count != current.count {
            previousTicks = current
            var load: [Double] = [0, 0, 0]
            getloadavg(&load, 3)
            return CPUMetrics(
                totalUsage: 0, userUsage: 0, systemUsage: 0, idleUsage: 1,
                perCore: [], pCoreAverage: nil, eCoreAverage: nil,
                loadAverage: LoadAverage(one: load[0], five: load[1], fifteen: load[2]),
                topProcesses: []
            )
        }
        let prev = previousTicks
        previousTicks = current

        var perCore: [CoreUsage] = []
        perCore.reserveCapacity(current.count)
        var totUser: Double = 0, totSys: Double = 0, totIdle: Double = 0, totAll: Double = 0
        var pSum: Double = 0, pCount = 0, eSum: Double = 0, eCount = 0

        for (i, c) in current.enumerated() {
            let p = prev[i]
            let dUser = Double(c.user &- p.user)
            let dSys  = Double(c.system &- p.system)
            let dIdle = Double(c.idle &- p.idle)
            let dNice = Double(c.nice &- p.nice)
            let dAll = dUser + dSys + dIdle + dNice
            let usage = dAll > 0 ? (dUser + dSys + dNice) / dAll : 0
            let type = i < coreLayout.count ? coreLayout[i] : .unknown
            perCore.append(CoreUsage(id: i, usage: usage, type: type))
            totUser += dUser; totSys += dSys; totIdle += dIdle; totAll += dAll
            switch type {
            case .performance: pSum += usage; pCount += 1
            case .efficiency:  eSum += usage; eCount += 1
            case .unknown:     break
            }
        }

        let total = totAll > 0 ? (totUser + totSys) / totAll : 0
        let userN = totAll > 0 ? totUser / totAll : 0
        let sysN  = totAll > 0 ? totSys  / totAll : 0
        let idleN = totAll > 0 ? totIdle / totAll : 1

        var load: [Double] = [0, 0, 0]
        getloadavg(&load, 3)

        return CPUMetrics(
            totalUsage: total,
            userUsage: userN,
            systemUsage: sysN,
            idleUsage: idleN,
            perCore: perCore,
            pCoreAverage: pCount > 0 ? pSum / Double(pCount) : nil,
            eCoreAverage: eCount > 0 ? eSum / Double(eCount) : nil,
            loadAverage: LoadAverage(one: load[0], five: load[1], fifteen: load[2]),
            topProcesses: collectTopProcesses ? topProcesses(totalDelta: totAll) : []
        )
    }

    private func topProcesses(totalDelta: Double) -> [ProcessUsage] {
        let now = CACurrentMediaTime()
        let elapsed = previousProcSample == 0 ? 0 : (now - previousProcSample)
        previousProcSample = now

        // proc_listpids first call returns bytes needed, not a pid count.
        var pidCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        if pidCount <= 0 { return [] }
        let bytesNeeded = Int(pidCount)
        let cap = (bytesNeeded / MemoryLayout<pid_t>.stride) * 2 + 64
        var pids = [pid_t](repeating: 0, count: cap)
        pidCount = pids.withUnsafeMutableBufferPointer { buf -> Int32 in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, buf.baseAddress, Int32(cap * MemoryLayout<pid_t>.stride))
        }
        if pidCount <= 0 { return [] }
        let realCount = Int(pidCount) / MemoryLayout<pid_t>.stride

        var nextTicks: [Int32: UInt64] = [:]
        nextTicks.reserveCapacity(realCount)
        var rows: [ProcessUsage] = []
        rows.reserveCapacity(realCount)

        var nameBuf = [CChar](repeating: 0, count: 256)
        for idx in 0..<realCount {
            let pid = pids[idx]
            if pid <= 0 { continue }
            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            let r = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
            if r != size { continue }
            let totalTicks = info.pti_total_user &+ info.pti_total_system
            nextTicks[pid] = totalTicks
            let prev = previousPidTicks[pid]
            let cpu: Double
            if let prev = prev, elapsed > 0 {
                let deltaNs = Double(totalTicks &- prev)
                cpu = min(1.0, (deltaNs / 1_000_000_000.0) / elapsed)
            } else {
                cpu = 0
            }
            nameBuf[0] = 0
            let n = proc_name(pid, &nameBuf, UInt32(nameBuf.count))
            let name = n > 0 ? String(cString: nameBuf) : "pid \(pid)"
            rows.append(ProcessUsage(id: pid, name: name, cpu: cpu, memoryBytes: info.pti_resident_size))
        }
        previousPidTicks = nextTicks
        return Array(rows.sorted { $0.cpu > $1.cpu }.prefix(8))
    }

    private static func sysctlInt(_ name: String) -> Int? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        return name.withCString { cname in
            sysctlbyname(cname, &value, &size, nil, 0) == 0 ? Int(value) : nil
        }
    }
}

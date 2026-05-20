import Foundation
import IOKit

struct ThermalReading { let name: String; let value: Double }

// Private IOHIDEventSystemClient symbols. Stable since macOS 11.
@MainActor
final class IOHIDThermalReader {
    private typealias CreateFn  = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
    private typealias MatchFn   = @convention(c) (AnyObject, CFDictionary) -> Void
    private typealias ServicesFn = @convention(c) (AnyObject) -> Unmanaged<CFArray>?
    private typealias CopyEventFn = @convention(c) (AnyObject, Int64, Int32, Int64) -> Unmanaged<AnyObject>?
    private typealias CopyPropertyFn = @convention(c) (AnyObject, CFString) -> Unmanaged<AnyObject>?
    private typealias EventFloatFn = @convention(c) (AnyObject, Int32) -> Double

    private let handle: UnsafeMutableRawPointer?
    private let createFn: CreateFn?
    private let matchFn: MatchFn?
    private let servicesFn: ServicesFn?
    private let copyEventFn: CopyEventFn?
    private let copyPropertyFn: CopyPropertyFn?
    private let eventFloatFn: EventFloatFn?

    private var client: AnyObject?
    private var services: [AnyObject] = []
    private var names: [String] = []

    private let temperatureType: Int64 = 15
    private let temperatureField: Int32 = 15 << 16

    init() {
        let h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY)
        self.handle = h
        func sym<T>(_ name: String, _ as: T.Type) -> T? {
            guard let p = dlsym(h, name) else { return nil }
            return unsafeBitCast(p, to: T.self)
        }
        self.createFn       = sym("IOHIDEventSystemClientCreate", CreateFn.self)
        self.matchFn        = sym("IOHIDEventSystemClientSetMatching", MatchFn.self)
        self.servicesFn     = sym("IOHIDEventSystemClientCopyServices", ServicesFn.self)
        self.copyEventFn    = sym("IOHIDServiceClientCopyEvent", CopyEventFn.self)
        self.copyPropertyFn = sym("IOHIDServiceClientCopyProperty", CopyPropertyFn.self)
        self.eventFloatFn   = sym("IOHIDEventGetFloatValue", EventFloatFn.self)
    }

    private func ensureClient() {
        guard client == nil else { return }
        guard let create = createFn, let match = matchFn, let servs = servicesFn else { return }
        guard let cli = create(kCFAllocatorDefault)?.takeRetainedValue() else { return }
        let matching: [String: Any] = ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 0x5]
        match(cli, matching as CFDictionary)
        guard let arr = servs(cli)?.takeRetainedValue() as? [AnyObject] else { return }
        client = cli
        services = arr
        names = arr.map { svc -> String in
            (copyPropertyFn?(svc, "Product" as CFString)?.takeRetainedValue() as? String) ?? ""
        }
    }

    func read() -> [ThermalReading] {
        ensureClient()
        if services.isEmpty { return [] }
        guard let copyEvent = copyEventFn, let floatOf = eventFloatFn else { return [] }
        var out: [ThermalReading] = []
        out.reserveCapacity(services.count)
        for (i, svc) in services.enumerated() {
            guard let ev = copyEvent(svc, temperatureType, 0, 0)?.takeRetainedValue() else { continue }
            let v = floatOf(ev, temperatureField)
            if v.isFinite && v > 3 && v < 150 {
                out.append(ThermalReading(name: names[i], value: v))
            }
        }
        return out
    }
}

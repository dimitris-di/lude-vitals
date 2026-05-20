import Foundation

struct RingBuffer<T> {
    private var storage: [T?]
    private var head: Int = 0
    private var size: Int = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = max(1, capacity)
        self.storage = .init(repeating: nil, count: self.capacity)
    }

    mutating func append(_ v: T) {
        storage[head] = v
        head = (head + 1) % capacity
        if size < capacity { size += 1 }
    }

    var count: Int { size }

    var last: T? {
        guard size > 0 else { return nil }
        return storage[(head - 1 + capacity) % capacity]
    }

    var values: [T] {
        guard size > 0 else { return [] }
        let start = (head - size + capacity) % capacity
        var out: [T] = []
        out.reserveCapacity(size)
        for i in 0..<size {
            if let v = storage[(start + i) % capacity] { out.append(v) }
        }
        return out
    }
}

import Foundation

struct RingBuffer<T> {
    private(set) var capacity: Int
    private var storage: [T] = []

    init(capacity: Int) { self.capacity = max(1, capacity) }

    mutating func append(_ value: T) {
        storage.append(value)
        if storage.count > capacity { storage.removeFirst(storage.count - capacity) }
    }

    var values: [T] { storage }
    var count: Int { storage.count }
    var last: T? { storage.last }
}

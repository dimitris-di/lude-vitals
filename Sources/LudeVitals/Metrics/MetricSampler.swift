import Foundation

/// All samplers conform to this. `sample()` is called on a background queue
/// at the scheduler's cadence; implementations should be cheap and stateful
/// (they own their own deltas between calls).
protocol MetricSampler: AnyObject {
    associatedtype Output
    func sample() -> Output
}

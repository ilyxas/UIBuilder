import Foundation
import Observation

@Observable
final class UIStateStore {
    var values: [String: DynamicValue]

    init(initial: [String: DynamicValue] = [:]) {
        self.values = initial
    }

    func get(_ key: String) -> DynamicValue? {
        values[key]
    }

    func set(_ key: String, value: DynamicValue) {
        values[key] = value
    }

    func increment(_ key: String, max: Double? = nil) {
        guard case .number(let current)? = values[key] else { return }
        let next = current + 1
        values[key] = .number(max.map { min(next, $0) } ?? next)
    }

    func decrement(_ key: String, min: Double? = nil) {
        guard case .number(let current)? = values[key] else { return }
        let next = current - 1
        values[key] = .number(min.map { Swift.max(next, $0) } ?? next)
    }

    func toggle(_ key: String) {
        guard case .bool(let current)? = values[key] else { return }
        values[key] = .bool(!current)
    }
}
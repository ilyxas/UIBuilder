import Foundation
import Observation

@Observable
final class NavigationStore {
    var path: [String] = []

    func push(_ screenId: String) {
        path.append(screenId)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}
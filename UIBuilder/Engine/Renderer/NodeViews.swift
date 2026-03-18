import SwiftUI

// MARK: - Conditional modifier helper

extension View {
    /// Applies a transform closure to the view when `condition` is true.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

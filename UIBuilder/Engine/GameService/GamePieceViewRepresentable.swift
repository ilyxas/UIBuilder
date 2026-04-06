import SwiftUI
import UIKit

struct GamePieceViewRepresentable: UIViewRepresentable {

    final class Coordinator {
        let view = GamePieceView()

        init() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onTick),
                name: GameWorld.didTickNotification,
                object: nil
            )
        }

        @objc
        func onTick() {
            Task { @MainActor in
                let state = GameWorld.shared.state
                view.update(state: state)
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> GamePieceView {
        context.coordinator.view
    }

    func updateUIView(_ uiView: GamePieceView, context: Context) {}
}

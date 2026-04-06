import Foundation
import SwiftUI
import Combine
import Observation

@available(iOS 26.0, *)
@MainActor
@Observable
final class WorldPOCViewModel {
    let llm: LLMEvaluator
    let planner: WorldPlannerService
    var statusText: String = "Ready"
    var recentActions: [String] = []
    var currentModeHint: String = "neutral"

    private let executor = WorldExecutor()

    
    init(llm: LLMEvaluator, planner: WorldPlannerService) {
        self.llm = llm
        self.planner = planner
    }
    
    func resetWorld() {
        GameWorld.shared.reset()
        recentActions.removeAll()
        currentModeHint = "neutral"
        statusText = "World reset"
    }
    
    func resetSession() {
        planner.resetSession()
        recentActions.removeAll()
        statusText = "Session reset"
    }
    
    func stepTowardGoal() async {
        let state = GameWorld.shared.state

        let context = WorldContext(
            gridWidth: state.gridWidth,
            gridHeight: state.gridHeight,
            playerX: state.x,
            playerY: state.y,
            goalX: state.goal.x,
            goalY: state.goal.y,
            obstacles: state.obstacles
        )

        do {
            let interpretation = try await planner.interpret(context: context)

            statusText = executor.accept(interpretation)

        } catch {
            statusText = "ERROR:\n\(error.localizedDescription)"
        }
    }

    private func appendRecent(_ action: String) {
        recentActions.append(action)
        if recentActions.count > 4 {
            recentActions.removeFirst(recentActions.count - 4)
        }
    }
}

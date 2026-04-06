import Foundation

final class WorldExecutor {

    func accept(_ interpretation: WorldInterpretation) -> String {
        let commands = mapToCommands(interpretation)

        GameWorld.shared.start()
        GameWorld.shared.enqueue(commands)

        return """
        reaction: \(interpretation.reaction)
        decision: \(interpretation.decision ?? "-")
        enqueued: \(commands)
        """
    }

    private func mapToCommands(_ interpretation: WorldInterpretation) -> [GameCommand] {
        let reaction = interpretation.reaction
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let state = GameWorld.shared.state

        switch reaction {
        case "step_right":
            if isValidMove(dx: 1, dy: 0, state: state) {
                return commandsToFace(targetHeading: 0, currentHeading: state.normalizedHeading) + [.step(.small)]
            } else {
                return [.halt]
            }

        case "step_left":
            if isValidMove(dx: -1, dy: 0, state: state) {
                return commandsToFace(targetHeading: 2, currentHeading: state.normalizedHeading) + [.step(.small)]
            } else {
                return [.halt]
            }

        case "step_down":
            if isValidMove(dx: 0, dy: 1, state: state) {
                return commandsToFace(targetHeading: 1, currentHeading: state.normalizedHeading) + [.step(.small)]
            } else {
                return [.halt]
            }

        case "step_up":
            if isValidMove(dx: 0, dy: -1, state: state) {
                return commandsToFace(targetHeading: 3, currentHeading: state.normalizedHeading) + [.step(.small)]
            } else {
                return [.halt]
            }

        default:
            return [.halt]
        }
    }

    private func commandsToFace(targetHeading: Int, currentHeading: Int) -> [GameCommand] {
        let current = ((currentHeading % 4) + 4) % 4
        let target = ((targetHeading % 4) + 4) % 4
        let delta = (target - current + 4) % 4

        switch delta {
        case 0:
            return []
        case 1:
            return [.rotateRight(.small)]
        case 2:
            return [.rotateRight(.small), .rotateRight(.small)]
        case 3:
            return [.rotateLeft(.small)]
        default:
            return []
        }
    }
    private func parseSpeed(_ raw: String) -> GameCommand.SpeedProfile? {
        GameCommand.SpeedProfile(
            rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }
    
    private func isValidMove(dx: Int, dy: Int, state: GamePieceState) -> Bool {
        let nx = state.x + dx
        let ny = state.y + dy

        if nx < 0 || ny < 0 || nx >= state.gridWidth || ny >= state.gridHeight {
            return false
        }

        return !state.obstacles.contains(where: { $0.x == nx && $0.y == ny })
    }
}

import Foundation
import CoreGraphics

struct GridPoint: Codable, Equatable, Hashable {
    var x: Int
    var y: Int
}

struct GamePieceState: Codable, Equatable {
    var x: Int = 0
    var y: Int = 0

    /// 0 = east, 1 = south, 2 = west, 3 = north
    var headingIndex: Int = 0

    var speedProfile: GameCommand.SpeedProfile = .normal
    var isHalted: Bool = true

    var gridWidth: Int = 12
    var gridHeight: Int = 8

    var goal: GridPoint = GridPoint(x: 10, y: 4)

    var obstacles: [GridPoint] = [
        GridPoint(x: 4, y: 3),
        GridPoint(x: 4, y: 4),
        GridPoint(x: 4, y: 5),
        GridPoint(x: 7, y: 2),
        GridPoint(x: 7, y: 3),
        GridPoint(x: 7, y: 4)
    ]

    var headingName: String {
        switch normalizedHeading {
        case 0: return "right"
        case 1: return "down"
        case 2: return "left"
        default: return "up"
        }
    }

    var headingRadians: CGFloat {
        switch normalizedHeading {
        case 0: return 0
        case 1: return .pi / 2
        case 2: return .pi
        default: return -.pi / 2
        }
    }

    var playerPoint: GridPoint {
        GridPoint(x: x, y: y)
    }

    var normalizedHeading: Int {
        ((headingIndex % 4) + 4) % 4
    }

    func containsObstacle(_ point: GridPoint) -> Bool {
        obstacles.contains(point)
    }

    func isInsideGrid(_ point: GridPoint) -> Bool {
        point.x >= 0 &&
        point.y >= 0 &&
        point.x < gridWidth &&
        point.y < gridHeight
    }

    func isBlocked(_ point: GridPoint) -> Bool {
        !isInsideGrid(point) || containsObstacle(point)
    }

    func pointForward() -> GridPoint {
        offsetPoint(for: normalizedHeading)
    }

    func pointLeft() -> GridPoint {
        offsetPoint(for: (normalizedHeading + 3) % 4)
    }

    func pointRight() -> GridPoint {
        offsetPoint(for: (normalizedHeading + 1) % 4)
    }

    private func offsetPoint(for heading: Int) -> GridPoint {
        switch heading {
        case 0:
            return GridPoint(x: x + 1, y: y)
        case 1:
            return GridPoint(x: x, y: y + 1)
        case 2:
            return GridPoint(x: x - 1, y: y)
        default:
            return GridPoint(x: x, y: y - 1)
        }
    }
}

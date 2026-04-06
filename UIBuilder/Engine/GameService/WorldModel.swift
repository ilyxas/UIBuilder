import Foundation


struct WorldContext: Codable {
    let gridWidth: Int
    let gridHeight: Int

    let playerX: Int
    let playerY: Int

    let goalX: Int
    let goalY: Int

    let obstacles: [GridPoint]
}

struct WorldInterpretation: Codable {
    let reaction: String
    let decision: String?
}

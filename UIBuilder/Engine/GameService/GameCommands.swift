import Foundation
import CoreGraphics

enum GameCommand: Codable, Equatable {
    case setSpeedProfile(SpeedProfile)
    case step(DistanceStep)
    case reverse(DistanceStep)
    case rotateLeft(RotationStep)
    case rotateRight(RotationStep)
    case halt

    enum SpeedProfile: String, Codable, CaseIterable {
        case slow
        case normal
        case fast
    }

    enum DistanceStep: String, Codable, CaseIterable {
        case small
        case medium
        case large
    }

    enum RotationStep: String, Codable, CaseIterable {
        case small
        case medium
        case large
    }
}

struct GameTuning {
    static func distanceUnits(for step: GameCommand.DistanceStep) -> CGFloat {
        switch step {
        case .small: return 0.6
        case .medium: return 1.2
        case .large: return 2.0
        }
    }

    static func rotationRadians(for step: GameCommand.RotationStep) -> CGFloat {
        switch step {
        case .small: return .pi / 18   // 10°
        case .medium: return .pi / 9   // 20°
        case .large: return .pi / 4    // 45°
        }
    }

    static func speedMultiplier(for profile: GameCommand.SpeedProfile) -> CGFloat {
        switch profile {
        case .slow: return 0.7
        case .normal: return 1.0
        case .fast: return 1.5
        }
    }
}

//
//  MiniWorld.swift
//  UIBuilder
//
//  Created by ilya on 06/04/2026.
//

import SwiftUI
import RealityKit
import UIKit
import Combine

//enum LevelSegment: String, Codable {
//    case intro_jump
//    case low_block
//    case tall_block
//    case wide_block
//    case left_bypass
//    case right_bypass
//    case pillar_pair
//    case jump_sequence
//    case vanishing_guard
//    case bounce_punish
//    case safe_zone
//    case goal_guard
//}
//
//struct LevelResponse: Codable {
//    let segments: [LevelSegment]
//    let difficulty: String
//    let note: String?
//}
//
//struct LevelsResponse: Codable {
//    let levels: [LevelResponse]
//}

@MainActor
@Observable
final class MiniWorld {
    let root = Entity()
    let planner: LevelPlannerService
    let player: ModelEntity
    private let ground: ModelEntity
    private let light: DirectionalLight
    private let camera: PerspectiveCamera
    private let goal: ModelEntity

    private(set) var obstacles: [ModelEntity] = []
    private var spawnedEntities: [Entity] = []

    var input = SIMD2<Float>(0, 0)

    private var horizVel = SIMD3<Float>(0, 0, 0)
    private var yVel: Float = 0
    private var jumpRequested = false

    private let playerRadius: Float = 0.18
    private let playerHalfHeight: Float = 0.45
    private let gravity: Float = 9.8
    private let moveSpeed: Float = 2.2
    private let accel: Float = 12.0
    private let jumpSpeed: Float = 4.3

    private let startPosition: SIMD3<Float>

    private let laneLeft: Float = -1.0
    private let laneCenter: Float = 0.0
    private let laneRight: Float = 1.0
    var isGeneratingNextLevel = false

    init(planner: LevelPlannerService) {
        self.planner = planner
        self.startPosition = [0, playerHalfHeight + playerRadius, 0]

        // Ground
        let groundMesh = MeshResource.generatePlane(width: 18, depth: 40)
        var groundMat = SimpleMaterial()
        groundMat.color = .init(
            tint: .init(red: 0.18, green: 0.55, blue: 0.22, alpha: 1.0),
            texture: nil
        )
        groundMat.roughness = 1.0
        groundMat.metallic = 0.0
        self.ground = ModelEntity(mesh: groundMesh, materials: [groundMat])
        ground.position = [0, 0, -10]

        // Player
        let playerMesh = MeshResource.generateCylinder(height: playerHalfHeight * 2, radius: playerRadius)
        let playerMat = SimpleMaterial(
            color: .init(red: 0.92, green: 0.86, blue: 0.25, alpha: 1),
            roughness: 0.35,
            isMetallic: false
        )
        self.player = ModelEntity(mesh: playerMesh, materials: [playerMat])
        player.position = startPosition

        // Light
        self.light = DirectionalLight()
        light.light.intensity = 35_000
        light.shadow = .init()
        light.shadow?.shadowProjection = .automatic(maximumDistance: 12.0)
        light.orientation = simd_quatf(angle: -.pi / 3, axis: [1, 0, 0])

        // Camera
        self.camera = PerspectiveCamera()
        camera.position = [0, 2.5, 4]

        // Goal
        let goalMesh = MeshResource.generateSphere(radius: 0.22)
        let goalMat = SimpleMaterial(color: .cyan, roughness: 0.2, isMetallic: true)
        self.goal = ModelEntity(mesh: goalMesh, materials: [goalMat])
        goal.position = [0, 0.22, -8]

        // Build hierarchy
        root.addChild(light)
        root.addChild(camera)
        root.addChild(ground)
        root.addChild(player)
        root.addChild(goal)

        // Default playable level
        buildLevel(segments: [
            .intro_jump,
            .left_bypass,
            .safe_zone,
            .pillar_pair,
            .goal_guard
        ])

        updateCamera()
    }

    func requestJump() {
        jumpRequested = true
    }

    func loadLevel(from json: String, index: Int = 0) throws {
        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        if let batch = try? decoder.decode(LevelsResponse.self, from: data),
           batch.levels.indices.contains(index) {
            buildLevel(segments: batch.levels[index].segments)
            return
        }

        let single = try decoder.decode(LevelResponse.self, from: data)
        buildLevel(segments: single.segments)
    }

    func buildLevel(segments: [LevelSegment]) {
        clearLevel()

        var currentZ: Float = -2.0

        for segment in segments {
            placeSegment(segment, z: currentZ)
            currentZ -= segmentLength(for: segment)
        }

        goal.position = [laneCenter, 0.22, currentZ - 1.0]

        resetPlayer()
        updateCamera()
    }

    func step(dt: Float) {
        let desired = SIMD3<Float>(input.x, 0, input.y) * moveSpeed

        let delta = desired - horizVel
        let maxStep = accel * dt
        let len = simd_length(delta)

        if len > maxStep, len > 0 {
            horizVel += (delta / len) * maxStep
        } else {
            horizVel = desired
        }

        let groundY: Float = playerHalfHeight + playerRadius
        let onGround = player.position.y <= groundY + 0.0005

        if jumpRequested && onGround {
            yVel = jumpSpeed
        }
        jumpRequested = false

        yVel -= gravity * dt

        var nextPos = player.position
        nextPos += horizVel * dt
        nextPos.y += yVel * dt

        if nextPos.y < groundY {
            nextPos.y = groundY
            yVel = 0
        }

        if collidesWithAnyObstacle(at: nextPos) {
            resetPlayer()
            return
        }

        player.position = nextPos

        let moveDir = SIMD3<Float>(horizVel.x, 0, horizVel.z)
        if simd_length(moveDir) > 0.05 {
            let yaw = atan2(moveDir.x, moveDir.z)
            player.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        }

        let distToGoal = simd_distance(player.position, goal.position)
        if distToGoal < 0.45 && !isGeneratingNextLevel {
            handleLevelCompleted()
            return
        }

        updateCamera()
    }
    
    private func handleLevelCompleted() {
        guard !isGeneratingNextLevel else { return }
        isGeneratingNextLevel = true
        input = .zero

        Task { @MainActor in
            do {
                let requestContext = LevelGenerationRequest(count: 1,
                                                            segmentsPerLevel: 20,
                                                            difficultyPlan: ["hard"])
                let json = try await planner.interpret(context: requestContext)
                try loadLevel(from: json)
            } catch {
                print("Level generation failed: \(error)")
                resetPlayer()
            }

            isGeneratingNextLevel = false
        }
    }

    private func clearLevel() {
        for entity in spawnedEntities {
            entity.removeFromParent()
        }
        spawnedEntities.removeAll()
        obstacles.removeAll()
    }

    private func segmentLength(for segment: LevelSegment) -> Float {
        switch segment {
        case .safe_zone:
            return 2.5
        case .wide_block, .left_bypass, .right_bypass, .pillar_pair:
            return 2.5
        case .jump_sequence:
            return 3.5
        default:
            return 1.5
        }
    }

    private func placeSegment(_ segment: LevelSegment, z: Float) {
        switch segment {
        case .intro_jump:
            spawnBlock(size: [0.50, 0.28, 0.50], x: laneCenter, z: z, color: .systemRed)

        case .low_block:
            spawnBlock(size: [0.55, 0.35, 0.55], x: laneCenter, z: z, color: .systemOrange)

        case .tall_block:
            spawnBlock(size: [0.65, 0.85, 0.65], x: laneCenter, z: z, color: .systemPurple)

        case .wide_block:
            spawnBlock(size: [1.40, 0.35, 0.55], x: 0.5, z: z, color: .systemPink)

        case .left_bypass:
            // Blocks center + right, leaves left open
            spawnBlock(size: [1.80, 0.45, 0.60], x: 0.5, z: z, color: .systemTeal)

        case .right_bypass:
            // Blocks center + left, leaves right open
            spawnBlock(size: [1.80, 0.45, 0.60], x: -0.5, z: z, color: .systemIndigo)

        case .pillar_pair:
            spawnBlock(size: [0.50, 0.70, 0.50], x: laneLeft, z: z, color: .systemYellow)
            spawnBlock(size: [0.50, 0.70, 0.50], x: laneRight, z: z, color: .systemYellow)

        case .jump_sequence:
            spawnBlock(size: [0.45, 0.25, 0.45], x: laneCenter, z: z, color: .systemRed)
            spawnBlock(size: [0.45, 0.25, 0.45], x: laneCenter, z: z - 0.95, color: .systemOrange)
            spawnBlock(size: [0.45, 0.25, 0.45], x: laneCenter, z: z - 1.90, color: .systemPink)

        case .vanishing_guard:
            // Пока как обычный блок-заглушка, потом поведение добавим
            spawnBlock(size: [0.80, 0.35, 0.50], x: laneCenter, z: z, color: .cyan)

        case .bounce_punish:
            // Пока как обычный блок-заглушка, потом отталкивание добавим
            spawnBlock(size: [0.80, 0.35, 0.50], x: laneCenter, z: z, color: .systemBlue)

        case .safe_zone:
            break

        case .goal_guard:
            spawnBlock(size: [1.10, 0.30, 0.60], x: laneCenter, z: z, color: .brown)
        }
    }

    private func spawnBlock(size: SIMD3<Float>, x: Float, z: Float, color: UIColor) {
        let mesh = MeshResource.generateBox(size: size)
        let mat = SimpleMaterial(color: color, roughness: 0.3, isMetallic: false)
        let block = ModelEntity(mesh: mesh, materials: [mat])

        block.position = [x, size.y / 2, z]

        root.addChild(block)
        spawnedEntities.append(block)
        obstacles.append(block)
    }

    private func collidesWithAnyObstacle(at playerPos: SIMD3<Float>) -> Bool {
        for obstacle in obstacles {
            if overlaps(playerPos: playerPos, obstacle: obstacle) {
                return true
            }
        }
        return false
    }

    private func overlaps(playerPos: SIMD3<Float>, obstacle: ModelEntity) -> Bool {
        guard let model = obstacle.model else { return false }

        let bounds = model.mesh.bounds
        let obstacleSize = bounds.extents
        let obstacleCenter = obstacle.position

        let obstacleMinX = obstacleCenter.x - obstacleSize.x / 2
        let obstacleMaxX = obstacleCenter.x + obstacleSize.x / 2
        let obstacleMinY = obstacleCenter.y - obstacleSize.y / 2
        let obstacleMaxY = obstacleCenter.y + obstacleSize.y / 2
        let obstacleMinZ = obstacleCenter.z - obstacleSize.z / 2
        let obstacleMaxZ = obstacleCenter.z + obstacleSize.z / 2

        let playerMinX = playerPos.x - playerRadius
        let playerMaxX = playerPos.x + playerRadius
        let playerMinY = playerPos.y - (playerHalfHeight + playerRadius)
        let playerMaxY = playerPos.y + (playerHalfHeight + playerRadius)
        let playerMinZ = playerPos.z - playerRadius
        let playerMaxZ = playerPos.z + playerRadius

        let overlapX = playerMaxX >= obstacleMinX && playerMinX <= obstacleMaxX
        let overlapY = playerMaxY >= obstacleMinY && playerMinY <= obstacleMaxY
        let overlapZ = playerMaxZ >= obstacleMinZ && playerMinZ <= obstacleMaxZ

        return overlapX && overlapY && overlapZ
    }

    private func resetPlayer() {
        player.position = startPosition
        horizVel = .zero
        yVel = 0
        input = .zero
    }

    private func updateCamera() {
        let target = player.position
        let offset = SIMD3<Float>(0, 2.5, 4.2)

        camera.position = target + offset
        camera.look(at: target, from: camera.position, relativeTo: nil)
    }
}

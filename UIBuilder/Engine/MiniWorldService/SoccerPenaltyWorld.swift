//
//  SoccerPenaltyWorld.swift
//  UIBuilder
//
//  Created by copilot on 14/04/2026.
//

import SwiftUI
import RealityKit
import Combine

// MARK: - Game phase

enum PenaltyPhase {
    case aiming           // user drags to pick direction
    case powerSelection   // user sets power
    case ready            // direction + power chosen, waiting for "Удар"
    case waitingLLM       // sent to LLM, awaiting goalkeeper decision
    case ballInFlight     // physics running
    case scored           // goal — start new round
    case blocked          // goalkeeper saved — restart
}

// MARK: - World

@MainActor
@Observable
final class SoccerPenaltyWorld {

    // MARK: Public observable state

    private(set) var phase: PenaltyPhase = .aiming
    var cameraInput = SIMD2<Float>.zero    // x = rotate, y = zoom
    var shotPower: Float = 0.5            // 0..1
    var showPowerMeter: Bool = false
    var aimDirection: SIMD2<Float> = .zero // normalised screen drag
    var trajectoryPoints: [SIMD3<Float>] = []
    var isLLMBusy = false

    // MARK: Scene roots

    let root = Entity()

    // MARK: Private scene nodes

    private let ground: ModelEntity
    private let ball: ModelEntity
    private let goalPost: Entity
    private let goalkeeper: ModelEntity
    private let camera: PerspectiveCamera

    // Trajectory dashes
    private var dashEntities: [ModelEntity] = []

    // MARK: Camera orbit

    private var cameraAngle: Float = 0          // radians around Y
    private var cameraDistance: Float = 5.0

    // MARK: Ball physics state

    private var ballVelocity: SIMD3<Float> = .zero
    private var ballInFlight = false

    // MARK: Constants

    private let ballStartPosition: SIMD3<Float> = [0, 0.18, 0]
    private let goalCenter: SIMD3<Float>         = [0, 1.0, -6.0]
    private let goalWidth: Float                 = 3.6
    private let goalHeight: Float                = 2.0
    private let gravity: Float                   = 9.8
    private let ballRadius: Float                = 0.18

    // MARK: Goalkeeper physics

    private var gkTargetPosition: SIMD3<Float>   = [0, 0.9, -5.9]
    private var gkVelocity: SIMD3<Float>         = .zero
    private var gkActive: Bool                   = false
    private var gkIntensity: Float               = 0.5

    // MARK: Services

    private let planner: SoccerPenaltyPlannerService

    // MARK: Init

    init(planner: SoccerPenaltyPlannerService) {
        self.planner = planner

        // --- Ground ---
        let groundMesh = MeshResource.generatePlane(width: 20, depth: 30)
        var groundMat = SimpleMaterial()
        groundMat.color = .init(tint: UIColor(red: 0.16, green: 0.52, blue: 0.20, alpha: 1), texture: nil)
        groundMat.roughness = 1.0
        groundMat.metallic  = 0.0
        ground = ModelEntity(mesh: groundMesh, materials: [groundMat])
        ground.position = [0, 0, -6]

        // --- Ball ---
        let ballMesh = MeshResource.generateSphere(radius: ballRadius)
        var ballMat = SimpleMaterial()
        ballMat.color    = .init(tint: .white, texture: nil)
        ballMat.roughness = 0.4
        ball = ModelEntity(mesh: ballMesh, materials: [ballMat])
        ball.position = ballStartPosition

        // --- Goal post ---
        goalPost = SoccerPenaltyWorld.buildGoalPost(center: goalCenter,
                                                     width: goalWidth,
                                                     height: goalHeight)

        // --- Goalkeeper ---
        let gkMesh = MeshResource.generateBox(size: [0.6, 1.8, 0.3])
        let gkMat  = SimpleMaterial(color: UIColor(red: 0.1, green: 0.3, blue: 0.9, alpha: 1),
                                    roughness: 0.5, isMetallic: false)
        goalkeeper = ModelEntity(mesh: gkMesh, materials: [gkMat])
        goalkeeper.position = [0, 0.9, -5.9]

        // --- Light ---
        let light = DirectionalLight()
        light.light.intensity = 35_000
        light.shadow = DirectionalLightComponent.Shadow()
        light.orientation = simd_quatf(angle: -.pi / 3.5, axis: [1, 0, 0])

        // --- Camera ---
        camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 65

        // Build hierarchy
        root.addChild(light)
        root.addChild(camera)
        root.addChild(ground)
        root.addChild(ball)
        root.addChild(goalPost)
        root.addChild(goalkeeper)

        updateCamera()
    }

    // MARK: - Per-frame step

    func step(dt: Float) {
        // Camera orbit input
        if cameraInput != .zero {
            cameraAngle    += cameraInput.x * dt * 1.4
            cameraDistance  = max(2.0, min(10.0, cameraDistance - cameraInput.y * dt * 4.0))
            updateCamera()
        }

        guard ballInFlight else { return }

        // Ball flight
        ballVelocity.y -= gravity * dt
        ball.position  += ballVelocity * dt

        // Goalkeeper chase
        if gkActive {
            let diff      = gkTargetPosition - goalkeeper.position
            let dist      = simd_length(diff)
            let speed     = gkIntensity * 6.0
            if dist > 0.01 {
                goalkeeper.position += (diff / dist) * min(speed * dt, dist)
            } else {
                goalkeeper.position = gkTargetPosition
            }
        }

        // --- Collision checks ---

        // 1. Ball hits goalkeeper?
        let toGK = simd_distance(ball.position, goalkeeper.position)
        if toGK < (ballRadius + 0.5) && ball.position.z < -4.5 {
            handleBlocked()
            return
        }

        // 2. Ball crosses goal plane?
        if ball.position.z <= goalCenter.z {
            checkGoalOrMiss()
            return
        }

        // 3. Ball hits ground?
        if ball.position.y < ballRadius {
            handleBlocked()
        }
    }

    // MARK: - Phase management (called from View)

    func setPhaseReady() {
        phase = .ready
    }

    func updateAimDrag(_ drag: SIMD2<Float>) {
        guard phase == .aiming else { return }
        aimDirection = drag
        rebuildTrajectory()
    }

    func confirmAim() {
        guard phase == .aiming else { return }
        phase = .ready
        clearDashes()
    }

    // MARK: - Power

    func setPower(_ power: Float) {
        shotPower = max(0, min(1, power))
    }

    func confirmPower() {
        showPowerMeter = false
        phase = .ready
    }

    // MARK: - Shoot

    func shoot() {
        guard phase == .ready || phase == .aiming else { return }
        phase = .waitingLLM

        let request = buildLLMRequest()
        isLLMBusy = true

        Task { @MainActor in
            do {
                let response = try await planner.interpret(request: request)
                applyGoalkeeperResponse(response)
            } catch {
                // Fallback: goalkeeper dives to the opposite corner
                applyFallbackGoalkeeper()
            }
            isLLMBusy = false
            launchBall()
        }
    }

    // MARK: - Round management

    private func handleBlocked() {
        ballInFlight = false
        phase = .blocked
        gkActive = false

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            restartRound()
        }
    }

    private func handleScored() {
        ballInFlight = false
        phase = .scored
        gkActive = false

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            startNewRound()
        }
    }

    private func restartRound() {
        ball.position    = ballStartPosition
        ballVelocity     = .zero
        aimDirection     = .zero
        shotPower        = 0.5
        phase            = .aiming
        goalkeeper.position = [0, 0.9, -5.9]
        clearDashes()
        updateCamera()
    }

    private func startNewRound() {
        // Randomise ball X slightly to vary the angle
        let offsetX = Float.random(in: -1.0...1.0)
        ball.position    = [offsetX, ballRadius, 0]
        ballVelocity     = .zero
        aimDirection     = .zero
        shotPower        = 0.5
        phase            = .aiming
        goalkeeper.position = [0, 0.9, -5.9]
        clearDashes()
        updateCamera()
    }

    // MARK: - Private helpers

    private func buildLLMRequest() -> PenaltyShotRequest {
        PenaltyShotRequest(
            ballDistance: classifyDistance(),
            shotDirection: classifyDirection()
        )
    }

    private func classifyDistance() -> BallDistance {
        let d = simd_distance(ball.position, goalCenter)
        switch d {
        case ..<3.5:  return .close
        case ..<6.0:  return .medium
        default:      return .far
        }
    }

    private func classifyDirection() -> ShotDirection {
        // aimDirection: x = horizontal, y = vertical (y positive = up)
        let x = aimDirection.x  // -1 = left, 1 = right
        let y = aimDirection.y  // -1 = down, 1 = up

        let isLeft   = x < -0.25
        let isRight  = x >  0.25
        let isTop    = y >  0.25
        let isBottom = y < -0.25

        switch (isLeft, isRight, isTop, isBottom) {
        case (true,  false, true,  false): return .topLeft
        case (true,  false, false, false): return .leftCenter
        case (true,  false, false, true ): return .bottomLeft
        case (false, false, true,  false): return .topCenter
        case (false, false, false, true ): return .bottomCenter
        case (false, true,  true,  false): return .topRight
        case (false, true,  false, false): return .rightCenter
        case (false, true,  false, true ): return .bottomRight
        default:                           return .topCenter
        }
    }

    private func applyGoalkeeperResponse(_ response: GoalkeeperResponse) {
        let target = goalPositionFor(direction: response.jumpDirection)
        gkTargetPosition = target

        switch response.intensity {
        case "low":   gkIntensity = 0.3
        case "high":  gkIntensity = 1.0
        default:      gkIntensity = 0.6
        }

        gkActive = true
    }

    private func applyFallbackGoalkeeper() {
        // Jump to a random corner
        let directions: [ShotDirection] = [.bottomLeft, .bottomRight, .topLeft, .topRight]
        let dir = directions.randomElement() ?? .bottomLeft
        gkTargetPosition = goalPositionFor(direction: dir)
        gkIntensity = 0.5
        gkActive = true
    }

    private func goalPositionFor(direction: ShotDirection) -> SIMD3<Float> {
        let halfW = goalWidth / 2
        let halfH = goalHeight / 2
        let z: Float = -5.9

        switch direction {
        case .topLeft:     return [-halfW * 0.75,  goalCenter.y + halfH * 0.7, z]
        case .leftCenter:  return [-halfW * 0.75,  goalCenter.y,               z]
        case .bottomLeft:  return [-halfW * 0.75,  goalCenter.y - halfH * 0.5, z]
        case .topCenter:   return [ 0,             goalCenter.y + halfH * 0.7, z]
        case .bottomCenter:return [ 0,             goalCenter.y - halfH * 0.5, z]
        case .topRight:    return [ halfW * 0.75,  goalCenter.y + halfH * 0.7, z]
        case .rightCenter: return [ halfW * 0.75,  goalCenter.y,               z]
        case .bottomRight: return [ halfW * 0.75,  goalCenter.y - halfH * 0.5, z]
        }
    }

    private func launchBall() {
        let power = shotPower * 18.0 + 6.0    // 6…24 m/s
        let dx    = aimDirection.x * 3.0
        let dy    = max(0, aimDirection.y) * 4.0 + 2.0   // always has some lift
        let dz    = -power

        ballVelocity  = SIMD3<Float>(dx, dy, dz)
        ballInFlight  = true
        phase         = .ballInFlight
    }

    private func checkGoalOrMiss() {
        let bx = ball.position.x
        let by = ball.position.y

        let inWidth  = abs(bx - goalCenter.x) < goalWidth / 2
        let inHeight = by > 0 && by < goalCenter.y + goalHeight / 2

        // Check if goalkeeper is blocking
        let gkDist = simd_distance(ball.position, goalkeeper.position)
        let blocked = gkDist < (ballRadius + 0.55)

        if inWidth && inHeight && !blocked {
            handleScored()
        } else {
            handleBlocked()
        }
    }

    // MARK: - Trajectory dashes

    private func rebuildTrajectory() {
        clearDashes()
        guard simd_length(aimDirection) > 0.05 else { return }

        let steps  = 8
        let step   = SIMD3<Float>(aimDirection.x * 0.3, 0.1, -0.5)

        for i in 1...steps {
            let pos = ball.position + step * Float(i)

            let dashMesh = MeshResource.generateBox(size: [0.06, 0.06, 0.25])
            var dashMat  = SimpleMaterial()
            dashMat.color = .init(tint: UIColor(red: 1, green: 0.85, blue: 0.0, alpha: 0.85), texture: nil)
            let dash = ModelEntity(mesh: dashMesh, materials: [dashMat])
            dash.position = pos

            root.addChild(dash)
            dashEntities.append(dash)
        }
    }

    private func clearDashes() {
        dashEntities.forEach { $0.removeFromParent() }
        dashEntities.removeAll()
    }

    // MARK: - Camera

    private func updateCamera() {
        let targetPos = ball.position
        let x = sin(cameraAngle) * cameraDistance
        let z = cos(cameraAngle) * cameraDistance
        let camPos = targetPos + SIMD3<Float>(x, 2.2, z)

        camera.position = camPos
        camera.look(at: targetPos, from: camPos, relativeTo: nil)
    }

    // MARK: - Goal post builder

    private static func buildGoalPost(center: SIMD3<Float>,
                                      width: Float,
                                      height: Float) -> Entity {
        let container = Entity()
        let postRadius: Float = 0.07
        let mat = SimpleMaterial(color: .white, roughness: 0.3, isMetallic: true)

        // Left post
        let leftMesh = MeshResource.generateBox(size: [postRadius * 2, height, postRadius * 2])
        let leftPost = ModelEntity(mesh: leftMesh, materials: [mat])
        leftPost.position = [center.x - width / 2, center.y, center.z]
        container.addChild(leftPost)

        // Right post
        let rightMesh = MeshResource.generateBox(size: [postRadius * 2, height, postRadius * 2])
        let rightPost = ModelEntity(mesh: rightMesh, materials: [mat])
        rightPost.position = [center.x + width / 2, center.y, center.z]
        container.addChild(rightPost)

        // Crossbar
        let barMesh = MeshResource.generateBox(size: [width + postRadius * 2, postRadius * 2, postRadius * 2])
        let crossbar = ModelEntity(mesh: barMesh, materials: [mat])
        crossbar.position = [center.x, center.y + height / 2, center.z]
        container.addChild(crossbar)

        // Back net (visual only — thin plane)
        var netMat = SimpleMaterial()
        netMat.color = .init(tint: UIColor(white: 1, alpha: 0.15), texture: nil)
        let netMesh = MeshResource.generatePlane(width: width, depth: height)
        let net = ModelEntity(mesh: netMesh, materials: [netMat])
        // Rotate the plane so it stands upright in the XY plane
        net.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        net.position = [center.x, center.y, center.z - 0.05]
        container.addChild(net)

        return container
    }
}

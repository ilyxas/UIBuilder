import Foundation
import QuartzCore
import CoreGraphics

@MainActor
@Observable
final class GameWorld {

    static let shared = GameWorld()

    private(set) var state = GamePieceState()

    static let didTickNotification = Notification.Name("GameWorld.didTick")

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    private var queue: [GameCommand] = []
    private let maxCommandsPerTick = 4

    private init() {}

    func start() {
        guard displayLink == nil else { return }

        lastTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(onTick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
    }

    func reset() {
        state = GamePieceState()
        queue.removeAll()
        NotificationCenter.default.post(name: Self.didTickNotification, object: self)
    }

    func enqueue(_ commands: [GameCommand]) {
        queue.append(contentsOf: commands)
    }

    @objc
    private func onTick(_ link: CADisplayLink) {
        if lastTimestamp == 0 { lastTimestamp = link.timestamp }
        let dt = CGFloat(link.timestamp - lastTimestamp)
        lastTimestamp = link.timestamp

        step(dt: dt)

        NotificationCenter.default.post(name: Self.didTickNotification, object: self)
    }

    private func step(dt: CGFloat) {
        let n = min(queue.count, maxCommandsPerTick)
        guard n > 0 else { return }

        let commands = queue.prefix(n)
        queue.removeFirst(n)

        for cmd in commands {
            apply(cmd, dt: dt)
        }
    }

    private func apply(_ cmd: GameCommand, dt: CGFloat) {
        _ = dt

        switch cmd {
        case .setSpeedProfile(let profile):
            state.speedProfile = profile

        case .halt:
            state.isHalted = true

        case .step:
            state.isHalted = false
            let next = state.pointForward()
            if !state.isBlocked(next) {
                state.x = next.x
                state.y = next.y
            }

        case .reverse:
            state.isHalted = false
            let reverseHeading = (state.normalizedHeading + 2) % 4
            let next = point(from: state.playerPoint, heading: reverseHeading)
            if !state.isBlocked(next) {
                state.x = next.x
                state.y = next.y
            }

        case .rotateLeft:
            state.isHalted = false
            state.headingIndex = (state.normalizedHeading + 3) % 4

        case .rotateRight:
            state.isHalted = false
            state.headingIndex = (state.normalizedHeading + 1) % 4
        }
    }

    private func point(from origin: GridPoint, heading: Int) -> GridPoint {
        switch heading {
        case 0:
            return GridPoint(x: origin.x + 1, y: origin.y)
        case 1:
            return GridPoint(x: origin.x, y: origin.y + 1)
        case 2:
            return GridPoint(x: origin.x - 1, y: origin.y)
        default:
            return GridPoint(x: origin.x, y: origin.y - 1)
        }
    }
}

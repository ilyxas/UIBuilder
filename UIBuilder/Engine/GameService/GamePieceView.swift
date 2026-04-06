import UIKit
import CoreGraphics

final class GamePieceView: UIView {

    private var state = GamePieceState()

    private let inset: CGFloat = 16
    private let pieceRadius: CGFloat = 12
    private let goalRadius: CGFloat = 10

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reset() {
        state = GamePieceState()
        setNeedsDisplay()
    }

    func update(state: GamePieceState) {
        self.state = state
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        drawGrid(in: ctx, rect: rect)
        drawObstacles(in: ctx, rect: rect)
        drawGoal(in: ctx, rect: rect)
        drawPlayer(in: ctx, rect: rect)
    }

    private func drawGrid(in ctx: CGContext, rect: CGRect) {
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.tertiaryLabel.withAlphaComponent(0.28).cgColor)
        ctx.setLineWidth(1)

        let cell = cellSize(in: rect)

        for x in 0...state.gridWidth {
            let px = inset + CGFloat(x) * cell.width
            ctx.move(to: CGPoint(x: px, y: inset))
            ctx.addLine(to: CGPoint(x: px, y: inset + CGFloat(state.gridHeight) * cell.height))
        }

        for y in 0...state.gridHeight {
            let py = inset + CGFloat(y) * cell.height
            ctx.move(to: CGPoint(x: inset, y: py))
            ctx.addLine(to: CGPoint(x: inset + CGFloat(state.gridWidth) * cell.width, y: py))
        }

        ctx.strokePath()
        ctx.restoreGState()
    }

    private func drawObstacles(in ctx: CGContext, rect: CGRect) {
        ctx.saveGState()
        ctx.setFillColor(UIColor.systemRed.withAlphaComponent(0.85).cgColor)

        for obstacle in state.obstacles {
            let r = rectForCell(point: obstacle, in: rect).insetBy(dx: 4, dy: 4)
            ctx.addRect(r)
            ctx.fillPath()
        }

        ctx.restoreGState()
    }

    private func drawGoal(in ctx: CGContext, rect: CGRect) {
        ctx.saveGState()

        let center = centerForCell(point: state.goal, in: rect)
        let outer = CGRect(
            x: center.x - goalRadius,
            y: center.y - goalRadius,
            width: goalRadius * 2,
            height: goalRadius * 2
        )

        ctx.setFillColor(UIColor.systemGreen.cgColor)
        ctx.addEllipse(in: outer)
        ctx.fillPath()

        let inner = outer.insetBy(dx: 4, dy: 4)
        ctx.setFillColor(UIColor.secondarySystemBackground.cgColor)
        ctx.addEllipse(in: inner)
        ctx.fillPath()

        ctx.restoreGState()
    }

    private func drawPlayer(in ctx: CGContext, rect: CGRect) {
        ctx.saveGState()

        let center = centerForCell(point: state.playerPoint, in: rect)

        let dotRect = CGRect(
            x: center.x - pieceRadius,
            y: center.y - pieceRadius,
            width: pieceRadius * 2,
            height: pieceRadius * 2
        )

        ctx.setFillColor(UIColor.systemBlue.cgColor)
        ctx.addEllipse(in: dotRect)
        ctx.fillPath()

        let arrowLength: CGFloat = 26
        let angle = state.headingRadians
        let dx = cos(angle) * arrowLength
        let dy = sin(angle) * arrowLength

        let arrowEnd = CGPoint(x: center.x + dx, y: center.y + dy)

        ctx.setStrokeColor(UIColor.systemBlue.cgColor)
        ctx.setLineWidth(4)
        ctx.setLineCap(.round)
        ctx.move(to: center)
        ctx.addLine(to: arrowEnd)
        ctx.strokePath()

        drawArrowHead(in: ctx, tip: arrowEnd, angle: angle)

        ctx.restoreGState()
    }

    private func drawArrowHead(in ctx: CGContext, tip: CGPoint, angle: CGFloat) {
        let headLen: CGFloat = 10
        let headAngle: CGFloat = .pi / 7

        let left = CGPoint(
            x: tip.x - cos(angle - headAngle) * headLen,
            y: tip.y - sin(angle - headAngle) * headLen
        )

        let right = CGPoint(
            x: tip.x - cos(angle + headAngle) * headLen,
            y: tip.y - sin(angle + headAngle) * headLen
        )

        ctx.saveGState()
        ctx.setFillColor(UIColor.systemBlue.cgColor)
        ctx.move(to: tip)
        ctx.addLine(to: left)
        ctx.addLine(to: right)
        ctx.closePath()
        ctx.fillPath()
        ctx.restoreGState()
    }

    private func cellSize(in rect: CGRect) -> CGSize {
        let usableWidth = rect.width - inset * 2
        let usableHeight = rect.height - inset * 2

        return CGSize(
            width: usableWidth / CGFloat(max(state.gridWidth, 1)),
            height: usableHeight / CGFloat(max(state.gridHeight, 1))
        )
    }

    private func rectForCell(point: GridPoint, in rect: CGRect) -> CGRect {
        let cell = cellSize(in: rect)

        return CGRect(
            x: inset + CGFloat(point.x) * cell.width,
            y: inset + CGFloat(point.y) * cell.height,
            width: cell.width,
            height: cell.height
        )
    }

    private func centerForCell(point: GridPoint, in rect: CGRect) -> CGPoint {
        let r = rectForCell(point: point, in: rect)
        return CGPoint(x: r.midX, y: r.midY)
    }
}

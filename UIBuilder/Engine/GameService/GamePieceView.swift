import UIKit
import CoreGraphics

/// Simple debug visualizer:
/// - draws a dot at (x,y)
/// - draws an arrow showing heading
/// - auto-scales to keep the piece visible
final class GamePieceView: UIView {

    // World -> View mapping
    private var worldX: CGFloat = 0
    private var worldY: CGFloat = 0
    private var heading: CGFloat = 0

    // Dynamic view scaling
    private var scale: CGFloat = 24          // pixels per world unit (auto adjusted)
    private var centerOffset: CGPoint = .zero // keeps view centered

    // Visual tuning
    private let dotRadius: CGFloat = 8
    private let arrowLength: CGFloat = 36
    private let gridStepPx: CGFloat = 40

    // Track bounds of seen positions for gentle autoscale/center
    private var minX: CGFloat = 0
    private var maxX: CGFloat = 0
    private var minY: CGFloat = 0
    private var maxY: CGFloat = 0
    private var hasBounds = false

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
        worldX = 0
        worldY = 0
        heading = 0
        hasBounds = false
        scale = 24
        centerOffset = .zero
        setNeedsDisplay()
    }

    func update(x: CGFloat, y: CGFloat, headingRadians: CGFloat) {
        worldX = x
        worldY = y
        heading = headingRadians

        updateBounds(x: x, y: y)
        recalcTransform()

        setNeedsDisplay()
    }

    private func updateBounds(x: CGFloat, y: CGFloat) {
        if !hasBounds {
            minX = x; maxX = x; minY = y; maxY = y
            hasBounds = true
            return
        }
        minX = min(minX, x)
        maxX = max(maxX, x)
        minY = min(minY, y)
        maxY = max(maxY, y)
    }

    private func recalcTransform() {
        // Keep all visited points comfortably inside view.
        let w = max(bounds.width, 1)
        let h = max(bounds.height, 1)

        let spanX = max(maxX - minX, 1.0)
        let spanY = max(maxY - minY, 1.0)

        // Add margins so dot+arrow fit
        let margin: CGFloat = 2.6 * dotRadius + arrowLength
        let maxScaleX = (w - margin) / spanX
        let maxScaleY = (h - margin) / spanY

        // Clamp scale to avoid tiny/huge extremes
        let targetScale = max(10, min(60, min(maxScaleX, maxScaleY)))
        // Smooth a bit
        scale = scale * 0.85 + targetScale * 0.15

        // Center on the midpoint of the visited bounds
        let midX = (minX + maxX) * 0.5
        let midY = (minY + maxY) * 0.5

        // Convert that midpoint to view center (y axis inverted)
        let viewCenter = CGPoint(x: w * 0.5, y: h * 0.5)
        let mappedMid = CGPoint(x: midX * scale, y: -midY * scale)
        centerOffset = CGPoint(x: viewCenter.x - mappedMid.x, y: viewCenter.y - mappedMid.y)
    }

    private func worldToView(_ p: CGPoint) -> CGPoint {
        CGPoint(
            x: p.x * scale + centerOffset.x,
            y: -p.y * scale + centerOffset.y
        )
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Background grid
        drawGrid(in: ctx, rect: rect)

        // Draw axes through view center (for orientation)
        drawAxes(in: ctx, rect: rect)

        // Dot position
        let pos = worldToView(CGPoint(x: worldX, y: worldY))

        // Arrow end
        let dx = cos(heading) * (arrowLength)
        let dy = -sin(heading) * (arrowLength) // view Y is down, so invert
        let arrowEnd = CGPoint(x: pos.x + dx, y: pos.y + dy)

        // Dot
        ctx.setFillColor(UIColor.systemBlue.cgColor)
        ctx.addEllipse(in: CGRect(x: pos.x - dotRadius, y: pos.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
        ctx.fillPath()

        // Arrow line
        ctx.setStrokeColor(UIColor.systemBlue.cgColor)
        ctx.setLineWidth(3)
        ctx.setLineCap(.round)
        ctx.move(to: pos)
        ctx.addLine(to: arrowEnd)
        ctx.strokePath()

        // Arrow head
        drawArrowHead(in: ctx, tip: arrowEnd, angle: heading)
    }

    private func drawGrid(in ctx: CGContext, rect: CGRect) {
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.tertiaryLabel.withAlphaComponent(0.25).cgColor)
        ctx.setLineWidth(1)

        var x: CGFloat = 0
        while x <= rect.width {
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: rect.height))
            x += gridStepPx
        }

        var y: CGFloat = 0
        while y <= rect.height {
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: rect.width, y: y))
            y += gridStepPx
        }

        ctx.strokePath()
        ctx.restoreGState()
    }

    private func drawAxes(in ctx: CGContext, rect: CGRect) {
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.secondaryLabel.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(1.5)

        let cx = rect.midX
        let cy = rect.midY

        ctx.move(to: CGPoint(x: 0, y: cy))
        ctx.addLine(to: CGPoint(x: rect.width, y: cy))

        ctx.move(to: CGPoint(x: cx, y: 0))
        ctx.addLine(to: CGPoint(x: cx, y: rect.height))

        ctx.strokePath()
        ctx.restoreGState()
    }

    private func drawArrowHead(in ctx: CGContext, tip: CGPoint, angle: CGFloat) {
        ctx.saveGState()

        let headLen: CGFloat = 12
        let headAngle: CGFloat = .pi / 7

        // We already inverted Y when computing arrow line end, so treat angle in "world"
        // and build head in view coordinates using same convention:
        let a = -angle

        let left = CGPoint(
            x: tip.x - cos(a - headAngle) * headLen,
            y: tip.y - sin(a - headAngle) * headLen
        )
        let right = CGPoint(
            x: tip.x - cos(a + headAngle) * headLen,
            y: tip.y - sin(a + headAngle) * headLen
        )

        ctx.setFillColor(UIColor.systemBlue.cgColor)
        ctx.move(to: tip)
        ctx.addLine(to: left)
        ctx.addLine(to: right)
        ctx.closePath()
        ctx.fillPath()

        ctx.restoreGState()
    }
}

import CoreGraphics
import CoreVideo
import Foundation
import UIKit

final class DashRenderer {
    let width: Int
    let height: Int

    init(width: Int = 526, height: Int = 300) {
        self.width = width
        self.height = height
    }

    func render(_ state: ProjectionUIState) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else {
            throw DashRendererError.pixelBufferCreationFailed(status)
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            throw DashRendererError.missingBaseAddress
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue |
                CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw DashRendererError.contextCreationFailed
        }

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }
        draw(state, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    private func draw(_ state: ProjectionUIState, in bounds: CGRect) {
        let safe = bounds.insetBy(dx: 52, dy: 20)
        let white = UIColor.white
        let secondary = UIColor(white: 0.72, alpha: 1)
        let accent = UIColor.systemOrange

        let topFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
        state.statusText.draw(
            in: CGRect(x: safe.minX, y: safe.minY, width: safe.width, height: 24),
            withAttributes: [.font: topFont, .foregroundColor: secondary]
        )

        let arrowRect = CGRect(x: safe.minX + 6, y: 65, width: 88, height: 88)
        drawManeuver(state.maneuver, in: arrowRect, color: accent)

        let distanceText = formattedDistance(state.distanceToTurnMeters)
        distanceText.draw(
            in: CGRect(x: safe.minX + 110, y: 58, width: safe.width - 110, height: 52),
            withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 42, weight: .bold),
                .foregroundColor: white
            ]
        )

        state.roadName.draw(
            in: CGRect(x: safe.minX + 110, y: 112, width: safe.width - 115, height: 58),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 20, weight: .medium),
                .foregroundColor: white
            ]
        )

        let remaining = "Remaining \(formattedDistance(state.remainingDistanceMeters))"
        remaining.draw(
            in: CGRect(x: safe.minX, y: 204, width: safe.width * 0.55, height: 28),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: secondary
            ]
        )

        let speed = "\(Int(state.speedKPH.rounded())) km/h"
        speed.draw(
            in: CGRect(x: safe.midX, y: 204, width: safe.width * 0.5, height: 28),
            withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: secondary
            ]
        )

        if let eta = state.eta {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            let etaText = "ETA \(formatter.string(from: eta))"
            etaText.draw(
                in: CGRect(x: safe.minX, y: 238, width: safe.width, height: 28),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                    .foregroundColor: white
                ]
            )
        }

        if state.isRerouting {
            let text = "Rerouting…"
            text.draw(
                in: CGRect(x: safe.maxX - 120, y: safe.minY, width: 120, height: 24),
                withAttributes: [.font: topFont, .foregroundColor: accent]
            )
        }
    }

    private func drawManeuver(_ maneuver: NavigationManeuver, in rect: CGRect, color: UIColor) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.setLineWidth(12)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let top = rect.minY + 8
        let bottom = rect.maxY - 8
        let left = rect.minX + 8
        let right = rect.maxX - 8

        switch maneuver {
        case .turnLeft, .slightLeft:
            context.move(to: CGPoint(x: center.x, y: bottom))
            context.addLine(to: CGPoint(x: center.x, y: center.y))
            context.addLine(to: CGPoint(x: left + 12, y: center.y))
            context.strokePath()
            drawArrowHead(at: CGPoint(x: left + 8, y: center.y), pointing: .left, context: context)
        case .turnRight, .slightRight:
            context.move(to: CGPoint(x: center.x, y: bottom))
            context.addLine(to: CGPoint(x: center.x, y: center.y))
            context.addLine(to: CGPoint(x: right - 12, y: center.y))
            context.strokePath()
            drawArrowHead(at: CGPoint(x: right - 8, y: center.y), pointing: .right, context: context)
        case .uTurn:
            context.addArc(center: CGPoint(x: center.x, y: center.y), radius: 25, startAngle: .pi / 2, endAngle: .pi * 1.8, clockwise: true)
            context.strokePath()
            drawArrowHead(at: CGPoint(x: center.x - 24, y: center.y + 8), pointing: .down, context: context)
        case .roundabout:
            context.addEllipse(in: rect.insetBy(dx: 18, dy: 18))
            context.strokePath()
            drawArrowHead(at: CGPoint(x: right - 12, y: center.y), pointing: .right, context: context)
        case .arrive:
            context.fillEllipse(in: CGRect(x: center.x - 16, y: center.y - 16, width: 32, height: 32))
        case .continueStraight:
            context.move(to: CGPoint(x: center.x, y: bottom))
            context.addLine(to: CGPoint(x: center.x, y: top + 15))
            context.strokePath()
            drawArrowHead(at: CGPoint(x: center.x, y: top + 6), pointing: .up, context: context)
        }
    }

    private enum ArrowDirection { case up, down, left, right }

    private func drawArrowHead(at point: CGPoint, pointing direction: ArrowDirection, context: CGContext) {
        let size: CGFloat = 17
        let path = UIBezierPath()
        switch direction {
        case .up:
            path.move(to: CGPoint(x: point.x, y: point.y - size))
            path.addLine(to: CGPoint(x: point.x - size, y: point.y + size * 0.6))
            path.addLine(to: CGPoint(x: point.x + size, y: point.y + size * 0.6))
        case .down:
            path.move(to: CGPoint(x: point.x, y: point.y + size))
            path.addLine(to: CGPoint(x: point.x - size, y: point.y - size * 0.6))
            path.addLine(to: CGPoint(x: point.x + size, y: point.y - size * 0.6))
        case .left:
            path.move(to: CGPoint(x: point.x - size, y: point.y))
            path.addLine(to: CGPoint(x: point.x + size * 0.6, y: point.y - size))
            path.addLine(to: CGPoint(x: point.x + size * 0.6, y: point.y + size))
        case .right:
            path.move(to: CGPoint(x: point.x + size, y: point.y))
            path.addLine(to: CGPoint(x: point.x - size * 0.6, y: point.y - size))
            path.addLine(to: CGPoint(x: point.x - size * 0.6, y: point.y + size))
        }
        path.close()
        context.addPath(path.cgPath)
        context.fillPath()
    }

    private func formattedDistance(_ meters: Int) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", Double(meters) / 1000)
        }
        return "\(max(0, meters)) m"
    }
}

enum DashRendererError: LocalizedError {
    case pixelBufferCreationFailed(CVReturn)
    case missingBaseAddress
    case contextCreationFailed

    var errorDescription: String? {
        switch self {
        case .pixelBufferCreationFailed(let code): return "Pixel buffer creation failed (\(code))."
        case .missingBaseAddress: return "Pixel buffer has no writable base address."
        case .contextCreationFailed: return "Could not create dash drawing context."
        }
    }
}

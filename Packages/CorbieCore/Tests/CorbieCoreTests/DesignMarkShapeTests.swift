import CoreGraphics
import SwiftUI
import Testing
@testable import CorbieCore

@Suite struct DesignMarkShapeTests {
    private static let betweenTheHeads = CGPoint(x: 0.4995, y: 0.1301)
    private static let channelBetweenTheBodies = CGPoint(x: 0.4264, y: 0.5996)
    private static let leftBodyBesideTheChannel = CGPoint(x: 0.3725, y: 0.5996)
    private static let rightBodyBesideTheChannel = CGPoint(x: 0.5116, y: 0.5996)

    @Test func theMarkKeepsItsAspectAndSitsInTheMiddleOfAnyRect() {
        for rect in [CGRect(x: 0, y: 0, width: 300, height: 100), CGRect(x: 10, y: 20, width: 100, height: 300)] {
            let box = CorbieMarkShape().path(in: rect).cgPath.boundingBoxOfPath
            #expect(abs(box.width / box.height - CorbieMarkGeometry.aspectRatio) < 0.01)
            #expect(abs(box.midX - rect.midX) < 1)
            #expect(abs(box.midY - rect.midY) < 1)
            #expect(rect.insetBy(dx: -0.5, dy: -0.5).contains(box))
        }
    }

    @Test func bothRavensTogetherAreTheMark() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 200)
        var ravens = Path()
        for side in CorbieRavenSide.allCases {
            ravens.addPath(CorbieRavenShape(side: side).path(in: rect))
        }
        let mark = CorbieMarkShape().path(in: rect).cgPath.boundingBoxOfPath
        #expect(abs(ravens.boundingRect.minX - mark.minX) < 0.01)
        #expect(abs(ravens.boundingRect.maxX - mark.maxX) < 0.01)
        #expect(abs(ravens.boundingRect.minY - mark.minY) < 0.01)
        #expect(abs(ravens.boundingRect.maxY - mark.maxY) < 0.01)
        #expect(CorbieRavenShape(side: .left).path(in: rect).cgPath.boundingBoxOfPath.midX < rect.midX)
        #expect(CorbieRavenShape(side: .right).path(in: rect).cgPath.boundingBoxOfPath.midX > rect.midX)
    }

    @Test func theSpaceBetweenTheHeadsIsOpenAt24Points() {
        let raster = MarkRaster(points: 24, scale: 3)
        #expect(raster.coverage(at: Self.betweenTheHeads) < 0.05)
        #expect(raster.coverage(at: Self.leftBodyBesideTheChannel) > 0.9)
        #expect(raster.coverage(at: Self.rightBodyBesideTheChannel) > 0.9)
    }

    @Test func theChannelBetweenTheBodiesStaysLighterThanTheBodiesAt24Points() {
        let raster = MarkRaster(points: 24, scale: 3)
        let channel = raster.coverage(at: Self.channelBetweenTheBodies)
        let bodies = min(
            raster.coverage(at: Self.leftBodyBesideTheChannel),
            raster.coverage(at: Self.rightBodyBesideTheChannel)
        )
        #expect(bodies - channel > 0.15, "channel \(channel), bodies \(bodies)")
    }

    @Test func theChannelIsFullyOpenAt200Points() {
        let raster = MarkRaster(points: 200, scale: 1)
        #expect(raster.coverage(at: Self.channelBetweenTheBodies) < 0.05)
    }
}

private struct MarkRaster {
    private let pixels: [UInt8]
    private let side: Int
    private let scale: CGFloat
    private let box: CGRect

    init(points: CGFloat, scale: CGFloat) {
        let rect = CGRect(x: 0, y: 0, width: points, height: points)
        let side = Int(points * scale)
        self.scale = scale
        self.side = side
        box = CorbieMarkGeometry.fitted(in: rect)
        pixels = Self.render(CorbieMarkShape().path(in: rect), side: side, scale: scale)
    }

    private static func render(_ path: Path, side: Int, scale: CGFloat) -> [UInt8] {
        var data = [UInt8](repeating: 255, count: side * side)
        data.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return }
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            context.scaleBy(x: scale, y: scale)
            context.addPath(path.cgPath)
            context.setFillColor(gray: 0, alpha: 1)
            context.fillPath()
        }
        return data
    }

    func coverage(at unit: CGPoint) -> Double {
        let x = Int(((box.minX + unit.x * box.width) * scale).rounded(.down))
        let yFromTop = Int(((box.minY + unit.y * box.height) * scale).rounded(.down))
        let y = side - 1 - yFromTop
        return 1 - Double(pixels[y * side + x]) / 255
    }
}

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageDownsampler {
    public static let maxPixelSize = 1024
    public static let compressionQuality = 0.8
    public static let byteLimit = 1_000_000

    public struct Result: Sendable, Equatable {
        public let data: Data
        public let pixelWidth: Int
        public let pixelHeight: Int

        public init(data: Data, pixelWidth: Int, pixelHeight: Int) {
            self.data = data
            self.pixelWidth = pixelWidth
            self.pixelHeight = pixelHeight
        }
    }

    public static func downsample(
        _ data: Data,
        maxPixelSize: Int = ImageDownsampler.maxPixelSize,
        quality: Double = ImageDownsampler.compressionQuality,
        byteLimit: Int = ImageDownsampler.byteLimit
    ) -> Result? {
        guard data.isEmpty == false,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }

        var sizes = [maxPixelSize]
        var next = maxPixelSize
        while next > 256 {
            next = next * 3 / 4
            sizes.append(next)
        }

        for size in sizes {
            guard let image = thumbnail(from: source, maxPixelSize: size) else { continue }
            for step in qualitySteps(from: quality) {
                guard let encoded = encodeJPEG(image, quality: step) else { continue }
                if encoded.count <= byteLimit {
                    return Result(data: encoded, pixelWidth: image.width, pixelHeight: image.height)
                }
            }
        }
        return nil
    }

    private static func qualitySteps(from quality: Double) -> [Double] {
        let start = min(max(0.1, quality), 1)
        return [start, start * 0.75, start * 0.5]
    }

    private static func thumbnail(from source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func encodeJPEG(_ image: CGImage, quality: Double) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

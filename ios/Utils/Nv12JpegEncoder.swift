import Foundation
import CoreImage
import CoreVideo
import ImageIO

public enum Nv12JpegEncoder {
    private static let ciContext = CIContext(options: [
        CIContextOption.useSoftwareRenderer: false
    ])

    public static func encode(
        pixelBuffer: CVPixelBuffer,
        quality: Int
    ) -> [UInt8] {
        let compressionQuality = CGFloat(max(0, min(quality, 100))) / 100.0

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let jpegData = ciContext.jpegRepresentation(
            of: ciImage,
            colorSpace: colorSpace,
            options: [
                kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: compressionQuality
            ]
        ) else {
            return []
        }

        return [UInt8](jpegData)
    }
}
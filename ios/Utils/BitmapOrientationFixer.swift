import Foundation
import UIKit
import NitroModules
import VisionCamera

public enum BitmapOrientationFixer {
    public static func fix(
        jpegBytes: [UInt8],
        frame: any HybridFrameSpec,
        quality: Int
    ) -> [UInt8] {

        let data = Data(jpegBytes)
        guard let image = UIImage(data: data),
              let cgImage = image.cgImage
        else {
            return jpegBytes
        }

        let uiOrientation: UIImage.Orientation

        switch frame.orientation {
        case .up:
            uiOrientation = frame.isMirrored ? .upMirrored : .up
        case .down:
            uiOrientation = frame.isMirrored ? .downMirrored : .down
        case .left:
            uiOrientation = frame.isMirrored ? .leftMirrored : .left
        case .right:
            uiOrientation = frame.isMirrored ? .rightMirrored : .right
        @unknown default:
            uiOrientation = .up
        }

        // 1. Wrap the image with the correct EXIF layout metadata
        let orientedImage = UIImage(
            cgImage: cgImage,
            scale: 1.0, // Force 1.0 to preserve raw camera matrix resolution
            orientation: uiOrientation
        )

        // 2. Configure a 1:1 hardware pixel canvas context format
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1.0
        rendererFormat.opaque = true // JPEG does not support transparency, making it opaque saves memory performance

        // 3. Draw and physically bake the metadata rotation permanently into new pixel bytes
        let bakedImage = UIGraphicsImageRenderer(
            size: orientedImage.size,
            format: rendererFormat
        ).image { _ in
            orientedImage.draw(in: CGRect(origin: .zero, size: orientedImage.size))
        }

        let compressionQuality = CGFloat(max(0, min(quality, 100))) / 100.0

        // 4. Compress the baked image. The metadata flag is now gone, and the pixels themselves are rotated.
        guard let outputData = bakedImage.jpegData(compressionQuality: compressionQuality) else {
            return jpegBytes
        }

        return [UInt8](outputData)
    }
}

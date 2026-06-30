import Foundation
import NitroModules
import VisionCamera
import CoreVideo

public enum FrameJpegConverter {
    private static let tag = "YOLO_TAG_FrameJpegConverter"

    public static func toJpegBytes(frame: any HybridFrameSpec, quality: Int = 80) -> [UInt8] {
        do {
            let nativeBuffer = try frame.getNativeBuffer()

            guard let rawPointer = UnsafeRawPointer(bitPattern: UInt(nativeBuffer.pointer)) else {
                NSLog("[%@]: ❌ Failed to get native buffer pointer", tag)
                return []
            }

            let pixelBuffer = Unmanaged<CVPixelBuffer>
                .fromOpaque(rawPointer)
                .takeUnretainedValue()

            let jpegBytes = Nv12JpegEncoder.encode(
                pixelBuffer: pixelBuffer,
                quality: quality
            )

            if jpegBytes.isEmpty {
                NSLog("[%@]: ❌ Failed to encode pixelBuffer to JPEG bytes", tag)
                return []
            }

            return BitmapOrientationFixer.fix(
                jpegBytes: jpegBytes,
                frame: frame,
                quality: quality
            )
        } catch {
            NSLog("[%@]: ❌ Failed to convert frame to JPEG: %@", tag, "\(error)")
            return []
        }
    }
}
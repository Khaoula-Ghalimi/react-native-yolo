import Foundation
import NitroModules
import VisionCamera

public enum FrameJpegConverter {
    private static let tag = "YOLO_TAG_FrameJpegConverter"
    
    public static func toJpegBytes(frame: any HybridFrameSpec, quality: Int = 80) -> [UInt8] {
        // 1. Extraction et arrondi propre des dimensions du frame
        let width = Int(frame.width.rounded())
        let height = Int(frame.height.rounded())
        
        // 2. Conversion ultra-rapide via memcpy vers le format matériel NV12
        let nv12 = Yuv420ToNv12Converter.convert(frame: frame, width: width, height: height)
        
        if nv12.isEmpty {
            NSLog("[%@]: ❌ Failed to convert frame to NV12 array", tag)
            return []
        }
        
        // 3. Encodage matériel en JPEG via le GPU (CoreImage / CIContext)
        let jpegBytes = Nv12JpegEncoder.encode(
            nv12: nv12,
            width: width,
            height: height,
            quality: quality
        )
        
        if jpegBytes.isEmpty {
            NSLog("[%@]: ❌ Failed to encode NV12 data to JPEG bytes", tag)
            return []
        }
        
        // 4. Redessin de sécurité via UIGraphicsImageRenderer pour fixer définitivement les pixels
        return BitmapOrientationFixer.fix(
            jpegBytes: jpegBytes,
            frame: frame,
            quality: quality
        )
    }
}

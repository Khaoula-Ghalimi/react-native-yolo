import Foundation
import AVFoundation
import NitroModules
import VisionCamera
import CoreVideo

public enum Yuv420ToNv12Converter {
    public static func convert(frame: any HybridFrameSpec, width: Int, height: Int) -> [UInt8] {
        do {
            let nativeBuffer = try frame.getNativeBuffer()
            guard let rawPointer = nativeBuffer.pointer else { return [] }

            let pixelBuffer = Unmanaged<CVPixelBuffer>
                .fromOpaque(rawPointer)
                .takeUnretainedValue()

            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            defer {
                CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            }

            guard
                let yBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
                let uvBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
            else {
                return []
            }

            let yRowStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            let uvRowStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)

            let ySize = width * height
            let uvSize = ySize / 2

            var nv12 = [UInt8](repeating: 0, count: ySize + uvSize)

            nv12.withUnsafeMutableBytes { dstBuffer in
                guard let dstBase = dstBuffer.baseAddress else { return }

                let ySrc = yBaseAddress.assumingMemoryBound(to: UInt8.self)
                let uvSrc = uvBaseAddress.assumingMemoryBound(to: UInt8.self)
                let dst = dstBase.assumingMemoryBound(to: UInt8.self)

                // 1. Copy Y Plane row-by-row to safely discard padding/stride
                for row in 0..<height {
                    memcpy(
                        dst.advanced(by: row * width),
                        ySrc.advanced(by: row * yRowStride),
                        width
                    )
                }

                // 2. Copy UV Plane row-by-row safely
                let uvDstStart = ySize
                let chromaHeight = height / 2

                for row in 0..<chromaHeight {
                    memcpy(
                        dst.advanced(by: uvDstStart + (row * width)), // Fixed layout math
                        uvSrc.advanced(by: row * uvRowStride),
                        width
                    )
                }
            }

            return nv12
        } catch {
            return []
        }
    }
}

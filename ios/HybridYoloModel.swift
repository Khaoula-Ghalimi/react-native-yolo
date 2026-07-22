import Foundation
import NitroModules
import TensorFlowLite
import VisionCamera
import CoreVideo

public class HybridYoloModel: HybridYoloModelSpec {
    private static let tag = "YOLO_MODEL_TAG"
    
    private let modelLoader = YoloModelLoader()
    
    private var interpreter: Interpreter? = nil
    private var retainedModelData: Data? = nil
    private var inputBuffer: Data? = nil
    private var inputWidth = 0
    private var inputHeight = 0
    private var inputDataType: Tensor.DataType? = nil
    
    private let threadLock = NSLock()
    
    public required init(modelPath: String) throws {
        super.init()
        try load(modelPath: modelPath)
    }
    
    private func load(modelPath: String) throws {
        do {
            let modelData = try modelLoader.load(modelPath: modelPath)
            // Keep the model bytes alive while the interpreter exists
            retainedModelData = modelData






            // Initialisation de l'interpréteur TensorFlowLiteSwift
            interpreter = try Interpreter(modelData: modelData)
            guard let localInterpreter = interpreter else { return }
            
            try localInterpreter.allocateTensors()
            
            let inputTensor = try localInterpreter.input(at: 0)
            let outputTensor = try localInterpreter.output(at: 0)
            
            let shape = inputTensor.shape.dimensions
            
            inputHeight = shape[1]
            inputWidth = shape[2]
            inputDataType = inputTensor.dataType
            inputBuffer = try modelLoader.makeInputBuffer(interpreter: localInterpreter)
            
            NSLog("[%@]: ✅ YOLO model instance loaded", HybridYoloModel.tag)
            NSLog("[%@]: 📥 Input shape: %@", HybridYoloModel.tag, shape.description)
            NSLog("[%@]: 📤 Output shape: %@", HybridYoloModel.tag, outputTensor.shape.dimensions.description)
        } catch {
            NSLog("[%@]: ❌ Failed to load model instance: %@", HybridYoloModel.tag, error.localizedDescription)
            throw error
        }
    }
    
    public func detect(frame: any HybridFrameSpec) throws -> [Detection] {
        
        guard let localInterpreter = interpreter else {
            NSLog("[%@]: ❌ This model instance is not loaded.", HybridYoloModel.tag)
            return []
        }
        
        guard FrameValidator.isValidYuv(frame: frame) else {
            NSLog("[%@]: ❌ Invalid frame provided for detection.", HybridYoloModel.tag)
            return []
        }
        NSLog("[%@]: Frame is valid for detection.", HybridYoloModel.tag)
        guard var input = inputBuffer else { return [] }
        NSLog("[%@]: Input buffer size: %d bytes", HybridYoloModel.tag, input.count)

        threadLock.lock()
        defer { threadLock.unlock() }
        
        NSLog("[%@]: Starting detection on frame...", HybridYoloModel.tag)
        // Remplissage du buffer d'entrée en analysant les données NV12
        try fillInputFromYuvFrame(
            frame: frame,
            input: &input,
            dstWidth: inputWidth,
            dstHeight: inputHeight,
            dataType: inputDataType ?? .float32
        )
        NSLog("[%@]: Input buffer filled with frame data.", HybridYoloModel.tag)
        // Injection du tampon de données brut dans le tenseur d'entrée
        let inputTensorBeforeInvoke = try localInterpreter.input(at: 0)

NSLog("[%@]: ===== BEFORE INVOKE =====", HybridYoloModel.tag)
NSLog("[%@]: Input tensor shape: %@", HybridYoloModel.tag,
      inputTensorBeforeInvoke.shape.dimensions.description)
NSLog("[%@]: Input tensor type: %@", HybridYoloModel.tag,
      String(describing: inputTensorBeforeInvoke.dataType))
NSLog("[%@]: Expected input bytes: %d", HybridYoloModel.tag,
      inputTensorBeforeInvoke.data.count)
NSLog("[%@]: Supplied input bytes: %d", HybridYoloModel.tag,
      input.count)

guard input.count == inputTensorBeforeInvoke.data.count else {
    NSLog(
        "[%@]: :x: Input byte count mismatch: expected %d, received %d",
        HybridYoloModel.tag,
        inputTensorBeforeInvoke.data.count,
        input.count
    )

    throw NSError(
        domain: "HybridYoloModel",
        code: 1001,
        userInfo: [
            NSLocalizedDescriptionKey:
                "Input byte count mismatch: expected \(inputTensorBeforeInvoke.data.count), received \(input.count)"
        ]
    )
}

NSLog("[%@]: Copying input...", HybridYoloModel.tag)
try localInterpreter.copy(input, toInputAt: 0)
NSLog("[%@]: :white_check_mark: Input copied", HybridYoloModel.tag)

do {
    NSLog("[%@]: Invoking interpreter...", HybridYoloModel.tag)
    try localInterpreter.invoke()
    NSLog("[%@]: :white_check_mark: Interpreter invocation completed", HybridYoloModel.tag)
} catch {
    NSLog(
        "[%@]: :x: TensorFlow Lite invocation error: %@",
        HybridYoloModel.tag,
        error.localizedDescription
    )
    throw error
}
        
        NSLog("[%@]: Model inference completed.", HybridYoloModel.tag)
        // Récupération des résultats du tenseur de sortie
        let outputTensor = try localInterpreter.output(at: 0)
        
        NSLog("[%@]: Output tensor shape: %@", HybridYoloModel.tag, outputTensor.shape.dimensions.description)
        // Extraction et conversion de la structure des tenseurs [1, 300, 6] en Float
        let nativeOutputs = outputTensor.data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [Float] in
            let floatPtr = ptr.assumingMemoryBound(to: Float.self)
            return Array(floatPtr)
        }
        NSLog("[%@]: Output tensor size: %d floats", HybridYoloModel.tag, nativeOutputs.count)
        return parseNmsOutput(outputArray: nativeOutputs, confidenceThreshold: 0.5)
    }
    
    public func close() throws {
        
        interpreter = nil
        inputBuffer = nil
        retainedModelData = nil
        NSLog("[%@]: 🧹 YOLO model disposed", HybridYoloModel.tag)
    }
    
    private func parseNmsOutput(outputArray: [Float], confidenceThreshold: Float = 0.5) -> [Detection] {
        var detections: [Detection] = []
        
        let totalRows = 300
        let columnsPerRow = 6
        
        // Parcours du tableau aplati [300 * 6]
        for i in 0..<totalRows {
            let offset = i * columnsPerRow
            guard offset + 5 < outputArray.count else { break }
            
            let score = outputArray[offset + 4]
            if score < confidenceThreshold { continue }
            
            let box = BoundingBox(
                x1: Double(outputArray[offset + 0]),
                y1: Double(outputArray[offset + 1]),
                x2: Double(outputArray[offset + 2]),
                y2: Double(outputArray[offset + 3])
            )
            
            detections.append(
                Detection(
                    classId: Double(outputArray[offset + 5]),
                    score: Double(score),
                    boundingBox: box
                )
            )
        }
        
        return detections
    }
    
  private func fillInputFromYuvFrame(
    frame: any HybridFrameSpec,
    input: inout Data,
    dstWidth: Int,
    dstHeight: Int,
    dataType: Tensor.DataType
) throws {
    let srcWidth = Int(frame.width)
    let srcHeight = Int(frame.height)

    guard srcWidth > 0,
          srcHeight > 0,
          dstWidth > 0,
          dstHeight > 0 else {
        NSLog(
            "[%@]: :x: Invalid source or destination dimensions.",
            HybridYoloModel.tag
        )
        return
    }

    // Retrieve the CVPixelBuffer used by VisionCamera.
    let nativeBuffer = try frame.getNativeBuffer()
    defer { nativeBuffer.release() }

    guard let rawPointer = UnsafeRawPointer(
        bitPattern: UInt(nativeBuffer.pointer)
    ) else {
        NSLog(
            "[%@]: :x: Could not retrieve native frame pointer.",
            HybridYoloModel.tag
        )
        return
    }

    let pixelBuffer = Unmanaged<CVPixelBuffer>
        .fromOpaque(rawPointer)
        .takeUnretainedValue()

    // The iOS camera frame should contain:
    // Plane 0: Y
    // Plane 1: interleaved UV
    let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)

    guard planeCount >= 2 else {
        NSLog(
            "[%@]: :x: Expected an NV12 frame with 2 planes, received %d.",
            HybridYoloModel.tag,
            planeCount
        )
        return
    }

    let lockResult = CVPixelBufferLockBaseAddress(
        pixelBuffer,
        .readOnly
    )

    guard lockResult == kCVReturnSuccess else {
        NSLog(
            "[%@]: :x: Could not lock CVPixelBuffer. Code: %d",
            HybridYoloModel.tag,
            lockResult
        )
        return
    }

    defer {
        CVPixelBufferUnlockBaseAddress(
            pixelBuffer,
            .readOnly
        )
    }

    guard
        let yBaseAddress = CVPixelBufferGetBaseAddressOfPlane(
            pixelBuffer,
            0
        ),
        let uvBaseAddress = CVPixelBufferGetBaseAddressOfPlane(
            pixelBuffer,
            1
        )
    else {
        NSLog(
            "[%@]: :x: Could not access the YUV plane addresses.",
            HybridYoloModel.tag
        )
        return
    }

    let actualWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
    let actualHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)

    let safeSrcWidth = min(srcWidth, actualWidth)
    let safeSrcHeight = min(srcHeight, actualHeight)

    guard safeSrcWidth > 0, safeSrcHeight > 0 else {
        NSLog(
            "[%@]: :x: Invalid CVPixelBuffer plane dimensions.",
            HybridYoloModel.tag
        )
        return
    }

    let yRowStride = CVPixelBufferGetBytesPerRowOfPlane(
        pixelBuffer,
        0
    )

    let uvRowStride = CVPixelBufferGetBytesPerRowOfPlane(
        pixelBuffer,
        1
    )

    let yPtr = yBaseAddress.assumingMemoryBound(to: UInt8.self)
    let uvPtr = uvBaseAddress.assumingMemoryBound(to: UInt8.self)

    let pixelCount = dstWidth * dstHeight
    let channelCount = 3

    switch dataType {
    case .float32:
        let requiredByteCount =
            pixelCount *
            channelCount *
            MemoryLayout<Float>.size

        guard input.count == requiredByteCount else {
            NSLog(
                "[%@]: :x: Float input size mismatch. Expected %d, received %d.",
                HybridYoloModel.tag,
                requiredByteCount,
                input.count
            )
            return
        }

        input.withUnsafeMutableBytes { rawOutputBuffer in
            let outputBuffer = rawOutputBuffer.bindMemory(
                to: Float.self
            )

            guard outputBuffer.count >= pixelCount * channelCount else {
                NSLog(
                    "[%@]: :x: Float output buffer is too small.",
                    HybridYoloModel.tag
                )
                return
            }

            var outputIndex = 0

            for dy in 0..<dstHeight {
                for dx in 0..<dstWidth {
                    let mappedPixel = mapModelPixelToFramePixel(
                        dx: dx,
                        dy: dy,
                        dstWidth: dstWidth,
                        dstHeight: dstHeight,
                        srcWidth: safeSrcWidth,
                        srcHeight: safeSrcHeight,
                        orientation: frame.orientation
                    )

                    let srcX = clampInt(
                        mappedPixel.x,
                        0,
                        safeSrcWidth - 1
                    )

                    let srcY = clampInt(
                        mappedPixel.y,
                        0,
                        safeSrcHeight - 1
                    )

                    let yIndex =
                        srcY * yRowStride +
                        srcX

                    // NV12 stores one UV pair for each 2×2 Y block.
                    let uvY = srcY / 2
                    let uvX = srcX / 2

                    let uvIndex =
                        uvY * uvRowStride +
                        uvX * 2

                    let yValue = Float(yPtr[yIndex])
                    let uValue = Float(Int(uvPtr[uvIndex]) - 128)
                    let vValue = Float(Int(uvPtr[uvIndex + 1]) - 128)

                    // NV12 YUV → RGB conversion.
                    let red = min(
                        max(
                            yValue + 1.402 * vValue,
                            0.0
                        ),
                        255.0
                    )

                    let green = min(
                        max(
                            yValue
                                - 0.344136 * uValue
                                - 0.714136 * vValue,
                            0.0
                        ),
                        255.0
                    )

                    let blue = min(
                        max(
                            yValue + 1.772 * uValue,
                            0.0
                        ),
                        255.0
                    )

                    outputBuffer[outputIndex] = red / 255.0
                    outputBuffer[outputIndex + 1] = green / 255.0
                    outputBuffer[outputIndex + 2] = blue / 255.0

                    outputIndex += 3
                }
            }
        }

    case .uInt8:
        let requiredByteCount =
            pixelCount *
            channelCount

        guard input.count == requiredByteCount else {
            NSLog(
                "[%@]: :x: UInt8 input size mismatch. Expected %d, received %d.",
                HybridYoloModel.tag,
                requiredByteCount,
                input.count
            )
            return
        }

        input.withUnsafeMutableBytes { rawOutputBuffer in
            let outputBuffer = rawOutputBuffer.bindMemory(
                to: UInt8.self
            )

            guard outputBuffer.count >= pixelCount * channelCount else {
                NSLog(
                    "[%@]: :x: UInt8 output buffer is too small.",
                    HybridYoloModel.tag
                )
                return
            }

            var outputIndex = 0

            for dy in 0..<dstHeight {
                for dx in 0..<dstWidth {
                    let mappedPixel = mapModelPixelToFramePixel(
                        dx: dx,
                        dy: dy,
                        dstWidth: dstWidth,
                        dstHeight: dstHeight,
                        srcWidth: safeSrcWidth,
                        srcHeight: safeSrcHeight,
                        orientation: frame.orientation
                    )

                    let srcX = clampInt(
                        mappedPixel.x,
                        0,
                        safeSrcWidth - 1
                    )

                    let srcY = clampInt(
                        mappedPixel.y,
                        0,
                        safeSrcHeight - 1
                    )

                    let yIndex =
                        srcY * yRowStride +
                        srcX

                    let uvY = srcY / 2
                    let uvX = srcX / 2

                    let uvIndex =
                        uvY * uvRowStride +
                        uvX * 2

                    let yValue = Float(yPtr[yIndex])
                    let uValue = Float(Int(uvPtr[uvIndex]) - 128)
                    let vValue = Float(Int(uvPtr[uvIndex + 1]) - 128)

                    let red = min(
                        max(
                            yValue + 1.402 * vValue,
                            0.0
                        ),
                        255.0
                    )

                    let green = min(
                        max(
                            yValue
                                - 0.344136 * uValue
                                - 0.714136 * vValue,
                            0.0
                        ),
                        255.0
                    )

                    let blue = min(
                        max(
                            yValue + 1.772 * uValue,
                            0.0
                        ),
                        255.0
                    )

                    outputBuffer[outputIndex] = UInt8(red.rounded())
                    outputBuffer[outputIndex + 1] = UInt8(green.rounded())
                    outputBuffer[outputIndex + 2] = UInt8(blue.rounded())

                    outputIndex += 3
                }
            }
        }

    default:
        NSLog(
            "[%@]: :x: Unsupported input tensor type: %@",
            HybridYoloModel.tag,
            "\(dataType)"
        )
        return
    }
}
    
    private func mapModelPixelToFramePixel(
        dx: Int, dy: Int,
        dstWidth: Int, dstHeight: Int,
        srcWidth: Int, srcHeight: Int,
        orientation: CameraOrientation
    ) -> (x: Int, y: Int) {
        let nx = Float(dx) / Float(dstWidth)
        let ny = Float(dy) / Float(dstHeight)
        
        switch orientation {
        case .up:
            let sx = Int(nx * Float(srcWidth))
            let sy = Int(ny * Float(srcHeight))
            return (clampInt(sx, 0, srcWidth - 1), clampInt(sy, 0, srcHeight - 1))
        case .down:
            let sx = Int((1.0 - nx) * Float(srcWidth))
            let sy = Int((1.0 - ny) * Float(srcHeight))
            return (clampInt(sx, 0, srcWidth - 1), clampInt(sy, 0, srcHeight - 1))
        case .left:
            let sx = Int(ny * Float(srcWidth))
            let sy = Int((1.0 - nx) * Float(srcHeight))
            return (clampInt(sx, 0, srcWidth - 1), clampInt(sy, 0, srcHeight - 1))
        case .right:
            let sx = Int((1.0 - ny) * Float(srcWidth))
            let sy = Int(nx * Float(srcHeight))
            return (clampInt(sx, 0, srcWidth - 1), clampInt(sy, 0, srcHeight - 1))
        @unknown default:
            return (0, 0)
        }
    }

    private func clampInt(_ value: Int, _ minValue: Int, _ maxValue: Int) -> Int {
        return min(max(value, minValue), maxValue)
    }
}


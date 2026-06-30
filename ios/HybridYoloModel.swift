import Foundation
import NitroModules
import TensorFlowLite
import VisionCamera
import CoreVideo

public class HybridYoloModel: HybridYoloModelSpec {
    private static let tag = "YOLO_MODEL_TAG"
    
    private let modelLoader = YoloModelLoader()
    
    private var interpreter: Interpreter? = nil
    private var inputBuffer: Data? = nil
    private var inputWidth = 0
    private var inputHeight = 0
    private var inputDataType: Tensor.DataType? = nil
    
    private let threadLock = NSLock()
    
    public required override init(modelPath: String) throws {
        super.init()
        try load(modelPath: modelPath)
    }
    
    private func load(modelPath: String) throws {
        do {
            let modelData = try modelLoader.load(modelPath: modelPath)
            
            // Initialisation de l'interpréteur TensorFlowLiteSwift
            interpreter = try Interpreter(modelData: modelData)
            guard let localInterpreter = interpreter else { return }
            
            try localInterpreter.allocateTensors()
            
            let inputTensor = try localInterpreter.inputTensor(at: 0)
            let outputTensor = try localInterpreter.outputTensor(at: 0)
            
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
        
        guard var input = inputBuffer else { return [] }
        
        threadLock.lock()
        defer { threadLock.unlock() }
        
        // Remplissage du buffer d'entrée en analysant les données NV12
        try fillInputFromYuvFrame(
            frame: frame,
            input: &input,
            dstWidth: inputWidth,
            dstHeight: inputHeight,
            dataType: inputDataType ?? .float32
        )
        
        // Injection du tampon de données brut dans le tenseur d'entrée
        try localInterpreter.copy(input, toInputAt: 0)
        try localInterpreter.invoke()
        
        // Récupération des résultats du tenseur de sortie
        let outputTensor = try localInterpreter.outputTensor(at: 0)
        
        // Extraction et conversion de la structure des tenseurs [1, 300, 6] en Float
        let nativeOutputs = outputTensor.data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [Float] in
            let floatPtr = ptr.assumingMemoryBound(to: Float.self)
            return Array(floatPtr)
        }
        
        return parseNmsOutput(outputArray: nativeOutputs, confidenceThreshold: 0.5)
    }
    
    public func close() throws {
        interpreter = nil
        inputBuffer = nil
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
                    boundingBox: box,
                    score: Double(score),
                    classId: Double(outputArray[offset + 5])
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
        
        // Extraction du CVPixelBuffer matériel pour un accès direct ultra-rapide
        let nativeBuffer = try frame.getNativeBuffer()
        guard let rawPointer = nativeBuffer.pointer else { return }
        let pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(rawPointer).takeUnretainedValue()
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let yBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
              let uvBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else { return }
        
        let yRowStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let uvRowStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
        
        let yPtr = yBaseAddress.assumingMemoryBound(to: UInt8.self)
        let uvPtr = uvBaseAddress.assumingMemoryBound(to: UInt8.self)
        
        // Allocation du flux d'écriture en octets
        var bytes: [UInt8] = []
        bytes.reserveCapacity(input.count)
        
        for dy in 0..<dstHeight {
            for dx in 0..<dstWidth {
                let (srcX, srcY) = mapModelPixelToFramePixel(
                    dx: dx, dy: dy,
                    dstWidth: dstWidth, dstHeight: dstHeight,
                    srcWidth: srcWidth, srcHeight: srcHeight,
                    orientation: frame.orientation
                )
                
                let yIndex = srcY * yRowStride + srcX
                
                // NV12 : Les composants U et V sont regroupés au même endroit (U, V, U, V)
                // L'indice de ligne utilise uvRowStride. Chaque pixel partagé saute de 2 en 2 horizontalement.
                let uvY = srcY / 2
                let uvX = srcX / 2
                let uvIndex = uvY * uvRowStride + uvX * 2
                
                let y = Int(yPtr[yIndex])
                let u = Int(uvPtr[uvIndex])     // Dans NV12, U se trouve au premier octet
                let v = Int(uvPtr[uvIndex + 1]) // V se trouve juste à côté
                
                // Formule standard de conversion YUV en RGB
                let rFloat = Float(y) + 1.402 * Float(v - 128)
                let gFloat = Float(y) - 0.344136 * Float(u - 128) - 0.714136 * Float(v - 128)
                let bFloat = Float(y) + 1.772 * Float(u - 128)
                
                let r = Int(rFloat.rounded()).clamped(to: 0...255)
                let g = Int(gFloat.rounded()).clamped(to: 0...255)
                let b = Int(bFloat.rounded()).clamped(to: 0...255)
                
                if dataType == .float32 {
                    let rNorm = Float(r) / 255.0
                    let gNorm = Float(g) / 255.0
                    let bNorm = Float(b) / 255.0
                    
                    withUnsafeBytes(of: rNorm) { bytes.append(contentsOf: $0) }
                    withUnsafeBytes(of: gNorm) { bytes.append(contentsOf: $0) }
                    withUnsafeBytes(of: bNorm) { bytes.append(contentsOf: $0) }
                } else {
                    bytes.append(UInt8(r))
                    bytes.append(UInt8(g))
                    bytes.append(UInt8(b))
                }
            }
        }
        
        // Copie globale du flux binaire structuré dans l'espace mémoire d'entrée
        input.withUnsafeMutableBytes { dstPtr in
            bytes.withUnsafeBytes { srcPtr in
                dstPtr.copyBytes(from: srcPtr)
            }
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
            return (sx.clamped(to: 0...(srcWidth - 1)), sy.clamped(to: 0...(srcHeight - 1)))
        case .down:
            let sx = Int((1.0 - nx) * Float(srcWidth))
            let sy = Int((1.0 - ny) * Float(srcHeight))
            return (sx.clamped(to: 0...(srcWidth - 1)), sy.clamped(to: 0...(srcHeight - 1)))
        case .left:
            let sx = Int(ny * Float(srcWidth))
            let sy = Int((1.0 - nx) * Float(srcHeight))
            return (sx.clamped(to: 0...(srcWidth - 1)), sy.clamped(to: 0...(srcHeight - 1)))
        case .right:
            let sx = Int((1.0 - ny) * Float(srcWidth))
            let sy = Int(nx * Float(srcHeight))
            return (sx.clamped(to: 0...(srcWidth - 1)), sy.clamped(to: 0...(srcHeight - 1)))
        @unknown default:
            return (0, 0)
        }
    }
}


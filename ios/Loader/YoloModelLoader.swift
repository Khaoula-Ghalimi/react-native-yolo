import Foundation
import NitroModules
import TensorFlowLite // Activé via votre s.dependency 'TensorFlowLiteSwift'

public class YoloModelLoader {
    private static let tag = "YOLO_TAG_LOADER"
    
    public init() {}
    
    /**
     * Charge un modèle YOLO à partir du chemin spécifié (URL, URI de fichier, chemin absolu, ou ressource brute).
     * Retourne un objet `Data` contenant les octets du modèle configurés via mmap (équivalent du MappedByteBuffer).
     */
    public func load(modelPath: String) throws -> Data {
        if modelPath.hasPrefix("http://") || modelPath.hasPrefix("https://") {
            NSLog("[%@]: Loading model from URL", YoloModelLoader.tag)
            let cachedFileURL = try downloadToCache(urlString: modelPath)
            return try mapFile(fileURL: cachedFileURL)
            
        } else if modelPath.hasPrefix("file://") {
            NSLog("[%@]: Loading model from file URI", YoloModelLoader.tag)
            guard let url = URL(string: modelPath) else {
                throw NSError(domain: "YoloModelLoader", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid file URI"])
            }
            return try mapFile(fileURL: url)
            
        } else if modelPath.hasPrefix("/") {
            NSLog("[%@]: Loading model from absolute path", YoloModelLoader.tag)
            let url = URL(fileURLWithPath: modelPath)
            return try mapFile(fileURL: url)
            
        } else if modelPath.hasPrefix("assets_") {
            NSLog("[%@]: Loading model from RN raw resource", YoloModelLoader.tag)
            let cachedFileURL = try copyRawResourceToCache(resourceName: modelPath)
            return try mapFile(fileURL: cachedFileURL)
            
        } else {
            NSLog("[%@]: Loading model from Main App Bundle Assets", YoloModelLoader.tag)
            let cleanName = modelPath.replacingOccurrences(of: ".tflite", with: "")
            guard let bundleURL = ContextProvider.mainBundle.url(forResource: cleanName, withExtension: "tflite") else {
                throw NSError(domain: "YoloModelLoader", code: 404, userInfo: [NSLocalizedDescriptionKey: "Model not found in main bundle: \(modelPath)"])
            }
            return try mapFile(fileURL: bundleURL)
        }
    }
    
    private func copyRawResourceToCache(resourceName: String) throws -> URL {
        guard let bundleURL = ContextProvider.mainBundle.url(forResource: resourceName, withExtension: "tflite") else {
            throw NSError(domain: "YoloModelLoader", code: 404, userInfo: [NSLocalizedDescriptionKey: "Raw resource not found: \(resourceName)"])
        }
        
        let destinationURL = ContextProvider.cacheDirectory.appendingPathComponent("\(resourceName).tflite")
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        try FileManager.default.copyItem(at: bundleURL, to: destinationURL)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        NSLog("[%@]: Copied raw resource to: %@", YoloModelLoader.tag, destinationURL.path)
        NSLog("[%@]: Copied raw resource size: %lld bytes", YoloModelLoader.tag, fileSize)
        
        return destinationURL
    }
    
    private func mapFile(fileURL: URL) throws -> Data {
        let path = fileURL.path
        if !FileManager.default.fileExists(atPath: path) {
            throw NSError(domain: "YoloModelLoader", code: 404, userInfo: [NSLocalizedDescriptionKey: "Model file does not exist: \(path)"])
        }
        
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        if fileSize <= 0 {
            throw NSError(domain: "YoloModelLoader", code: 400, userInfo: [NSLocalizedDescriptionKey: "Model file is empty: \(path)"])
        }
        
        // .alwaysMapped utilise mmap au niveau du noyau iOS pour des performances instantanées (Zero CPU copy)
        return try Data(contentsOf: fileURL, options: .alwaysMapped)
    }
    
    private func downloadToCache(urlString: String) throws -> URL {
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "YoloModelLoader", code: 400, userInfo: [NSLocalizedDescriptionKey: "Malformed URL"])
        }
        
        let destinationURL = ContextProvider.cacheDirectory.appendingPathComponent("yolo_model.tflite")
        let modelData = try Data(contentsOf: url)
        try modelData.write(to: destinationURL, options: .atomic)
        
        NSLog("[%@]: Downloaded model to: %@", YoloModelLoader.tag, destinationURL.path)
        NSLog("[%@]: Downloaded model size: %d bytes", YoloModelLoader.tag, modelData.count)
        
        return destinationURL
    }
    
    /**
     * Alloue un tampon d'entrée brut ('Data') calibré sur les dimensions du tenseur d'entrée du modèle.
     * Remplace parfaitement Direct ByteBuffer de Java.
     */
    public func makeInputBuffer(interpreter: Interpreter) throws -> Data {
        // Récupérer le premier tenseur d'entrée du modèle TFLite
        let inputTensor = try interpreter.input(at: 0)
        let shape = inputTensor.shape.dimensions // Généralement: [1, 640, 640, 3]
        let dataType = inputTensor.dataType
        
        let batch = shape[0]
        let height = shape[1]
        let width = shape[2]
        let channels = shape[3]
        
        // Vérifications strictes (équivalents de require() en Kotlin)
        guard batch == 1 else {
            fatalError("YOLO Input Violation: Batch size must be 1")
        }
        guard channels == 3 else {
            fatalError("YOLO Input Violation: Channels count must be 3 (RGB)")
        }
        
        let bytesPerValue: Int
        switch dataType {
        case .float32:
            bytesPerValue = 4
        case .uInt8:
            bytesPerValue = 1
        default:
            fatalError("Unsupported input type: \(dataType)")
        }
        
        let totalBytes = batch * width * height * channels * bytesPerValue
        
        // Crée une structure Data Swift vide avec l'empreinte mémoire exacte
        return Data(repeating: 0, count: totalBytes)
    }
}

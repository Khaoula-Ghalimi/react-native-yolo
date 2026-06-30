import Foundation
import NitroModules
import VisionCamera

public class HybridYolo: HybridYoloSpec {
    private static let tag = "YOLO_TAG"
    
    // Initialisateur obligatoire pour les modules Nitro
    public required init() {
        super.init()
    }
    
    /**
     * Charge l'objet modèle YOLO spécifié par son chemin.
     * Implémente la méthode obligatoire du protocole Nitro TypeScript.
     */
    public override func loadModel(modelPath: String) throws -> any HybridYoloModelSpec {
        NSLog("[%@]: Trying to load model object: %@", HybridYolo.tag, modelPath)
        
        // Initialise et retourne votre sous-classe de modèle Nitro (assurez-vous qu'elle s'appelle bien HybridYoloModel)
        return try HybridYoloModel(modelPath: modelPath)
    }
    
    /**
     * Valide un Frame de la caméra, le convertit en JPEG permanent (NV12 -> JPEG -> Fix Rotation),
     * puis l'encode instantanément en chaîne de caractères Base64 standard.
     */
    public override func frameToBase64(frame: any HybridFrameSpec) throws -> String {
        NSLog("[%@]: Trying to convert frame to base64", HybridYolo.tag)
        
        do {
            // 1. Validation du buffer vidéo via notre validateur adapté à iOS (NV12 à 2 plans minimum)
            guard FrameValidator.isValidYuv(frame: frame) else {
                return ""
            }
            NSLog("[%@]: frameToBase64: frame is valid YUV", HybridYolo.tag)
            
            // 2. Traitement complet de l'image (Conversion NV12 -> Encodage GPU JPEG -> Rendu de sécurité)
            let jpegBytes = FrameJpegConverter.toJpegBytes(frame: frame, quality: 80)
            
            guard !jpegBytes.isEmpty else {
                NSLog("[%@]: ❌ frameToBase64 failed: converted JPEG bytes array is empty", HybridYolo.tag)
                return ""
            }
            NSLog("[%@]: frameToBase64: jpegBytes size: %d bytes", HybridYolo.tag, jpegBytes.count)
            
            // 3. Encapsulation dans un conteneur Data pour un encodage Base64 matériel (sans sauts de ligne, équivalent de NO_WRAP)
            let data = Data(jpegBytes)
            return data.base64EncodedString(options: [])
            
        } catch {
            NSLog("[%@]: ❌ frameToBase64 failed: %@", HybridYolo.tag, error.localizedDescription)
            return ""
        }
    }
}

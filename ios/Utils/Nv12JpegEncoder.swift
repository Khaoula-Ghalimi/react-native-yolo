import Foundation
import CoreImage
import UIKit

public enum Nv12JpegEncoder {
    // Réutiliser le CIContext permet d'éviter des fuites de mémoire massives à chaque frame
    private static let ciContext = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
    
    public static func encode(
        nv12: [UInt8],
        width: Int,
        height: Int,
        quality: Int
    ) -> [UInt8] {
        
        // 1. Convertir la qualité (0-100 sur Android) en CGFloat (0.0-1.0 sur iOS)
        let compressionQuality = CGFloat(max(0, min(quality, 100))) / 100.0
        
        let ySize = width * height
        let uvSize = ySize / 2
        
        // Sécurité : s'assurer que la taille du tableau correspond bien aux dimensions fournies
        guard nv12.count >= (ySize + uvSize) else { return [] }
        
        // 2. Transformer le tableau d'octets [UInt8] en objet Data Swift
        let rawData = Data(bytes: nv12, count: ySize + uvSize)
        
        // 3. Spécifier le format de couleur NV12 pour CoreImage (kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        let imageOptions: [CIImageOption: Any] = [
            .colorSpace: CGColorSpaceCreateDeviceRGB()
        ]
        
        // On indique à CoreImage la structure exacte du NV12 (Plan 0: Y, Plan 1: UV entrelacé)
        guard let ciImage = CIImage(
            imageWithFormat: Int32(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
            size: CGSize(width: width, height: height),
            data: rawData,
            rowBytes: width,
            options: imageOptions
        ) else {
            return []
        }
        
        // 4. Rendu de l'image GPU vers une structure d'image CoreGraphics
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return []
        }
        
        // 5. Conversion en UIImage puis compression matérielle en JPEG
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: compressionQuality) else {
            return []
        }
        
        // 6. Retourner le tableau d'octets natif [UInt8] requis par votre modèle
        return [UInt8](jpegData)
    }
}

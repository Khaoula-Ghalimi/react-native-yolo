import Foundation
import NitroModules
import VisionCamera

public enum FrameValidator {
    private static let tag = "YOLO_TAG_FrameValidator"
    
    public static func isValidYuv(frame: any HybridFrameSpec) -> Bool {
        // 1. Vérification de la validité globale du Frame
        if !frame.isValid {
            NSLog("[%@]: ❌ Frame is not valid", tag)
            return false
        }
        
        do {
            let planes = try frame.getPlanes()
            
            // 2. Sur iOS, le format matériel natif NV12 contient exactement 2 plans.
            // On s'assure d'avoir au moins ces 2 plans requis.
            if planes.count < 2 {
                NSLog("[%@]: ❌ Expected at least 2 YUV planes (NV12), got %d", tag, planes.count)
                return false
            }
            
            // 3. Parcours et validation de chaque plan individuel
            for (index, plane) in planes.enumerated() {
                if !plane.isValid {
                    NSLog("[%@]: ❌ Plane %d is not valid", tag, index)
                    return false
                }
            }
            
            return true
            
        } catch {
            NSLog("[%@]: ❌ Failed to retrieve planes from frame: %@", tag, error.localizedDescription)
            return false
        }
    }
}

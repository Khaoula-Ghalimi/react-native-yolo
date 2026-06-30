import Foundation
import UIKit
import NitroModules

/**
 * Provides a way to access application-wide singletons and paths from anywhere in the app.
 * This acts as the iOS equivalent to the Android ContextProvider.
 */
public enum ContextProvider {
    
    /// Returns the main application instance (equivalent to Application instance)
    public static var sharedApplication: UIApplication {
        // Must be accessed on the main thread
        if Thread.isMainThread {
            return UIApplication.shared
        } else {
            var app: UIApplication!
            DispatchQueue.main.sync {
                app = UIApplication.shared
            }
            return app
        }
    }
    
    /// Returns the main bundle containing application assets (equivalent to context.resources)
    public static var mainBundle: Bundle {
        return Bundle.main
    }
    
    /// Returns the application cache directory URL (equivalent to context.cacheDir)
    public static var cacheDirectory: URL {
        guard let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            fatalError("iOS Cache Directory is null or inaccessible")
        }
        return url
    }
    
    /// Returns the application document directory URL (equivalent to context.filesDir)
    public static var documentsDirectory: URL {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("iOS Documents Directory is null or inaccessible")
        }
        return url
    }
}

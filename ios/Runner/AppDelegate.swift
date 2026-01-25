import Flutter
import UIKit
import FirebaseCore
import GoogleSignIn

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase is initialized in Dart (main.dart) before runApp
    // No need to initialize here since FirebaseAppDelegateProxyEnabled is false
    
    // Configure Google Sign-In
    // Try to get CLIENT_ID from GoogleService-Info.plist first
    var clientID: String? = nil
    
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let plist = NSDictionary(contentsOfFile: path),
       let plistClientID = plist["CLIENT_ID"] as? String {
      clientID = plistClientID
      print("[AppDelegate] Found CLIENT_ID in GoogleService-Info.plist")
    } else {
      // Fallback: Try to get from Firebase (may not be initialized yet)
      if let firebaseClientID = FirebaseApp.app()?.options.clientID {
        clientID = firebaseClientID
        print("[AppDelegate] Using CLIENT_ID from Firebase options")
      } else {
        print("[AppDelegate] WARNING: CLIENT_ID not found. Google Sign-In may not work.")
        print("[AppDelegate] Please re-download GoogleService-Info.plist from Firebase Console after enabling Google Sign-In.")
      }
    }
    
    if let clientID = clientID {
      let config = GIDConfiguration(clientID: clientID)
      GIDSignIn.sharedInstance.configuration = config
      print("[AppDelegate] Google Sign-In configured with CLIENT_ID")
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle Google Sign-In URL callback
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}

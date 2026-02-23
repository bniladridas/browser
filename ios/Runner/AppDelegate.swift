import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let handled = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if window == nil {
      let windowScene = application.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first {
          $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive
        } ?? application.connectedScenes.compactMap { $0 as? UIWindowScene }.first
      if let windowScene {
        window = UIWindow(windowScene: windowScene)
      }
    }
    window?.makeKeyAndVisible()
    return handled
  }
}

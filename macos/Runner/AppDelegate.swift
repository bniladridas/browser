import Cocoa
import FlutterMacOS
import ObjectiveC.runtime
import WebKit

private enum WKWebViewFullscreenBootstrap {
  static func enable() {
    guard #available(macOS 12.3, *) else { return }
    _ = swizzleConfigurationInit
  }

  private static let swizzleConfigurationInit: Void = {
    let cls: AnyClass = WKWebViewConfiguration.self
    let originalSelector = NSSelectorFromString("init")
    let swizzledSelector = #selector(WKWebViewConfiguration.browser_fullscreen_init)

    guard
      let originalMethod = class_getInstanceMethod(cls, originalSelector),
      let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector)
    else {
      assertionFailure("Failed to enable WKWebView fullscreen support.")
      return
    }

    method_exchangeImplementations(originalMethod, swizzledMethod)
  }()
}

extension WKWebViewConfiguration {
  @objc fileprivate func browser_fullscreen_init() -> WKWebViewConfiguration {
    let configuration = browser_fullscreen_init()
    if #available(macOS 12.3, *) {
      configuration.preferences.isElementFullscreenEnabled = true
    }
    return configuration
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    WKWebViewFullscreenBootstrap.enable()
    super.applicationDidFinishLaunching(notification)

    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    NSApp.mainWindow?.makeKeyAndOrderFront(nil)
    NSApp.windows.first?.makeKeyAndOrderFront(nil)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

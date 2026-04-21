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

final class BrowserMenuBarController: NSObject {
  static let shared = BrowserMenuBarController()

  private var statusItem: NSStatusItem?
  private var creationAttempts = 0

  func install(reason: String) {
    creationAttempts += 1
    if let existingItem = statusItem,
       let button = existingItem.button,
       button.window != nil {
      existingItem.isVisible = true
      return
    }
    if let existingItem = statusItem {
      NSStatusBar.system.removeStatusItem(existingItem)
      statusItem = nil
    }

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem = item
    item.isVisible = true

    if let button = item.button {
      button.image = makeStatusItemImage()
      button.imagePosition = .imageOnly
      button.title = ""
      button.toolTip = "Browser"
      button.target = self
      button.action = #selector(handleStatusItemButtonPress(_:))
      button.sizeToFit()
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    let menu = NSMenu()
    menu.addItem(
      withTitle: "Show browser",
      action: #selector(showMainWindow(_:)),
      keyEquivalent: ""
    )
    menu.addItem(
      withTitle: "Hide browser",
      action: #selector(hideMainWindow(_:)),
      keyEquivalent: ""
    )
    menu.addItem(NSMenuItem.separator())
    menu.addItem(
      withTitle: "Quit",
      action: #selector(quitApplication(_:)),
      keyEquivalent: "q"
    )
    menu.items.forEach { $0.target = self }
    item.menu = menu
  }

  private func makeStatusItemImage() -> NSImage? {
    guard let image = NSApp.applicationIconImage.copy() as? NSImage else {
      return nil
    }
    image.isTemplate = false
    image.size = NSSize(width: 18, height: 18)
    return image
  }

  private func mainFlutterWindow() -> NSWindow? {
    if let window = NSApp.windows.first(where: { $0 is MainFlutterWindow }) {
      return window
    }
    return NSApp.mainWindow ?? NSApp.windows.first
  }

  @objc func showMainWindow(_ sender: Any?) {
    guard let window = mainFlutterWindow() else { return }
    if window.isMiniaturized {
      window.deminiaturize(nil)
    }
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  @objc func hideMainWindow(_ sender: Any?) {
    mainFlutterWindow()?.orderOut(nil)
  }

  @objc func quitApplication(_ sender: Any?) {
    NSApp.terminate(nil)
  }

  @objc private func handleStatusItemButtonPress(_ sender: Any?) {
    if let event = NSApp.currentEvent, event.type == .rightMouseUp {
      statusItem?.button?.performClick(nil)
      return
    }
    if let window = mainFlutterWindow(), window.isVisible {
      hideMainWindow(nil)
    } else {
      showMainWindow(nil)
    }
  }
}

@main
class AppDelegate: FlutterAppDelegate {

  override func applicationDidFinishLaunching(_ notification: Notification) {
    WKWebViewFullscreenBootstrap.enable()
    super.applicationDidFinishLaunching(notification)

    NSApp.setActivationPolicy(.regular)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleApplicationDidBecomeActive),
      name: NSApplication.didBecomeActiveNotification,
      object: nil
    )
    scheduleStatusItemSetup()
    BrowserMenuBarController.shared.showMainWindow(nil)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      BrowserMenuBarController.shared.showMainWindow(nil)
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  private func scheduleStatusItemSetup() {
    DispatchQueue.main.async { [weak self] in
      self?.ensureStatusItemVisible(reason: "initial async")
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
      self?.ensureStatusItemVisible(reason: "launch retry")
    }
  }

  @objc private func handleApplicationDidBecomeActive() {
    ensureStatusItemVisible(reason: "app became active")
  }

  private func ensureStatusItemVisible(reason: String) {
    BrowserMenuBarController.shared.install(reason: reason)
  }
}

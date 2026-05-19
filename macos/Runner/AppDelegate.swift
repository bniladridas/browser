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
  private var windowVisibilityItem: NSMenuItem?
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
    menu.delegate = self
    let appInfoItem = NSMenuItem(
      title: "Browser",
      action: nil,
      keyEquivalent: ""
    )
    appInfoItem.isEnabled = false
    menu.addItem(appInfoItem)
    let versionItem = NSMenuItem(
      title: appVersionLabel(),
      action: nil,
      keyEquivalent: ""
    )
    versionItem.isEnabled = false
    menu.addItem(versionItem)
    menu.addItem(NSMenuItem.separator())
    deviceInfoLabels().forEach { label in
      let item = NSMenuItem(
        title: label,
        action: nil,
        keyEquivalent: ""
      )
      item.isEnabled = false
      menu.addItem(item)
    }
    menu.addItem(NSMenuItem.separator())
    let visibilityItem = NSMenuItem(
      title: windowVisibilityTitle(),
      action: #selector(toggleMainWindow(_:)),
      keyEquivalent: ""
    )
    visibilityItem.target = self
    windowVisibilityItem = visibilityItem
    menu.addItem(visibilityItem)
    menu.addItem(NSMenuItem.separator())
    menu.addItem(
      withTitle: "Quit",
      action: #selector(quitApplication(_:)),
      keyEquivalent: "q"
    )
    menu.items.forEach { $0.target = self }
    item.menu = menu
  }

  private func appVersionLabel() -> String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String
    let build = info?["CFBundleVersion"] as? String

    switch (version?.isEmpty == false ? version : nil, build?.isEmpty == false ? build : nil) {
    case let (.some(version), .some(build)):
      return "Version \(version) (\(build))"
    case let (.some(version), nil):
      return "Version \(version)"
    default:
      return "Version unavailable"
    }
  }

  private func isMainWindowVisible() -> Bool {
    guard let window = mainFlutterWindow() else { return false }
    return window.isVisible && !window.isMiniaturized
  }

  private func windowVisibilityTitle() -> String {
    isMainWindowVisible() ? "Hide" : "Show"
  }

  private func deviceInfoLabels() -> [String] {
    var labels = ["Mac"]
    if let chip = chipName() {
      labels.append("Chip \(chip)")
    }
    labels.append(memoryLabel())
    labels.append(macOSVersionLabel())
    return labels
  }

  private func chipName() -> String? {
    var size = 0
    guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0,
          size > 0
    else {
      return nil
    }

    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0
    else {
      return nil
    }

    let value = String(cString: buffer)
      .replacingOccurrences(of: "Apple ", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }

  private func memoryLabel() -> String {
    let bytes = ProcessInfo.processInfo.physicalMemory
    let gib = Double(bytes) / 1_073_741_824
    return "Memory \(Int(gib.rounded())) GB"
  }

  private func macOSVersionLabel() -> String {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    let releaseName = macOSReleaseName(for: version.majorVersion)
    var label = releaseName.map { "macOS \($0) " } ?? "macOS "
    label += "\(version.majorVersion).\(version.minorVersion)"
    if version.patchVersion > 0 {
      label += ".\(version.patchVersion)"
    }
    if let build = osBuildVersion() {
      label += " (\(build))"
    }
    return label
  }

  private func osBuildVersion() -> String? {
    var size = 0
    guard sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0,
          size > 0
    else {
      return nil
    }

    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname("kern.osversion", &buffer, &size, nil, 0) == 0
    else {
      return nil
    }

    let value = String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }

  private func macOSReleaseName(for majorVersion: Int) -> String? {
    switch majorVersion {
    case 26:
      return "Tahoe"
    case 15:
      return "Sequoia"
    case 14:
      return "Sonoma"
    case 13:
      return "Ventura"
    case 12:
      return "Monterey"
    case 11:
      return "Big Sur"
    default:
      return nil
    }
  }

  private func makeStatusItemImage() -> NSImage? {
    let image = NSImage(named: "MenuBarIcon")
    image?.isTemplate = true
    image?.size = NSSize(width: 18, height: 18)
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

  @objc func toggleMainWindow(_ sender: Any?) {
    if isMainWindowVisible() {
      hideMainWindow(sender)
    } else {
      showMainWindow(sender)
    }
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

extension BrowserMenuBarController: NSMenuDelegate {
  func menuWillOpen(_ menu: NSMenu) {
    windowVisibilityItem?.title = windowVisibilityTitle()
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

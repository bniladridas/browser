import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    BrowserMenuBarController.shared.install(reason: "window awakeFromNib")
    delegate = self

    let isIntegrationTest = ProcessInfo.processInfo.environment["INTEGRATION_TEST"] == "true"
    guard !isIntegrationTest else {
      self.alphaValue = 1
      return
    }

    standardWindowButton(.closeButton)?.isHidden = true
    standardWindowButton(.miniaturizeButton)?.isHidden = true
    standardWindowButton(.zoomButton)?.isHidden = true

    let splashSize = NSSize(width: 640, height: 360)
    if let screenFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
      let splashOrigin = NSPoint(
        x: screenFrame.midX - splashSize.width / 2,
        y: screenFrame.midY - splashSize.height / 2
      )
      setFrame(NSRect(origin: splashOrigin, size: splashSize), display: false)
    } else {
      setContentSize(splashSize)
    }

    minSize = splashSize
    self.alphaValue = 0
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
      guard let self, self.alphaValue == 0 else {
        return
      }
      self.alphaValue = 1
      self.makeKeyAndOrderFront(nil)
    }
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    orderOut(nil)
    return false
  }
}

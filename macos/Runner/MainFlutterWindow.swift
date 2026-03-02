import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // Hide window initially
    self.alphaValue = 0

    // Show after Flutter initializes
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      NSAnimationContext.runAnimationGroup({ context in
        context.duration = 0.2
        self.animator().alphaValue = 1.0
      }, completionHandler: nil)
    }
  }
}

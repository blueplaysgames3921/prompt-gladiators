import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame

    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Set minimum window size — arena UI needs at least 800x600
    self.minSize = NSSize(width: 800, height: 600)

    // Default size: wide enough for the split branding+menu layout
    if windowFrame.size.width < 1280 {
      let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
      let newSize = NSSize(width: min(1280, screen.width), height: min(800, screen.height))
      let origin = CGPoint(
        x: screen.origin.x + (screen.width - newSize.width) / 2,
        y: screen.origin.y + (screen.height - newSize.height) / 2
      )
      self.setFrame(CGRect(origin: origin, size: newSize), display: true)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()
  }
}

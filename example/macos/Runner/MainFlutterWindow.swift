import Cocoa
import FlutterMacOS

/// Canonical method-channel name for forwarding workbench brightness
/// to the host window runner. Matches the Dart-side `MethodChannel`
/// declared in `lib/main.dart` (SPEC §spec:platform-brightness-sync).
private let kWindowChromeChannel = "workbench_shell/window_chrome"

class MainFlutterWindow: NSWindow {
  private var windowChromeChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Receive brightness updates from `WorkbenchThemeController` and
    // align the window's title bar via `NSWindow.appearance`. The
    // channel is unidirectional Dart→host; the receiver replies
    // `nil` on success and `FlutterError` on bad payloads so the
    // host shows up in app logs when wired wrong.
    let channel = FlutterMethodChannel(
      name: kWindowChromeChannel,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "setBrightness":
        guard let payload = call.arguments as? String else {
          result(
            FlutterError(
              code: "invalid-argument",
              message: "setBrightness expects a String payload",
              details: nil
            )
          )
          return
        }
        self.applyBrightness(payload)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.windowChromeChannel = channel

    super.awakeFromNib()
  }

  private func applyBrightness(_ payload: String) {
    let appearance: NSAppearance?
    switch payload {
    case "dark":
      appearance = NSAppearance(named: .darkAqua)
    case "light":
      appearance = NSAppearance(named: .aqua)
    default:
      // Unknown brightness — leave the appearance alone rather than
      // forcing a default. The Dart side validates payloads, so this
      // path only fires for protocol drift.
      return
    }
    self.appearance = appearance
  }
}

#include "flutter_window.h"

#include <dwmapi.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Canonical method-channel name for forwarding workbench brightness
// to the host window runner. Matches the Dart-side declaration in
// `lib/main.dart` (SPEC §spec:platform-brightness-sync).
constexpr const char* kWindowChromeChannel = "workbench_shell/window_chrome";

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Wire the canonical workbench_shell/window_chrome method channel.
  // The handler is unidirectional Dart→host: the only method is
  // `setBrightness("light"|"dark")` and the result reply is `nil` on
  // success or a FlutterError for bad payloads.
  window_chrome_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kWindowChromeChannel,
          &flutter::StandardMethodCodec::GetInstance());
  window_chrome_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "setBrightness") {
          result->NotImplemented();
          return;
        }
        const auto* payload = std::get_if<std::string>(call.arguments());
        if (payload == nullptr) {
          result->Error("invalid-argument",
                        "setBrightness expects a String payload");
          return;
        }
        this->ApplyBrightness(*payload);
        result->Success();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  // Tear down the channel before the engine — `MethodChannel` borrows
  // the engine's messenger.
  window_chrome_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::ApplyBrightness(const std::string& payload) {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }
  BOOL enable_dark_mode;
  if (payload == "dark") {
    enable_dark_mode = TRUE;
  } else if (payload == "light") {
    enable_dark_mode = FALSE;
  } else {
    // Unknown payload — leave the title bar alone. The Dart side
    // validates payloads, so this only fires under protocol drift.
    return;
  }
  DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE,
                        &enable_dark_mode, sizeof(enable_dark_mode));
}

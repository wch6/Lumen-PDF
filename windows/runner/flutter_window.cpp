#include "flutter_window.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
#endif

#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif

#ifndef DWMWA_TEXT_COLOR
#define DWMWA_TEXT_COLOR 36
#endif

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

void ApplyTitleBarTheme(HWND window, bool dark) {
  if (!window) {
    return;
  }

  DWORD corner_preference = 2;
  DwmSetWindowAttribute(window, DWMWA_WINDOW_CORNER_PREFERENCE,
                        &corner_preference, sizeof(corner_preference));

  BOOL enable_dark_mode = dark ? TRUE : FALSE;
  DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                        &enable_dark_mode, sizeof(enable_dark_mode));

  COLORREF caption_color =
      dark ? RGB(32, 29, 31) : RGB(255, 252, 249);
  COLORREF text_color =
      dark ? RGB(243, 236, 232) : RGB(33, 29, 32);
  COLORREF border_color =
      dark ? RGB(55, 48, 51) : RGB(229, 220, 214);

  DwmSetWindowAttribute(window, DWMWA_CAPTION_COLOR, &caption_color,
                        sizeof(caption_color));
  DwmSetWindowAttribute(window, DWMWA_TEXT_COLOR, &text_color,
                        sizeof(text_color));
  DwmSetWindowAttribute(window, DWMWA_BORDER_COLOR, &border_color,
                        sizeof(border_color));
}

int ResizeHitTestFromEdge(const std::string& edge) {
  if (edge == "left") {
    return HTLEFT;
  }
  if (edge == "right") {
    return HTRIGHT;
  }
  if (edge == "top") {
    return HTTOP;
  }
  if (edge == "bottom") {
    return HTBOTTOM;
  }
  if (edge == "topLeft") {
    return HTTOPLEFT;
  }
  if (edge == "topRight") {
    return HTTOPRIGHT;
  }
  if (edge == "bottomLeft") {
    return HTBOTTOMLEFT;
  }
  if (edge == "bottomRight") {
    return HTBOTTOMRIGHT;
  }
  return HTBOTTOMRIGHT;
}

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

  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "pdf_reader/window_chrome",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        HWND window = GetHandle();
        if (call.method_name() == "minimizeWindow") {
          ShowWindow(window, SW_MINIMIZE);
          result->Success();
          return;
        }
        if (call.method_name() == "toggleMaximizeWindow") {
          ShowWindow(window, IsZoomed(window) ? SW_RESTORE : SW_MAXIMIZE);
          result->Success(flutter::EncodableValue(IsZoomed(window) != FALSE));
          return;
        }
        if (call.method_name() == "isWindowMaximized") {
          result->Success(flutter::EncodableValue(IsZoomed(window) != FALSE));
          return;
        }
        if (call.method_name() == "closeWindow") {
          PostMessage(window, WM_CLOSE, 0, 0);
          result->Success();
          return;
        }
        if (call.method_name() == "startWindowDrag") {
          ReleaseCapture();
          SendMessage(window, WM_NCLBUTTONDOWN, HTCAPTION, 0);
          result->Success();
          return;
        }
        if (call.method_name() == "startWindowResize") {
          if (IsZoomed(window)) {
            result->Success();
            return;
          }
          std::string edge = "bottomRight";
          if (const auto* args =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            const auto edge_it = args->find(flutter::EncodableValue("edge"));
            if (edge_it != args->end()) {
              if (const auto* value =
                      std::get_if<std::string>(&edge_it->second)) {
                edge = *value;
              }
            }
          }
          ReleaseCapture();
          SendMessage(window, WM_NCLBUTTONDOWN, ResizeHitTestFromEdge(edge), 0);
          result->Success();
          return;
        }
        if (call.method_name() == "setMinimumWindowSize") {
          int width = 900;
          int height = 640;
          if (const auto* args =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            const auto width_it = args->find(flutter::EncodableValue("width"));
            if (width_it != args->end()) {
              if (const auto* value = std::get_if<int>(&width_it->second)) {
                width = *value;
              }
            }
            const auto height_it =
                args->find(flutter::EncodableValue("height"));
            if (height_it != args->end()) {
              if (const auto* value = std::get_if<int>(&height_it->second)) {
                height = *value;
              }
            }
          }
          SetMinimumSize(width, height);
          result->Success();
          return;
        }
        if (call.method_name() != "setTitleBarTheme") {
          result->NotImplemented();
          return;
        }

        bool dark = false;
        if (const auto* args =
                std::get_if<flutter::EncodableMap>(call.arguments())) {
          const auto dark_it = args->find(flutter::EncodableValue("dark"));
          if (dark_it != args->end()) {
            if (const auto* value = std::get_if<bool>(&dark_it->second)) {
              dark = *value;
            }
          }
        }
        ApplyTitleBarTheme(window, dark);
        result->Success();
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

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
  window_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  switch (message) {
    case WM_NCCALCSIZE:
    case WM_NCHITTEST:
    case WM_GETMINMAXINFO:
    case WM_DPICHANGED:
      return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
  }

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

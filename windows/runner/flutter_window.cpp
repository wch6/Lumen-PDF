#include "flutter_window.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>
#include <shellapi.h>

#include <algorithm>
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

void ApplyTitleBarTheme(HWND window, bool dark) {
  if (!window) {
    return;
  }

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

int ReadIntArgument(const flutter::EncodableMap& args,
                    const std::string& key,
                    int fallback) {
  const auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) {
    return fallback;
  }
  if (const auto* value = std::get_if<int>(&it->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int64_t>(&it->second)) {
    return static_cast<int>(*value);
  }
  if (const auto* value = std::get_if<double>(&it->second)) {
    return static_cast<int>(*value);
  }
  return fallback;
}

int LogicalToPhysical(HWND window, int value) {
  return MulDiv(value, static_cast<int>(GetDpiForWindow(window)), 96);
}

int ClampInt(int value, int lower, int upper) {
  return std::min(std::max(value, lower), upper);
}

int PhysicalToLogical(HWND window, int value) {
  return MulDiv(value, 96, static_cast<int>(GetDpiForWindow(window)));
}

RECT WorkAreaForWindow(HWND window) {
  MONITORINFO monitor_info;
  monitor_info.cbSize = sizeof(MONITORINFO);
  HMONITOR monitor = MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
  if (GetMonitorInfo(monitor, &monitor_info)) {
    return monitor_info.rcWork;
  }
  RECT fallback;
  GetWindowRect(window, &fallback);
  return fallback;
}

void ApplyLogicalWindowSize(HWND window, int logical_width, int logical_height) {
  if (!window) {
    return;
  }
  if (IsZoomed(window)) {
    ShowWindow(window, SW_RESTORE);
  }

  const RECT work_area = WorkAreaForWindow(window);
  const int work_width = work_area.right - work_area.left;
  const int work_height = work_area.bottom - work_area.top;
  int width = LogicalToPhysical(window, std::max(logical_width, 720));
  int height = LogicalToPhysical(window, std::max(logical_height, 640));
  width = std::min(width, work_width);
  height = std::min(height, work_height);

  RECT current;
  GetWindowRect(window, &current);
  const int center_x = current.left + (current.right - current.left) / 2;
  const int center_y = current.top + (current.bottom - current.top) / 2;
  int left = center_x - width / 2;
  int top = center_y - height / 2;
  left = ClampInt(left, static_cast<int>(work_area.left),
                  static_cast<int>(work_area.right) - width);
  top = ClampInt(top, static_cast<int>(work_area.top),
                 static_cast<int>(work_area.bottom) - height);

  SetWindowPos(window, nullptr, left, top, width, height,
               SWP_NOZORDER | SWP_NOACTIVATE);
}

std::string WideStringToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return "";
  }
  const int size = WideCharToMultiByte(CP_UTF8, 0, value.c_str(),
                                       static_cast<int>(value.size()), nullptr,
                                       0, nullptr, nullptr);
  if (size <= 0) {
    return "";
  }
  std::string result(size, 0);
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(),
                      static_cast<int>(value.size()), result.data(), size,
                      nullptr, nullptr);
  return result;
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
        if (call.method_name() == "getWindowDpi") {
          result->Success(flutter::EncodableValue(
              static_cast<int>(GetDpiForWindow(window))));
          return;
        }
        if (call.method_name() == "getWindowSize") {
          RECT bounds;
          GetWindowRect(window, &bounds);
          flutter::EncodableMap size;
          size[flutter::EncodableValue("width")] = flutter::EncodableValue(
              PhysicalToLogical(window, bounds.right - bounds.left));
          size[flutter::EncodableValue("height")] = flutter::EncodableValue(
              PhysicalToLogical(window, bounds.bottom - bounds.top));
          result->Success(flutter::EncodableValue(size));
          return;
        }
        if (call.method_name() == "setWindowSize") {
          int width = 1280;
          int height = 720;
          if (const auto* args =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            width = ReadIntArgument(*args, "width", width);
            height = ReadIntArgument(*args, "height", height);
          }
          ApplyLogicalWindowSize(window, width, height);
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
          int width = 720;
          int height = 640;
          if (const auto* args =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            width = ReadIntArgument(*args, "width", width);
            height = ReadIntArgument(*args, "height", height);
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
  EnableFileDrop(GetHandle());
  EnableFileDrop(flutter_controller_->view()->GetNativeWindow());

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
  RestoreFlutterViewWindowProc();
  if (GetHandle()) {
    DragAcceptFiles(GetHandle(), FALSE);
  }
  window_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::NotifyWindowMaximizedChanged(HWND window) {
  if (!window_channel_) {
    return;
  }
  const bool maximized = IsZoomed(window) != FALSE;
  if (last_notified_window_maximized_.has_value() &&
      *last_notified_window_maximized_ == maximized) {
    return;
  }
  last_notified_window_maximized_ = maximized;
  window_channel_->InvokeMethod(
      "windowMaximizedChanged",
      std::make_unique<flutter::EncodableValue>(
          flutter::EncodableValue(maximized)));
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DROPFILES:
      HandleDroppedFiles(reinterpret_cast<HDROP>(wparam));
      return 0;
    case WM_NCCALCSIZE:
    case WM_NCHITTEST:
    case WM_GETMINMAXINFO:
    case WM_DPICHANGED:
      return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
    case WM_SIZE: {
      const LRESULT result =
          Win32Window::MessageHandler(hwnd, message, wparam, lparam);
      if (wparam != SIZE_MINIMIZED) {
        NotifyWindowMaximizedChanged(hwnd);
      }
      return result;
    }
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

LRESULT CALLBACK
FlutterWindow::FlutterViewWindowProc(HWND window, UINT const message,
                                     WPARAM const wparam,
                                     LPARAM const lparam) noexcept {
  auto* flutter_window = reinterpret_cast<FlutterWindow*>(
      GetProp(window, L"PDFReaderFlutterWindow"));
  if (flutter_window != nullptr && message == WM_DROPFILES) {
    flutter_window->HandleDroppedFiles(reinterpret_cast<HDROP>(wparam));
    return 0;
  }
  if (flutter_window != nullptr &&
      flutter_window->flutter_view_window_proc_ != nullptr) {
    return CallWindowProc(flutter_window->flutter_view_window_proc_, window,
                          message, wparam, lparam);
  }
  return DefWindowProc(window, message, wparam, lparam);
}

void FlutterWindow::EnableFileDrop(HWND window) {
  if (!window) {
    return;
  }
  DragAcceptFiles(window, TRUE);
  if (window == GetHandle() || flutter_view_window_ != nullptr) {
    return;
  }
  flutter_view_window_ = window;
  SetProp(window, L"PDFReaderFlutterWindow", this);
  flutter_view_window_proc_ = reinterpret_cast<WNDPROC>(SetWindowLongPtr(
      window, GWLP_WNDPROC,
      reinterpret_cast<LONG_PTR>(FlutterWindow::FlutterViewWindowProc)));
}

void FlutterWindow::RestoreFlutterViewWindowProc() {
  if (flutter_view_window_ != nullptr && IsWindow(flutter_view_window_)) {
    DragAcceptFiles(flutter_view_window_, FALSE);
    RemoveProp(flutter_view_window_, L"PDFReaderFlutterWindow");
    if (flutter_view_window_proc_ != nullptr) {
      SetWindowLongPtr(flutter_view_window_, GWLP_WNDPROC,
                       reinterpret_cast<LONG_PTR>(flutter_view_window_proc_));
    }
  }
  flutter_view_window_ = nullptr;
  flutter_view_window_proc_ = nullptr;
}

void FlutterWindow::HandleDroppedFiles(HDROP drop) {
  if (drop == nullptr) {
    return;
  }
  flutter::EncodableList paths;
  const UINT file_count = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
  for (UINT index = 0; index < file_count; ++index) {
    const UINT length = DragQueryFileW(drop, index, nullptr, 0);
    if (length == 0) {
      continue;
    }
    std::wstring path(length + 1, L'\0');
    DragQueryFileW(drop, index, path.data(), length + 1);
    path.resize(length);
    const std::string utf8_path = WideStringToUtf8(path);
    if (!utf8_path.empty()) {
      paths.emplace_back(utf8_path);
    }
  }
  DragFinish(drop);

  if (!paths.empty() && window_channel_ != nullptr) {
    window_channel_->InvokeMethod(
        "openDroppedFiles",
        std::make_unique<flutter::EncodableValue>(std::move(paths)));
  }
}

#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <shellapi.h>
#include <windows.h>

#include <memory>
#include <optional>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  static LRESULT CALLBACK FlutterViewWindowProc(HWND window,
                                                UINT const message,
                                                WPARAM const wparam,
                                                LPARAM const lparam) noexcept;

  void EnableFileDrop(HWND window);
  void RestoreFlutterViewWindowProc();
  void HandleDroppedFiles(HDROP drop);
  void NotifyWindowMaximizedChanged(HWND window);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_channel_;
  std::optional<bool> last_notified_window_maximized_;

  HWND flutter_view_window_ = nullptr;
  WNDPROC flutter_view_window_proc_ = nullptr;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_

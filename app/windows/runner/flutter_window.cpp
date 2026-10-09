#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
// `desktop_multi_window` 0.2.x is in-process: each call to
// `DesktopMultiWindow.createWindow()` spawns a fresh FlutterViewController
// inside this same exe (no separate process). For plugins registered
// against the main engine to also be visible inside the sub-window's
// engine, the plugin's `DesktopMultiWindowSetWindowCreatedCallback`
// re-registers the plugins the sub-window needs.
//
// IMPORTANT: we must NOT call the full `RegisterPlugins()` here.
// That re-registers desktop_multi_window, and its
// `DesktopMultiWindowPluginRegisterWithRegistrar` unconditionally
// creates a `WindowChannel` registered as window id 0. On a
// sub-window engine that OVERWRITES the real-id channel handler for
// `mixin.one/flutter_multi_window_channel` (same channel name on the
// same messenger -> the second SetMethodCallHandler wins). The orphan
// id-0 channel is never wired to the MultiWindowManager, so the
// sub-window's `DesktopMultiWindow.invokeMethod(...)` reaches an
// orphan whose result is never completed -> the IPC future hangs
// forever and the add-task result is silently lost.
//
// desktop_multi_window is already registered internally by its own
// `FlutterWindow` constructor (show/close/invokeMethod all work
// without us). We only add the plugins the sub-window actually uses:
// `window_manager` (setAlwaysOnTop) and its `screen_retriever`
// dependency.
#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "screen_retriever/screen_retriever_plugin.h"
#include "window_manager/window_manager_plugin.h"

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

  // Re-register the plugins the sub-window needs on every sub-window
  // engine the desktop_multi_window plugin creates. The lambda
  // receives the raw FlutterViewController pointer; we
  // reinterpret-cast and register on its engine exactly like the main
  // window did above. Safe to call once (the plugin stashes the
  // callback internally); only the first call has any effect, so
  // multiple sub-window spawns are a no-op for the registration
  // itself but each new engine gets the registered plugins.
  // NOTE: register only window_manager + screen_retriever, NOT the
  // full RegisterPlugins - see the comment above the includes.
  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {
    auto *flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController *>(controller);
    auto *registry = flutter_view_controller->engine();
    WindowManagerPluginRegisterWithRegistrar(
        registry->GetRegistrarForPlugin("WindowManagerPlugin"));
    ScreenRetrieverPluginRegisterWithRegistrar(
        registry->GetRegistrarForPlugin("ScreenRetrieverPlugin"));
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

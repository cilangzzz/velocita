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
// Rounded borderless sub-window: subclass the sub-window's WndProc
// from the desktop_multi_window created-callback and re-apply a
// SetWindowRgn rounded rectangle on every WM_WINDOWPOSCHANGED
// (covers show, resize, maximize, restore). The OS does not
// composite the clipped outer corners, so the desktop shows
// through them instead of the engine's opaque black D3D clear
// color. Pure Win32 - no MethodChannel, no flutter:: engine
// classes - so it links cleanly inside the runner (which only
// links the C engine, not the C++ PluginRegistrarManager wrapper
// that C++ plugins like desktop_multi_window use).

#include <unordered_map>

namespace {

// Per-HWND map of the original WndProc that desktop_multi_window
// installed on each sub-window. We call it via CallWindowProc so
// the plugin's own window handling (WM_SIZE child re-layout, etc.)
// keeps working. The map intentionally leaks: entries live for the
// lifetime of the process, but the count is bounded by the number
// of sub-windows ever spawned (one per browser-extension trigger).
std::unordered_map<HWND, WNDPROC> &OrigWndProcMap() {
  static std::unordered_map<HWND, WNDPROC> m;
  return m;
}

// Radius (in pixels, at 100% DPI) for the rounded outer corners.
// Matches Radii.lg (8 dp) in the Flutter theme - a deliberately
// subtle rounding, not a big pill. Adjust here if the design
// wants something softer.
constexpr int kCornerRadiusPx = 8;

void ApplyRoundedRegion(HWND root) {
  RECT wr;
  ::GetWindowRect(root, &wr);
  int w = wr.right - wr.left;
  int h = wr.bottom - wr.top;
  if (w <= 0 || h <= 0) return;
  // CreateRoundRectRgn's last two params are the ellipse DIAMETERS
  // used for the corners, so 2*radius.
  HRGN hrgn = ::CreateRoundRectRgn(0, 0, w, h,
                                   kCornerRadiusPx * 2,
                                   kCornerRadiusPx * 2);
  ::SetWindowRgn(root, hrgn, TRUE);
}

LRESULT CALLBACK VelocitaSubWindowProc(HWND hwnd, UINT msg,
                                       WPARAM wparam, LPARAM lparam) {
  if (msg == WM_WINDOWPOSCHANGED) {
    // Fires on show, resize, move, maximize, and restore. A
    // maximized borderless window fills the screen, so the
    // rounded region (which was sized for the restored extent)
    // would clip a full-screen window down to a tiny rect and
    // must be cleared. IsZoomed() returns TRUE while the window
    // is in the maximized state, FALSE otherwise (including
    // during the SIZE_RESTORED animation, which is what we
    // want for re-apply).
    if (::IsZoomed(hwnd)) {
      ::SetWindowRgn(hwnd, NULL, TRUE);
    } else {
      ApplyRoundedRegion(hwnd);
    }
  }
  auto it = OrigWndProcMap().find(hwnd);
  if (it == OrigWndProcMap().end()) {
    return ::DefWindowProc(hwnd, msg, wparam, lparam);
  }
  return ::CallWindowProc(it->second, hwnd, msg, wparam, lparam);
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

    // Strip the OS title bar / frame. desktop_multi_window's own
    // flutter_window.cc (in the plugin) creates the sub-window with
    // WS_OVERLAPPEDWINDOW (caption + frame + min/max/close boxes).
    // For the Add-Task sub-window we want a borderless popup so the
    // Dart-rendered custom title bar (_SubWindowTitleBar) is the
    // only chrome. We swap to WS_POPUP and apply with SWP_FRAMECHANGED
    // so DWM recomposes. windowManager.startDragging() still works
    // because it posts WM_NCLBUTTONDOWN + HTCAPTION, which the OS
    // honours for window-moving regardless of the WS_CAPTION bit.
    auto view = flutter_view_controller->view()->GetNativeWindow();
    if (view) {
      HWND root = GetAncestor(view, GA_ROOT);
      if (root) {
        LONG style = ::GetWindowLong(root, GWL_STYLE);
        style &= ~WS_OVERLAPPEDWINDOW;
        style |= WS_POPUP;
        ::SetWindowLong(root, GWL_STYLE, style);
        ::SetWindowPos(
            root, nullptr, 0, 0, 0, 0,
            SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
                SWP_FRAMECHANGED);

        // Subclass the WndProc so we can react to every resize /
        // show / maximize / restore and re-apply the rounded
        // region at the new size. The original WndProc (installed
        // by desktop_multi_window's FlutterWindow ctor) is saved
        // and called via CallWindowProc so the plugin's own
        // window handling keeps working.
        WNDPROC orig = reinterpret_cast<WNDPROC>(
            ::GetWindowLongPtr(root, GWLP_WNDPROC));
        OrigWndProcMap()[root] = orig;
        ::SetWindowLongPtr(root, GWLP_WNDPROC,
                           reinterpret_cast<LONG_PTR>(
                               VelocitaSubWindowProc));
        // Apply the rounded region at the current (default)
        // size so the very first show is already rounded; the
        // WndProc subclass will keep it correct across resizes.
        ApplyRoundedRegion(root);
      }
    }
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

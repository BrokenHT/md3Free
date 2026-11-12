#pragma once
#include <windows.h>
#include <cstdint>
#include <memory>

// A clipped Windows composition visual, never a rectangular DWM backdrop.
// Unsupported systems keep the per-pixel layered-window fallback.
class LyricGlassBackdrop {
 public:
  LyricGlassBackdrop();
  ~LyricGlassBackdrop();
  bool Initialize(HWND window);
  bool Present(const std::uint32_t* pixels, int width, int height);
 private:
  struct State;
  std::unique_ptr<State> state_;
};

#ifndef RUNNER_FLOATING_LYRIC_WINDOW_H_
#define RUNNER_FLOATING_LYRIC_WINDOW_H_
#include <windows.h>
#include <windowsx.h>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>
namespace Gdiplus { class Bitmap; }
class LyricGlassBackdrop;
struct FloatingLyricWord { std::wstring text; int start_ms; int duration_ms; };

// Compact, per-pixel transparent md3Free lyric capsule. The native window owns
// its bitmap and cover; progress updates never decode artwork or resize it.
class FloatingLyricWindow {
 public:
  FloatingLyricWindow();
  ~FloatingLyricWindow();
  using ConfigCallback = void (*)(void*, const char*, int);
  bool Start(HWND owner, const std::wstring& lyric, const std::wstring& title);
  void Stop();
  void UpdateLyric(const std::wstring&, const std::wstring&,
                   const std::vector<FloatingLyricWord>&, int);
  void UpdateProgress(int);
  void UpdatePlaying(bool);
  void UpdateTitle(const std::wstring&);
  void UpdateArtwork(const std::vector<std::uint8_t>&);
  void SetConfig(double, double, bool, int, bool, std::uint32_t,
                 std::uint32_t, std::uint32_t, int, std::uint32_t,
                 std::uint32_t, std::uint32_t, bool = true);
  void SetConfigCallback(ConfigCallback callback, void* data) { callback_=callback; callback_data_=data; }
  void SetPositionKey(const wchar_t* key) { position_key_=key; }
 private:
  static LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);
  void Paint();
  void Position(HWND);
  void Menu();
  void Invalidate();
  void ReleaseBitmap();
  bool EnsureBitmap(int, int);
  void PersistPosition();
  void Emit(const char* key, int value) { if(callback_) callback_(callback_data_,key,value); }
  double ScrollElapsed() const;
  double CoverElapsed() const;
  void UpdateAnimationTimer();
  HWND window_=nullptr;
  HDC dc_=nullptr;
  HBITMAP bitmap_=nullptr;
  HGDIOBJ previous_bitmap_=nullptr;
  std::uint32_t* pixels_=nullptr;
  int bitmap_w_=0, bitmap_h_=0;
  ULONG_PTR gdiplus_token_=0;
  std::unique_ptr<LyricGlassBackdrop> backdrop_;
  std::unique_ptr<Gdiplus::Bitmap> cover_;
  std::wstring lyric_, title_;
  double font_size_=14, display_scale_=1, dpi_scale_=1;
  bool playing_=false, locked_=false, horizontal_=true, overflow_=false;
  int opacity_=50;
  double elapsed_ms_=0;
  ULONGLONG clock_tick_=0;
  double cover_elapsed_ms_=0;
  ULONGLONG cover_tick_=0;
  bool animation_timer_=false;
  bool pressed_=false, moved_=false, positioned_=false;
  POINT press_cursor_{}, press_origin_{};
  const wchar_t* position_key_=L"Software\\MD3Music\\FloatingLyricCapsule";
  ConfigCallback callback_=nullptr;
  void* callback_data_=nullptr;
};
#endif

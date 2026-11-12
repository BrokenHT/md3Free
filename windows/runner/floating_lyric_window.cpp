#include "floating_lyric_window.h"
#include "lyric_glass_backdrop.h"
#include <objidl.h>
#include <gdiplus.h>
#include <dwmapi.h>
#include <algorithm>
#include <cmath>
#include <cstring>

using namespace Gdiplus;
namespace {
constexpr wchar_t kClass[]=L"MD3FREE_LYRIC_CAPSULE";
GraphicsPath* Pill(const RectF& r) {
  auto* p=new GraphicsPath(); const float d=r.Height;
  p->AddArc(r.X,r.Y,d,d,90,180);
  p->AddArc(r.GetRight()-d,r.Y,d,d,270,180); p->CloseFigure();return p;
}
void Glow(Graphics& g, const RectF& r, Color color) {
  GraphicsPath p;p.AddEllipse(r); PathGradientBrush b(&p);
  b.SetCenterColor(color);Color edge(0,color.GetR(),color.GetG(),color.GetB());int n=1;
  b.SetSurroundColors(&edge,&n);g.FillPath(&b,&p);
}
}
FloatingLyricWindow::FloatingLyricWindow() = default;
FloatingLyricWindow::~FloatingLyricWindow(){Stop();cover_.reset();if(gdiplus_token_)GdiplusShutdown(gdiplus_token_);}
bool FloatingLyricWindow::Start(HWND owner,const std::wstring& lyric,const std::wstring& title){
  if(!gdiplus_token_){GdiplusStartupInput input;if(GdiplusStartup(&gdiplus_token_,&input,nullptr)!=Ok)return false;}
  lyric_=lyric;title_=title;elapsed_ms_=0;clock_tick_=GetTickCount64();cover_tick_=clock_tick_;
  if(!window_){WNDCLASSW wc{};wc.lpfnWndProc=WndProc;wc.hInstance=GetModuleHandleW(nullptr);wc.lpszClassName=kClass;wc.hCursor=LoadCursor(nullptr,IDC_ARROW);wc.style=CS_DBLCLKS;
    if(!RegisterClassW(&wc)&&GetLastError()!=ERROR_CLASS_ALREADY_EXISTS)return false;
    window_=CreateWindowExW(WS_EX_TOPMOST|WS_EX_TOOLWINDOW|WS_EX_NOREDIRECTIONBITMAP,kClass,L"md3Free 悬浮歌词",WS_POPUP,0,0,340,68,nullptr,nullptr,wc.hInstance,this);
    if(!window_)return false;
    backdrop_=std::make_unique<LyricGlassBackdrop>();
    if(!backdrop_->Initialize(window_)){
      backdrop_.reset();
      SetWindowLongPtrW(window_,GWL_EXSTYLE,(GetWindowLongPtrW(window_,GWL_EXSTYLE)&~WS_EX_NOREDIRECTIONBITMAP)|WS_EX_LAYERED);
    }
  }
  Position(owner);ShowWindow(window_,SW_SHOWNOACTIVATE);Invalidate();return true;
}
void FloatingLyricWindow::Stop(){cover_elapsed_ms_=CoverElapsed();cover_tick_=GetTickCount64();backdrop_.reset();if(window_){KillTimer(window_,1);DestroyWindow(window_);window_=nullptr;}animation_timer_=false;ReleaseBitmap();positioned_=false;}
void FloatingLyricWindow::Invalidate(){if(window_)InvalidateRect(window_,nullptr,FALSE);}
double FloatingLyricWindow::ScrollElapsed() const{return elapsed_ms_+(playing_?static_cast<double>(GetTickCount64()-clock_tick_):0);}
double FloatingLyricWindow::CoverElapsed() const{return cover_elapsed_ms_+((playing_&&window_)?static_cast<double>(GetTickCount64()-cover_tick_):0);}
void FloatingLyricWindow::UpdateAnimationTimer(){
  const bool needed=window_&&playing_&&IsWindowVisible(window_)&&(cover_||overflow_);
  if(needed&&!animation_timer_){SetTimer(window_,1,16,nullptr);animation_timer_=true;}
  else if(!needed&&animation_timer_){KillTimer(window_,1);animation_timer_=false;}
}
void FloatingLyricWindow::UpdateLyric(const std::wstring& lyric,const std::wstring&,const std::vector<FloatingLyricWord>&,int){
  if(lyric_==lyric)return;lyric_=lyric;elapsed_ms_=0;clock_tick_=GetTickCount64();Invalidate();
}
void FloatingLyricWindow::UpdateProgress(int){} // Text moves on its own monotonic animation clock.
void FloatingLyricWindow::UpdatePlaying(bool playing){if(playing==playing_)return;elapsed_ms_=ScrollElapsed();cover_elapsed_ms_=CoverElapsed();clock_tick_=GetTickCount64();cover_tick_=clock_tick_;playing_=playing;UpdateAnimationTimer();Invalidate();}
void FloatingLyricWindow::UpdateTitle(const std::wstring& title){if(title==title_)return;title_=title;lyric_.clear();elapsed_ms_=0;cover_elapsed_ms_=0;clock_tick_=GetTickCount64();cover_tick_=clock_tick_;cover_.reset();Invalidate();}
void FloatingLyricWindow::UpdateArtwork(const std::vector<std::uint8_t>& bytes){
  cover_.reset(); if(!bytes.empty()&&gdiplus_token_){
    HGLOBAL h=GlobalAlloc(GMEM_MOVEABLE,bytes.size());if(h){void* data=GlobalLock(h);memcpy(data,bytes.data(),bytes.size());GlobalUnlock(h);IStream* stream=nullptr;
      if(SUCCEEDED(CreateStreamOnHGlobal(h,TRUE,&stream))){
        auto source=std::unique_ptr<Bitmap>(Bitmap::FromStream(stream));
        if(source&&source->GetLastStatus()==Ok)cover_.reset(source->Clone(0,0,source->GetWidth(),source->GetHeight(),PixelFormat32bppPARGB));
        source.reset();stream->Release();
      }else GlobalFree(h);
    }
  }Invalidate();
}
void FloatingLyricWindow::SetConfig(double font,double scale,bool,int opacity,bool locked,std::uint32_t,std::uint32_t,std::uint32_t,int,std::uint32_t,std::uint32_t,std::uint32_t,bool horizontal){
  // Older releases stored 40–100 px karaoke text. Map that to a readable compact
  // size without letting a legacy preference expand the new overlay.
  font_size_=std::clamp(font>24?font*.4:font,12.0,18.0);display_scale_=std::clamp(scale,.85,1.25);
  opacity_=std::clamp(opacity,0,100);locked_=locked;horizontal_=horizontal;
  if(window_){Position(window_);Invalidate();}
}
void FloatingLyricWindow::Position(HWND owner){
  MONITORINFO m{sizeof(MONITORINFO)};if(!GetMonitorInfoW(MonitorFromWindow(owner?owner:window_,MONITOR_DEFAULTTOPRIMARY),&m))return;
  dpi_scale_=static_cast<double>(GetDpiForWindow(owner?owner:window_))/96.0*display_scale_;
  const int w=std::min(static_cast<int>(340*dpi_scale_),static_cast<int>(m.rcWork.right-m.rcWork.left-24));
  const int h=static_cast<int>(68*dpi_scale_);int x=m.rcWork.right-w-static_cast<int>(24*dpi_scale_),y=m.rcWork.top+static_cast<int>(48*dpi_scale_);
  if(positioned_){RECT r{};GetWindowRect(window_,&r);x=r.left;y=r.top;}
  else {HKEY k;if(RegOpenKeyExW(HKEY_CURRENT_USER,position_key_,0,KEY_READ,&k)==ERROR_SUCCESS){DWORD size=sizeof(DWORD),v=0;if(RegQueryValueExW(k,L"X",nullptr,nullptr,reinterpret_cast<BYTE*>(&v),&size)==ERROR_SUCCESS)x=static_cast<int>(v);size=sizeof(DWORD);if(RegQueryValueExW(k,L"Y",nullptr,nullptr,reinterpret_cast<BYTE*>(&v),&size)==ERROR_SUCCESS)y=static_cast<int>(v);RegCloseKey(k);}positioned_=true;}
  x=std::clamp(x,static_cast<int>(m.rcWork.left),static_cast<int>(m.rcWork.right)-w);y=std::clamp(y,static_cast<int>(m.rcWork.top),static_cast<int>(m.rcWork.bottom)-h);
  SetWindowPos(window_,HWND_TOPMOST,x,y,w,h,SWP_NOACTIVATE|SWP_SHOWWINDOW);
}
void FloatingLyricWindow::PersistPosition(){if(!window_)return;RECT r{};GetWindowRect(window_,&r);HKEY k;if(RegCreateKeyExW(HKEY_CURRENT_USER,position_key_,0,nullptr,0,KEY_WRITE,nullptr,&k,nullptr)==ERROR_SUCCESS){DWORD x=r.left,y=r.top;RegSetValueExW(k,L"X",0,REG_DWORD,reinterpret_cast<BYTE*>(&x),sizeof(x));RegSetValueExW(k,L"Y",0,REG_DWORD,reinterpret_cast<BYTE*>(&y),sizeof(y));RegCloseKey(k);}}
bool FloatingLyricWindow::EnsureBitmap(int w,int h){
  if(dc_&&w==bitmap_w_&&h==bitmap_h_)return true;ReleaseBitmap();if(w<=0||h<=0)return false;
  BITMAPINFO info{};info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);info.bmiHeader.biWidth=w;info.bmiHeader.biHeight=-h;info.bmiHeader.biPlanes=1;info.bmiHeader.biBitCount=32;info.bmiHeader.biCompression=BI_RGB;
  dc_=CreateCompatibleDC(nullptr);bitmap_=CreateDIBSection(dc_,&info,DIB_RGB_COLORS,reinterpret_cast<void**>(&pixels_),nullptr,0);if(!bitmap_){ReleaseBitmap();return false;}
  previous_bitmap_=SelectObject(dc_,bitmap_);bitmap_w_=w;bitmap_h_=h;return true;
}
void FloatingLyricWindow::ReleaseBitmap(){if(dc_&&previous_bitmap_)SelectObject(dc_,previous_bitmap_);if(bitmap_)DeleteObject(bitmap_);if(dc_)DeleteDC(dc_);dc_=nullptr;bitmap_=nullptr;previous_bitmap_=nullptr;pixels_=nullptr;bitmap_w_=bitmap_h_=0;}
void FloatingLyricWindow::Paint(){
  PAINTSTRUCT ps{};BeginPaint(window_,&ps);RECT r{};GetClientRect(window_,&r);int w=r.right,h=r.bottom;if(!EnsureBitmap(w,h)){EndPaint(window_,&ps);return;}
  memset(pixels_,0,w*h*4);
  {
    Bitmap target(w,h,w*4,PixelFormat32bppPARGB,reinterpret_cast<BYTE*>(pixels_));Graphics g(&target);
    g.SetSmoothingMode(SmoothingModeAntiAlias);g.SetTextRenderingHint(TextRenderingHintAntiAliasGridFit);g.SetInterpolationMode(InterpolationModeHighQualityBicubic);
    const float s=static_cast<float>(dpi_scale_);RectF rect(.8f*s,.8f*s,w-1.6f*s,h-1.6f*s);std::unique_ptr<GraphicsPath> pill(Pill(rect));
    const BYTE a=static_cast<BYTE>(65+opacity_*1.5);
    LinearGradientBrush base(PointF(0,0),PointF(static_cast<float>(w),static_cast<float>(h)),Color(a,63,45,82),Color(a,27,23,42));g.FillPath(&base,pill.get());
    g.SetClip(pill.get());Glow(g,RectF(w*.05f,-24*s,170*s,78*s),Color(85,246,241,255));Glow(g,RectF(w-135*s,h-35*s,150*s,65*s),Color(44,150,226,208));
    g.ResetClip();LinearGradientBrush edge(PointF(0,0),PointF(static_cast<float>(w),static_cast<float>(h)),Color(180,255,249,255),Color(75,182,224,222));Pen rim(&edge,1.1f*s);g.DrawPath(&rim,pill.get());
    RectF art(10*s,10*s,48*s,48*s);GraphicsPath circle;circle.AddEllipse(art);g.SetClip(&circle);
    if(cover_){
      const auto state=g.Save();const float cx=art.X+art.Width/2,cy=art.Y+art.Height/2;
      g.TranslateTransform(cx,cy);g.RotateTransform(static_cast<float>(std::fmod(CoverElapsed(),22000.0)*360.0/22000.0));g.TranslateTransform(-cx,-cy);
      const float side=static_cast<float>(std::min(cover_->GetWidth(),cover_->GetHeight()));
      g.DrawImage(cover_.get(),art,(cover_->GetWidth()-side)/2,(cover_->GetHeight()-side)/2,side,side,UnitPixel);g.Restore(state);
    }
    else{SolidBrush bg(Color(255,60,48,80));g.FillEllipse(&bg,art);Font fallback(L"Segoe UI Symbol",23*s,FontStyleRegular,UnitPixel);SolidBrush mint(Color(255,150,226,208));g.DrawString(L"♪",-1,&fallback,PointF(22*s,17*s),&mint);}
    g.ResetClip();Pen artEdge(Color(65,255,255,255),.8f*s);g.DrawEllipse(&artEdge,art);
    const float x=70*s,tw=w-x-16*s;
    Font titleFont(L"Microsoft YaHei UI",11.5f*s,FontStyleRegular,UnitPixel);Font lyricFont(L"Microsoft YaHei UI",static_cast<float>(font_size_)*s,FontStyleRegular,UnitPixel);
    StringFormat titleFormat;titleFormat.SetFormatFlags(StringFormatFlagsNoWrap);titleFormat.SetTrimming(StringTrimmingEllipsisCharacter);
    SolidBrush muted(Color(255,203,192,218)),ink(Color(255,247,242,255));RectF titleRect(x,12*s,tw,19*s);
    const auto title=title_.empty()?std::wstring(L"md3Free"):title_;g.DrawString(title.c_str(),-1,&titleFont,titleRect,&titleFormat,&muted);
    const auto text=lyric_.empty()?(playing_?std::wstring(L"音乐播放中"):std::wstring(L"已暂停")):lyric_;
    StringFormat format(StringFormat::GenericTypographic());format.SetFormatFlags(StringFormatFlagsNoWrap|StringFormatFlagsMeasureTrailingSpaces);
    RectF bounds;g.MeasureString(text.c_str(),-1,&lyricFont,PointF(0,0),&format,&bounds);
    const float distance=std::max(0.f,bounds.Width-tw);overflow_=distance>1;
    float offset=0;if(overflow_){const double travel=distance/(24*s)*1000;const double t=std::fmod(ScrollElapsed(),travel*2+2000);if(t>1000&&t<1000+travel)offset=static_cast<float>((t-1000)/travel)*distance;else if(t>=1000+travel&&t<2000+travel)offset=distance;else if(t>=2000+travel)offset=static_cast<float>(1-(t-2000-travel)/travel)*distance;}
    g.SetClip(RectF(x,32*s,tw,27*s));g.DrawString(text.c_str(),-1,&lyricFont,PointF(x-offset,32*s),&format,&ink);g.ResetClip();g.Flush(FlushIntentionSync);
  }
  if(backdrop_){
    if(!backdrop_->Present(pixels_,w,h)){
      backdrop_.reset();
      SetWindowLongPtrW(window_,GWL_EXSTYLE,(GetWindowLongPtrW(window_,GWL_EXSTYLE)&~WS_EX_NOREDIRECTIONBITMAP)|WS_EX_LAYERED);
      Invalidate();
    }
  }
  else{RECT wr{};GetWindowRect(window_,&wr);HDC screen=GetDC(nullptr);POINT dst{wr.left,wr.top},src{};SIZE size{w,h};BLENDFUNCTION blend{AC_SRC_OVER,0,255,AC_SRC_ALPHA};UpdateLayeredWindow(window_,screen,&dst,&size,dc_,&src,0,&blend,ULW_ALPHA);ReleaseDC(nullptr,screen);}
  EndPaint(window_,&ps);UpdateAnimationTimer();
}
void FloatingLyricWindow::Menu(){
  HMENU menu=CreatePopupMenu();AppendMenuW(menu,MF_STRING,1,playing_?L"暂停播放":L"继续播放");AppendMenuW(menu,MF_STRING|(locked_?MF_CHECKED:0),2,L"锁定位置");AppendMenuW(menu,MF_STRING,3,L"字号稍大");AppendMenuW(menu,MF_STRING,4,L"字号稍小");AppendMenuW(menu,MF_SEPARATOR,0,nullptr);AppendMenuW(menu,MF_STRING,5,L"关闭悬浮歌词");POINT p{};GetCursorPos(&p);SetForegroundWindow(window_);int action=TrackPopupMenu(menu,TPM_RETURNCMD|TPM_NONOTIFY,p.x,p.y,0,window_,nullptr);DestroyMenu(menu);
  if(action==1)Emit("play",1);if(action==2){locked_=!locked_;Emit("locked",locked_?1:0);}if(action==3||action==4){font_size_=std::clamp(font_size_+(action==3?1:-1),12.0,18.0);Emit("fontSize",static_cast<int>(font_size_));Invalidate();}if(action==5){Emit("close",1);Stop();}
}
LRESULT CALLBACK FloatingLyricWindow::WndProc(HWND w,UINT m,WPARAM wp,LPARAM lp){
  if(m==WM_NCCREATE){auto* c=reinterpret_cast<CREATESTRUCTW*>(lp);SetWindowLongPtrW(w,GWLP_USERDATA,reinterpret_cast<LONG_PTR>(c->lpCreateParams));}
  auto* self=reinterpret_cast<FloatingLyricWindow*>(GetWindowLongPtrW(w,GWLP_USERDATA));if(!self)return DefWindowProcW(w,m,wp,lp);
  switch(m){
    case WM_NCHITTEST:{RECT r{};GetWindowRect(w,&r);const double x=GET_X_LPARAM(lp)-r.left,y=GET_Y_LPARAM(lp)-r.top,h=r.bottom-r.top,width=r.right-r.left,rad=h/2;const double cx=x<rad?rad:(x>width-rad?width-rad:x);if((x-cx)*(x-cx)+(y-rad)*(y-rad)>rad*rad)return HTTRANSPARENT;return HTCLIENT;}
    case WM_PAINT:self->Paint();return 0;
    case WM_ERASEBKGND:return 1;
    case WM_TIMER:if(self->playing_&&(self->cover_||self->overflow_))self->Invalidate();return 0;
    case WM_LBUTTONDOWN:{self->pressed_=true;self->moved_=false;GetCursorPos(&self->press_cursor_);RECT r{};GetWindowRect(w,&r);self->press_origin_={r.left,r.top};SetCapture(w);return 0;}
    case WM_MOUSEMOVE:if(self->pressed_&&(wp&MK_LBUTTON)){POINT p{};GetCursorPos(&p);const int dx=p.x-self->press_cursor_.x,dy=p.y-self->press_cursor_.y;if(abs(dx)+abs(dy)>4)self->moved_=true;if(self->moved_&&!self->locked_)SetWindowPos(w,HWND_TOPMOST,self->press_origin_.x+(self->horizontal_?dx:0),self->press_origin_.y+dy,0,0,SWP_NOSIZE|SWP_NOACTIVATE);}return 0;
    case WM_LBUTTONUP:{const bool click=self->pressed_&&!self->moved_;self->pressed_=false;ReleaseCapture();if(self->moved_)self->PersistPosition();if(click)self->Menu();return 0;}
    case WM_CAPTURECHANGED:self->pressed_=false;return 0;
    case WM_RBUTTONUP:self->Menu();return 0;
    case WM_DPICHANGED:self->Position(w);self->Invalidate();return 0;
    case WM_CLOSE:self->Emit("close",1);self->Stop();return 0;
  }return DefWindowProcW(w,m,wp,lp);
}

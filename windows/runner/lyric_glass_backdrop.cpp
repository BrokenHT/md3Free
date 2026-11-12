#include "lyric_glass_backdrop.h"
#include <d3d11.h>
#include <d2d1_1.h>
#include <dwmapi.h>
#include <DispatcherQueue.h>
#include <winrt/Windows.System.h>
#include <winrt/Windows.Graphics.DirectX.h>
#include <winrt/Windows.UI.Composition.h>
#include <winrt/Windows.UI.Composition.Desktop.h>
#include <windows.ui.composition.interop.h>

namespace composition = winrt::Windows::UI::Composition;
namespace directx = winrt::Windows::Graphics::DirectX;

struct LyricGlassBackdrop::State {
  composition::Compositor compositor{nullptr};
  composition::Desktop::DesktopWindowTarget target{nullptr};
  composition::ContainerVisual root{nullptr};
  composition::SpriteVisual background{nullptr}, foreground{nullptr};
  composition::CompositionRoundedRectangleGeometry geometry{nullptr};
  composition::CompositionGraphicsDevice graphics{nullptr};
  composition::CompositionDrawingSurface surface{nullptr};
  winrt::com_ptr<ID3D11Device> d3d;
  winrt::com_ptr<ID2D1Device> d2d;
  int width=0, height=0;
};

LyricGlassBackdrop::LyricGlassBackdrop() = default;
LyricGlassBackdrop::~LyricGlassBackdrop() = default;

bool LyricGlassBackdrop::Initialize(HWND window) {
  try {
    const BOOL enabled=TRUE;
    winrt::check_hresult(DwmSetWindowAttribute(window,DWMWA_USE_HOSTBACKDROPBRUSH,&enabled,sizeof(enabled)));
    // The dispatcher is shared on this UI thread and survives closing/reopening
    // the capsule. Creating another dispatcher on the same thread would fail.
    static winrt::Windows::System::DispatcherQueueController dispatcher{nullptr};
    if(!winrt::Windows::System::DispatcherQueue::GetForCurrentThread()) {
      DispatcherQueueOptions options{sizeof(options),DQTYPE_THREAD_CURRENT,DQTAT_COM_STA};
      winrt::check_hresult(CreateDispatcherQueueController(options,
        reinterpret_cast<ABI::Windows::System::IDispatcherQueueController**>(winrt::put_abi(dispatcher))));
    }
    auto state=std::make_unique<State>();
    state->compositor=composition::Compositor();
    auto desktop=state->compositor.as<ABI::Windows::UI::Composition::Desktop::ICompositorDesktopInterop>();
    winrt::check_hresult(desktop->CreateDesktopWindowTarget(window,TRUE,
      reinterpret_cast<ABI::Windows::UI::Composition::Desktop::IDesktopWindowTarget**>(winrt::put_abi(state->target))));
    state->root=state->compositor.CreateContainerVisual();
    state->geometry=state->compositor.CreateRoundedRectangleGeometry();
    state->root.Clip(state->compositor.CreateGeometricClip(state->geometry));
    state->background=state->compositor.CreateSpriteVisual();
    state->background.Brush(state->compositor.CreateHostBackdropBrush());
    state->foreground=state->compositor.CreateSpriteVisual();
    state->root.Children().InsertAtTop(state->background);
    state->root.Children().InsertAtTop(state->foreground);
    state->target.Root(state->root);
    winrt::check_hresult(D3D11CreateDevice(nullptr,D3D_DRIVER_TYPE_HARDWARE,nullptr,
      D3D11_CREATE_DEVICE_BGRA_SUPPORT,nullptr,0,D3D11_SDK_VERSION,state->d3d.put(),nullptr,nullptr));
    winrt::com_ptr<ID2D1Factory1> factory;
    winrt::check_hresult(D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED,
      __uuidof(ID2D1Factory1),nullptr,factory.put_void()));
    winrt::check_hresult(factory->CreateDevice(state->d3d.as<IDXGIDevice>().get(),state->d2d.put()));
    auto interop=state->compositor.as<ABI::Windows::UI::Composition::ICompositorInterop>();
    winrt::check_hresult(interop->CreateGraphicsDevice(state->d2d.get(),
      reinterpret_cast<ABI::Windows::UI::Composition::ICompositionGraphicsDevice**>(winrt::put_abi(state->graphics))));
    state_=std::move(state);
    return true;
  } catch(const winrt::hresult_error&) {
    state_.reset();
    return false;
  }
}

bool LyricGlassBackdrop::Present(const std::uint32_t* pixels,int width,int height) {
  if(!state_||width<=0||height<=0)return false;
  try {
    auto& s=*state_;
    if(s.width!=width||s.height!=height) {
      const winrt::Windows::Foundation::Numerics::float2 size{static_cast<float>(width),static_cast<float>(height)};
      s.root.Size(size);s.background.Size(size);s.foreground.Size(size);
      s.geometry.Size(size);s.geometry.CornerRadius({height*.5f,height*.5f});
      s.surface=s.graphics.CreateDrawingSurface({size.x,size.y},
        directx::DirectXPixelFormat::B8G8R8A8UIntNormalized,directx::DirectXAlphaMode::Premultiplied);
      s.foreground.Brush(s.compositor.CreateSurfaceBrush(s.surface));
      s.width=width;s.height=height;
    }
    auto interop=s.surface.as<ABI::Windows::UI::Composition::ICompositionDrawingSurfaceInterop>();
    POINT offset{};winrt::com_ptr<ID2D1DeviceContext> context;
    winrt::check_hresult(interop->BeginDraw(nullptr,__uuidof(ID2D1DeviceContext),context.put_void(),&offset));
    HRESULT result=S_OK;
    {
      context->SetTransform(D2D1::Matrix3x2F::Translation(static_cast<float>(offset.x),static_cast<float>(offset.y)));
      context->Clear(D2D1::ColorF(0,0));
      winrt::com_ptr<ID2D1Bitmap1> bitmap;
      const auto props=D2D1::BitmapProperties1(D2D1_BITMAP_OPTIONS_NONE,
        D2D1::PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM,D2D1_ALPHA_MODE_PREMULTIPLIED));
      result=context->CreateBitmap(D2D1::SizeU(width,height),pixels,width*4,&props,bitmap.put());
      if(SUCCEEDED(result))context->DrawBitmap(bitmap.get());
    }
    const HRESULT ended=interop->EndDraw();
    return SUCCEEDED(result)&&SUCCEEDED(ended);
  } catch(const winrt::hresult_error&) {return false;}
}

import SwiftUI

struct VisualEffectView: NSViewRepresentable {
  let visualEffectView = NSVisualEffectView()

  var material: NSVisualEffectView.Material = .popover
  var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

  func makeNSView(context: Context) -> NSVisualEffectView {
    return visualEffectView
  }

  func updateNSView(_ view: NSVisualEffectView, context: Context) {
    visualEffectView.material = material
    visualEffectView.blendingMode = blendingMode
  }
}

// NSGlassEffectView exists only in the macOS 26 SDK (Xcode 26 / Swift 6.2+).
// When built with an older toolchain, fall back to the regular blur background.
#if compiler(>=6.2)
@available(macOS 26.0, *)
struct GlassEffectView: NSViewRepresentable {
  let glassEffectView = NSGlassEffectView()

  var style: NSGlassEffectView.Style = .regular

  func makeNSView(context: Context) -> NSGlassEffectView {
    return glassEffectView
  }

  func updateNSView(_ view: NSGlassEffectView, context: Context) {
    glassEffectView.style = style
  }
}
#else
@available(macOS 26.0, *)
struct GlassEffectView: View {
  var body: some View {
    VisualEffectView()
  }
}
#endif

#Preview {
  VisualEffectView(
    material: .popover,
    blendingMode: .behindWindow
  )
}

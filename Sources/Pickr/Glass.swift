import SwiftUI
import AppKit

/// Liquid Glass arrived in macOS 26 and is refined in macOS 27, which also hands the user a slider
/// for how tinted it looks. Pickr keeps a macOS 14 deployment target, so glass is adopted behind an
/// availability check and the previous vibrancy treatment remains the fallback for older systems.
///
/// Both paths live here so they cannot drift apart, and so there is exactly one place to change if a
/// surface needs a different treatment.
extension View {

    /// A glass surface clipped to `shape`, falling back to an `NSVisualEffectView` material on
    /// systems older than macOS 26.
    @ViewBuilder
    func pickrGlassSurface<S: Shape>(
        in shape: S,
        vibrancy: NSVisualEffectView.Material = .hudWindow
    ) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(
                VisualEffectView(material: vibrancy, blendingMode: .behindWindow)
                    .clipShape(shape)
            )
        }
    }
}

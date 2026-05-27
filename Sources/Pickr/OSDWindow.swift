import SwiftUI

class OSDController {
    static let shared = OSDController()
    
    private var window: NSWindow?
    private var dismissTask: Task<Void, Never>?
    
    func show(isMuted: Bool) {
        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 220, height: 220),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            
            let host = NSHostingView(rootView: OSDView(isMuted: isMuted))
            panel.contentView = host
            window = panel
        } else {
            (window?.contentView as? NSHostingView<OSDView>)?.rootView = OSDView(isMuted: isMuted)
        }
        
        guard let window = window else { return }
        window.center()
        
        // Fading animation in
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            window.animator().alphaValue = 1.0
        }
        
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s delay
            guard !Task.isCancelled else { return }
            
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.3
            window.animator().alphaValue = 0.0
            NSAnimationContext.endGrouping()
        }
    }
}

struct OSDView: View {
    let isMuted: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .foregroundStyle(.primary)
            
            Text(isMuted ? "Muted" : "Mic On")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
        }
        .frame(width: 220, height: 220)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        )
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

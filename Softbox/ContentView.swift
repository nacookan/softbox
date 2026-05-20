import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var windowManager: WindowManager
    @Environment(\.openWindow) private var openWindow

    @State private var pendingSnapshot: WindowSnapshot? = WindowManager.instance?.nextSnapshot()

    @State private var showControls = false     // per-window (used when not linked)
    @State private var cursorOverControlBar = false
    @State private var showBrightnessHint = false

    // Routes to shared or per-window state depending on linked mode
    private var effectiveShowControls: Bool {
        windowManager.linked ? windowManager.showControls : showControls
    }

    private func toggleControls() {
        if windowManager.linked {
            windowManager.showControls.toggle()
        } else {
            showControls.toggle()
        }
    }

    @State private var brightness: Double = 1.0
    @State private var colorTemperature: Double = 6500

    private var brightnessBinding: Binding<Double> {
        windowManager.linked
            ? Binding(get: { windowManager.linkedBrightness },
                      set: { windowManager.linkedBrightness = $0 })
            : $brightness
    }
    private var colorTempBinding: Binding<Double> {
        windowManager.linked
            ? Binding(get: { windowManager.linkedColorTemperature },
                      set: { windowManager.linkedColorTemperature = $0 })
            : $colorTemperature
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            screenColor
                .ignoresSafeArea()
            controlBar
                .padding()
                .onHover { cursorOverControlBar = $0 }
                .opacity(effectiveShowControls ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: effectiveShowControls)
                .allowsHitTesting(effectiveShowControls)
        }
        .overlay(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: "sun.max")
                Text("Increase your display brightness for best results")
            }
            .font(.callout)
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(.regularMaterial))
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
            .environment(\.colorScheme, .light)
            .allowsHitTesting(false)
            .opacity(showBrightnessHint ? 1 : 0)
            .animation(.easeInOut(duration: 0.5), value: showBrightnessHint)
        }
        .frame(minWidth: 300, minHeight: 200)
        .background(WindowConfigurator(
            windowManager: windowManager,
            skipDrag: cursorOverControlBar && effectiveShowControls,
            onTap: { toggleControls() },
            brightness: brightnessBinding.wrappedValue,
            colorTemperature: colorTempBinding.wrappedValue,
            initialFrame: pendingSnapshot.map {
                NSRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height)
            }
        ))
        .onAppear {
            windowManager.openWindowCount += 1
            if let snap = pendingSnapshot {
                // Session restore: use saved values
                brightness = snap.brightness
                colorTemperature = snap.colorTemperature
            } else if windowManager.openWindowCount >= 2 {
                // New window opened by user: match the active window
                brightness = windowManager.seedBrightness
                colorTemperature = windowManager.seedColorTemperature
                if windowManager.openWindowCount == 2 {
                    // 2nd window also auto-enables linking
                    windowManager.linkedBrightness = brightness
                    windowManager.linkedColorTemperature = colorTemperature
                    windowManager.linked = true
                }
            }
            if windowManager.openWindowCount == 1 || pendingSnapshot != nil {
                showBrightnessHint = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    showBrightnessHint = false
                }
            }
            if windowManager.openWindowCount == 1 {
                for _ in 0..<windowManager.pendingSnapshots.count {
                    openWindow(id: "softbox")
                }
            }
        }
        .onDisappear { windowManager.openWindowCount -= 1 }
        .onChange(of: windowManager.linked) { _, isLinked in
            if !isLinked {
                brightness = windowManager.linkedBrightness
                colorTemperature = windowManager.linkedColorTemperature
                showControls = windowManager.showControls  // carry shared state into per-window
            }
        }
    }

    private var screenColor: Color {
        let b = brightnessBinding.wrappedValue
        let k = colorTempBinding.wrappedValue
        let t = (k - 2700) / (6500 - 2700)
        return Color(red: b, green: (0.706 + t * 0.294) * b, blue: (0.420 + t * 0.580) * b)
    }

    private var controlBar: some View {
        VStack(spacing: 6) {
            // Window position — global, applies to all windows regardless of link
            HStack(spacing: 14) {
                Toggle("Float on Top", isOn: Binding(
                    get: { windowManager.position == .floatOnTop },
                    set: { windowManager.position = $0 ? .floatOnTop : .normal }
                ))
                .toggleStyle(.checkbox)
                Toggle("Pin to Back", isOn: Binding(
                    get: { windowManager.position == .pinToBack },
                    set: { windowManager.position = $0 ? .pinToBack : .normal }
                ))
                .toggleStyle(.checkbox)
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 10) {
                Image(systemName: "sun.min").foregroundStyle(.secondary)
                Slider(value: brightnessBinding, in: 0...1).frame(minWidth: 120)
                Image(systemName: "sun.max.fill").foregroundStyle(.secondary)
                Text(verbatim: "\(Int(brightnessBinding.wrappedValue * 100))%")
                    .monospacedDigit().frame(width: 48, alignment: .leading).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Image(systemName: "flame").foregroundStyle(.secondary)
                Slider(value: colorTempBinding, in: 2700...6500, step: 100).frame(minWidth: 120)
                Image(systemName: "snowflake").foregroundStyle(.secondary)
                Text(verbatim: "\(Int(colorTempBinding.wrappedValue))K")
                    .monospacedDigit().frame(width: 48, alignment: .leading).foregroundStyle(.secondary)
            }
            if windowManager.openWindowCount > 1 {
                Toggle("Link windows", isOn: Binding(
                    get: { windowManager.linked },
                    set: { newValue in
                        if newValue {
                            windowManager.linkedBrightness = brightness
                            windowManager.linkedColorTemperature = colorTemperature
                            windowManager.showControls = showControls  // adopt this window's state
                        }
                        windowManager.linked = newValue
                        windowManager.saveSession()
                    }
                ))
                .toggleStyle(.checkbox)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.regularMaterial))
        .environment(\.colorScheme, .light)
    }
}

// MARK: - Window configuration + drag

// isMovableByWindowBackground does not work with SwiftUI's NSHostingView because
// NSHostingView always claims the hit test, so mouseDownCanMoveWindow is never reached.
//
// Instead, a local event monitor intercepts mouseDown before SwiftUI sees it.
// Whether to drag is determined by `skipDrag`, which ContentView sets via .onHover
// on the control bar — true while the cursor is over the bar, false otherwise.
// When not skipping, we call window.performDrag(with:), the same call the title
// bar uses, giving us native snapping, Stage Manager, and all system behaviors.
//
// makeNSView defers install() via async because nsView.window is nil at call time.
// When restoring a saved frame, the window is hidden (alphaValue=0) before install
// so it never appears at the default SwiftUI position; it fades in at the correct frame.
struct WindowConfigurator: NSViewRepresentable {
    let windowManager: WindowManager
    let skipDrag: Bool
    let onTap: () -> Void
    let brightness: Double
    let colorTemperature: Double
    let initialFrame: NSRect?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            if !coordinator.isInstalled, coordinator.initialFrame != nil {
                window.alphaValue = 0
            }
            coordinator.install(in: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.windowManagerRef = windowManager
        context.coordinator.brightness = brightness
        context.coordinator.colorTemperature = colorTemperature
        context.coordinator.initialFrame = initialFrame
        context.coordinator.skipDrag = skipDrag
        context.coordinator.onTap = onTap

        if let window = nsView.window {
            if !context.coordinator.isInstalled, initialFrame != nil {
                window.alphaValue = 0
            }
            window.tabbingMode = .disallowed
            window.title = ""
            window.setFrameAutosaveName("")
            windowManager.apply()
            context.coordinator.install(in: window)
            windowManager.updateSnapshot(for: window,
                                         brightness: brightness,
                                         colorTemperature: colorTemperature)
            // Keep seed current so new windows open with the active window's values
            if window.isKeyWindow {
                windowManager.updateSeed(brightness: brightness,
                                         colorTemperature: colorTemperature)
            }
        }
    }

    class Coordinator {
        private var monitors: [Any] = []
        private var frameObs: NSKeyValueObservation?
        private weak var window: NSWindow?

        var isInstalled: Bool { window != nil }
        weak var windowManagerRef: WindowManager?
        var brightness: Double = 1.0
        var colorTemperature: Double = 6500
        var initialFrame: NSRect?
        var skipDrag = false
        var onTap: (() -> Void)?
        private var mouseDownLocation: NSPoint?

        func install(in window: NSWindow) {
            guard self.window == nil else { return }
            self.window = window

            frameObs = window.observe(\.frame, options: [.new]) { [weak self] win, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.windowManagerRef?.updateSnapshot(for: win,
                                                          brightness: self.brightness,
                                                          colorTemperature: self.colorTemperature)
                }
            }

            if let frame = initialFrame {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak window] in
                    guard let window else { return }
                    window.setFrame(frame, display: false)
                    NSAnimationContext.runAnimationGroup { ctx in
                        ctx.duration = 0.15
                        window.animator().alphaValue = 1
                    }
                }
            }

            if let monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] event in
                guard let self, event.window === self.window, !self.skipDrag else { return event }
                let loc = event.locationInWindow
                let size = event.window!.frame.size
                let border: CGFloat = 10
                guard loc.x > border, loc.x < size.width  - border,
                      loc.y > border, loc.y < size.height - border else { return event }
                self.mouseDownLocation = NSEvent.mouseLocation
                self.window?.performDrag(with: event)
                return nil
            }) { monitors.append(monitor) }

            if let monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] event in
                guard let self, event.window === self.window,
                      let start = self.mouseDownLocation else { return event }
                self.mouseDownLocation = nil
                let moved = hypot(NSEvent.mouseLocation.x - start.x,
                                  NSEvent.mouseLocation.y - start.y)
                if moved < 4 { self.onTap?() }
                return event
            }) { monitors.append(monitor) }
        }

        deinit {
            frameObs?.invalidate()
            monitors.forEach { NSEvent.removeMonitor($0) }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WindowManager())
}

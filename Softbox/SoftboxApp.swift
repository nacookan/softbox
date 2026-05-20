import SwiftUI
import AppKit

// MARK: - Snapshot types

struct WindowSnapshot: Codable {
    var x, y, width, height: Double
    var brightness, colorTemperature: Double
}

struct SessionSnapshot: Codable {
    var linked: Bool
    var linkedBrightness: Double
    var linkedColorTemperature: Double
    var windowPosition: String
    var windows: [WindowSnapshot]
}

// MARK: - Window position mode

enum WindowPosition: String {
    case normal, floatOnTop, pinToBack
}

// MARK: - Window manager

class WindowManager: ObservableObject {
    static private(set) var instance: WindowManager?

    @Published var openWindowCount: Int = 0
    @Published var position: WindowPosition {
        didSet {
            apply()
            saveSession()
        }
    }

    @Published var linked: Bool = true
    @Published var linkedBrightness: Double = 1.0
    @Published var linkedColorTemperature: Double = 6500
    @Published var showControls: Bool = false  // shared panel visibility when linked

    var pendingSnapshots: [WindowSnapshot] = []
    private var sliderValues: [ObjectIdentifier: (brightness: Double, colorTemperature: Double)] = [:]

    // Tracks the active (key) window's current values; used to seed new windows
    private(set) var seedBrightness: Double = 1.0
    private(set) var seedColorTemperature: Double = 6500

    func updateSeed(brightness: Double, colorTemperature: Double) {
        seedBrightness = brightness
        seedColorTemperature = colorTemperature
    }

    init() {
        let session = WindowManager.loadSession()

        // Single assignment so didSet doesn't fire with empty window data
        let rawPosition = session?.windowPosition
            ?? UserDefaults.standard.string(forKey: "windowPosition")
            ?? "normal"
        position = WindowPosition(rawValue: rawPosition) ?? .normal

        if let session {
            linked = session.linked
            linkedBrightness = session.linkedBrightness
            linkedColorTemperature = session.linkedColorTemperature
            pendingSnapshots = session.windows
        }

        WindowManager.instance = self
    }

    func nextSnapshot() -> WindowSnapshot? {
        pendingSnapshots.isEmpty ? nil : pendingSnapshots.removeFirst()
    }

    func updateSnapshot(for window: NSWindow, brightness: Double, colorTemperature: Double) {
        sliderValues[ObjectIdentifier(window)] = (brightness, colorTemperature)
        saveSession()
    }

    func saveSession() {
        let windows: [WindowSnapshot] = NSApplication.shared.windows
            .filter { !($0 is NSPanel) }
            .compactMap { win in
                guard let v = sliderValues[ObjectIdentifier(win)] else { return nil }
                let f = win.frame
                return WindowSnapshot(x: f.origin.x, y: f.origin.y,
                                      width: f.width, height: f.height,
                                      brightness: v.brightness,
                                      colorTemperature: v.colorTemperature)
            }
        let session = SessionSnapshot(linked: linked,
                                      linkedBrightness: linkedBrightness,
                                      linkedColorTemperature: linkedColorTemperature,
                                      windowPosition: position.rawValue,
                                      windows: windows)
        guard let data = try? JSONEncoder().encode(session),
              let json = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(json, forKey: "windowSnapshots")
    }

    private static func loadSession() -> SessionSnapshot? {
        guard let json = UserDefaults.standard.string(forKey: "windowSnapshots"),
              let data = json.data(using: .utf8),
              let session = try? JSONDecoder().decode(SessionSnapshot.self, from: data)
        else { return nil }
        return session
    }

    func apply() {
        for window in NSApplication.shared.windows {
            switch position {
            case .normal:
                window.level = .normal
                window.collectionBehavior = [.fullScreenPrimary]
            case .floatOnTop:
                window.level = .floating
                window.collectionBehavior = [.fullScreenPrimary]
            case .pinToBack:
                window.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
                window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            }
        }
    }
}

// MARK: - App

@main
struct SoftboxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var windowManager = WindowManager()

    var body: some Scene {
        WindowGroup(id: "softbox") {
            ContentView()
                .environmentObject(windowManager)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .help) { }
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) { }
            CommandGroup(replacing: .toolbar) {
                Toggle("Float on Top", isOn: Binding(
                    get: { windowManager.position == .floatOnTop },
                    set: { windowManager.position = $0 ? .floatOnTop : .normal }
                ))
                .keyboardShortcut("t", modifiers: [.command, .option])

                Toggle("Pin to Back", isOn: Binding(
                    get: { windowManager.position == .pinToBack },
                    set: { windowManager.position = $0 ? .pinToBack : .normal }
                ))
                .keyboardShortcut("b", modifiers: [.command, .option])
            }
        }
    }
}

// MARK: - App delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        let ud = UserDefaults.standard
        ud.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("NSWindow Frame") }
            .forEach { ud.removeObject(forKey: $0) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.windows.forEach { $0.setFrameAutosaveName("") }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

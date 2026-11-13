import AppKit
import SwiftUI
import SnowfallCore

final class SnowSettings: ObservableObject {
    @Published var enabled = true { didSet { changed() } }
    @Published var intensity: Double { didSet { changed() } }
    @Published var wind: Double { didSet { changed() } }
    @Published var accumulation: Bool { didSet { changed() } }
    @Published var lowPower: Bool { didSet { changed() } }
    var onChange: (() -> Void)?
    init() {
        let defaults = UserDefaults.standard
        intensity = defaults.object(forKey: "intensity") as? Double ?? 0.5
        wind = defaults.object(forKey: "wind") as? Double ?? 0.12
        accumulation = defaults.object(forKey: "accumulation") as? Bool ?? true
        lowPower = defaults.object(forKey: "lowPower") as? Bool ?? false
    }
    private func changed() {
        let defaults = UserDefaults.standard
        defaults.set(intensity, forKey: "intensity")
        defaults.set(wind, forKey: "wind")
        defaults.set(accumulation, forKey: "accumulation")
        defaults.set(lowPower, forKey: "lowPower")
        onChange?()
    }
}

struct ControlPanel: View {
    @ObservedObject var settings: SnowSettings
    var clear: () -> Void
    var quit: () -> Void
    private let ink = Color(red: 0.13, green: 0.21, blue: 0.32)
    private let accent = Color(red: 0.22, green: 0.43, blue: 0.64)
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SNOWFALL").font(.system(size: 10, weight: .semibold, design: .rounded)).tracking(3).foregroundStyle(accent)
                    Text("给桌面，下场雪。").font(.system(size: 24, weight: .semibold)).foregroundStyle(ink)
                }
                Spacer()
                Image(systemName: "snowflake").font(.system(size: 31, weight: .ultraLight)).foregroundStyle(accent.opacity(0.75)).rotationEffect(.degrees(-10))
            }
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [Color(red: 0.15, green: 0.25, blue: 0.37), Color(red: 0.28, green: 0.42, blue: 0.54)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Canvas { context, size in
                    for i in 0..<36 {
                        let x = CGFloat((i * 83 + 17) % 307) / 307 * size.width
                        let y = CGFloat((i * 47 + 13) % 113) / 113 * size.height
                        let r = CGFloat(i % 3 + 1) * 0.65
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(.white.opacity(Double(i % 4 + 2) / 6)))
                    }
                    var hill = Path()
                    hill.move(to: CGPoint(x: 0, y: size.height - 11))
                    hill.addCurve(to: CGPoint(x: size.width, y: size.height - 13), control1: CGPoint(x: size.width * 0.3, y: size.height - 27), control2: CGPoint(x: size.width * 0.65, y: size.height + 2))
                    hill.addLine(to: CGPoint(x: size.width, y: size.height)); hill.addLine(to: CGPoint(x: 0, y: size.height)); hill.closeSubpath()
                    context.fill(hill, with: .color(Color(red: 0.91, green: 0.96, blue: 0.99)))
                }.clipShape(RoundedRectangle(cornerRadius: 16))
                VStack(spacing: 7) {
                    Text(settings.enabled ? "此刻，正在下雪" : "雪停了，安静一会儿").font(.system(size: 14, weight: .medium))
                    Text("雪落在窗沿，工作照常。").font(.system(size: 11)).opacity(0.7)
                }.foregroundStyle(.white)
            }.frame(height: 111)
            HStack {
                Label("桌面飘雪", systemImage: "sparkles").font(.system(size: 13, weight: .medium))
                Spacer()
                Toggle("桌面飘雪", isOn: $settings.enabled).labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            VStack(alignment: .leading, spacing: 9) {
                HStack { Text("雪量"); Spacer(); Text(settings.intensity < 0.3 ? "小雪" : settings.intensity > 0.7 ? "大雪" : "漫天飞雪").foregroundStyle(accent) }
                Slider(value: $settings.intensity, in: 0...1).tint(accent).accessibilityLabel("雪量")
                HStack { Text("轻轻飘落"); Spacer(); Text("大雪纷飞") }.font(.system(size: 10)).foregroundStyle(.secondary)
            }.font(.system(size: 12))
            VStack(alignment: .leading, spacing: 7) {
                HStack { Text("风向与风力"); Spacer(); Text(abs(settings.wind) < 0.1 ? "微风" : settings.wind < 0 ? "← 向左" : "向右 →").foregroundStyle(accent) }
                Slider(value: $settings.wind, in: -1...1).tint(accent).accessibilityLabel("风向与风力")
            }.font(.system(size: 12))
            Divider().opacity(0.6)
            VStack(spacing: 12) {
                Toggle(isOn: $settings.accumulation) { Label("在窗沿积雪", systemImage: "rectangle.topthird.inset.filled") }
                Toggle(isOn: $settings.lowPower) { Label("节能模式 · 20 帧", systemImage: "leaf") }
            }.font(.system(size: 12)).toggleStyle(.switch).controlSize(.mini)
            HStack {
                Button(action: clear) { Label("清空积雪", systemImage: "wind") }
                Spacer()
                Button("退出", action: quit)
            }.font(.system(size: 11)).buttonStyle(.borderless).foregroundStyle(accent)
            Text("点击穿透 · 多屏飘雪 · 无需额外权限").font(.system(size: 9)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(width: 340)
        .foregroundStyle(ink)
        .background(LinearGradient(colors: [Color(red: 0.96, green: 0.98, blue: 1), Color(red: 0.89, green: 0.94, blue: 0.97)], startPoint: .top, endPoint: .bottom))
        .environment(\.colorScheme, .light)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SnowSettings()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var overlays: [SnowOverlay] = []
    private var windowTimer: Timer?
    private var suspended = false
    private var lastEnabled = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A menu-bar utility should not steal focus or create a Dock icon.
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "snowflake", accessibilityDescription: "桌面飘雪 Snowfall")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = "桌面飘雪 · 点击调节，右键快速退出"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        let controller = NSHostingController(rootView: ControlPanel(settings: settings,
            clear: { [weak self] in self?.overlays.forEach { $0.snowScene.clearSnow() } },
            quit: { NSApp.terminate(nil) }))
        controller.sizingOptions = [.preferredContentSize]
        popover.contentViewController = controller
        popover.contentSize = controller.view.fittingSize
        settings.onChange = { [weak self] in self?.applySettings() }
        NotificationCenter.default.addObserver(self, selector: #selector(rebuildOverlays), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(suspendSnow), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(suspendSnow), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspace.addObserver(self, selector: #selector(resumeSnow), name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(resumeSnow), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        workspace.addObserver(self, selector: #selector(refreshWindows), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        rebuildOverlays()
        windowTimer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in self?.refreshWindows() }
        RunLoop.main.add(windowTimer!, forMode: .common)
        if !UserDefaults.standard.bool(forKey: "hasLaunched") {
            UserDefaults.standard.set(true, forKey: "hasLaunched")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.showPanel() }
        }
    }

    @objc private func togglePanel() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            let pause = NSMenuItem(title: settings.enabled ? "暂停飘雪" : "继续飘雪", action: #selector(toggleEnabled), keyEquivalent: "")
            pause.target = self; menu.addItem(pause)
            let clear = NSMenuItem(title: "清空积雪", action: #selector(clearSnow), keyEquivalent: "")
            clear.target = self; menu.addItem(clear)
            menu.addItem(.separator())
            let quit = NSMenuItem(title: "退出桌面飘雪", action: #selector(quit), keyEquivalent: "q")
            quit.target = self; menu.addItem(quit)
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else if popover.isShown { popover.performClose(nil) } else { showPanel() }
    }
    private func showPanel() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return false
    }
    @objc private func toggleEnabled() { settings.enabled.toggle() }
    @objc private func clearSnow() { overlays.forEach { $0.snowScene.clearSnow() } }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func rebuildOverlays() {
        overlays.forEach { $0.snowView.presentScene(nil); $0.close() }
        overlays = NSScreen.screens.map(SnowOverlay.init)
        applySettings()
        refreshWindows()
    }
    private func applySettings() {
        for overlay in overlays {
            overlay.snowScene.apply(intensity: settings.intensity, wind: settings.wind, accumulates: settings.accumulation)
            overlay.snowView.preferredFramesPerSecond = settings.lowPower ? 20 : 30
            overlay.snowView.isPaused = !settings.enabled || suspended
            if settings.enabled && !suspended { overlay.orderFrontRegardless() } else { overlay.orderOut(nil) }
        }
        statusItem.button?.appearsDisabled = !settings.enabled
        if settings.enabled && !lastEnabled { refreshWindows() }
        lastEnabled = settings.enabled
    }
    @objc private func suspendSnow() { suspended = true; applySettings() }
    @objc private func resumeSnow() { suspended = false; rebuildOverlays() }

    @objc private func refreshWindows() {
        guard settings.enabled, settings.accumulation, !suspended,
              let primaryHeight = NSScreen.screens.first?.frame.height,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }
        var windows: [(id: Int, rect: CGRect)] = []
        for item in list {
            guard let layer = item[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = item[kCGWindowOwnerPID as String] as? Int, pid != Int(getpid()),
                  let alpha = item[kCGWindowAlpha as String] as? Double, alpha > 0.1,
                  let id = item[kCGWindowNumber as String] as? Int,
                  let bounds = item[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary), rect.width > 40, rect.height > 30 else { continue }
            windows.append((id, SnowGeometry.appKitRect(rect, primaryHeight: primaryHeight)))
        }
        for overlay in overlays {
            let frame = overlay.screenFrame
            var edges: [WindowEdge] = []
            var occluders: [CGRect] = []
            for window in windows {
                let rect = window.rect
                defer { occluders.append(rect) }
                guard rect.width > 140, rect.height > 70,
                      rect.maxY > frame.minY + 25, rect.maxY < frame.maxY - 16 else { continue }
                let lower = max(frame.minX, rect.minX + 9)
                let upper = min(frame.maxX, rect.maxX - 9)
                guard upper > lower else { continue }
                let spans = SnowGeometry.exposedSpans(edge: Span(lower, upper), y: rect.maxY, occluders: occluders)
                    .map { Span($0.lower - frame.minX, $0.upper - frame.minX) }
                edges.append(WindowEdge(id: "window-\(window.id)", x: lower - frame.minX, y: rect.maxY - frame.minY,
                                        width: upper - lower, spans: spans))
            }
            let screen = NSScreen.screens.first { $0.frame == frame }
            let floorY = max(frame.minY, screen?.visibleFrame.minY ?? frame.minY)
            let floorSpans = SnowGeometry.exposedSpans(edge: Span(frame.minX, frame.maxX), y: floorY, occluders: windows.map(\.rect))
                .map { Span($0.lower - frame.minX, $0.upper - frame.minX) }
            edges.append(WindowEdge(id: "floor", x: 0, y: floorY - frame.minY, width: frame.width, spans: floorSpans, floor: true))
            overlay.snowScene.setEdges(edges)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowTimer?.invalidate()
        overlays.forEach { $0.close() }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

import AppKit
import Combine
import SwiftUI

/// The lamp in the menu bar and the panel under it.
///
/// It closes like a normal menu bar panel: click outside it, press Esc, switch apps,
/// or click the lamp again. The one exception is the few seconds after Start, when
/// Spotify jumps to the front on its own; that shouldn't close the panel, so you can
/// see the new track come in.
@MainActor
final class PanelController: NSObject {
    private let spotify: SpotifyController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let panel = MenuPanel()
    private let model = PanelModel()
    private var holdOpenUntil = Date.distantPast
    private var outsideClickMonitor: Any?
    private var appSwitchObserver: NSObjectProtocol?
    private var refit: AnyCancellable?

    init(spotify: SpotifyController) {
        self.spotify = spotify
        super.init()

        if let button = statusItem.button {
            button.image = LampGlyph.menuBarImage
            button.target = self
            button.action = #selector(toggle)
            // Act on mouse-down, like system menu bar items.
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }

        // The same glass the system's own menu bar panels use; older macOS gets the blur.
        let glass: NSView
        if #available(macOS 26, *) {
            let liquid = NSGlassEffectView()
            liquid.cornerRadius = 13
            glass = liquid
        } else {
            let blur = NSVisualEffectView()
            blur.material = .menu
            blur.blendingMode = .behindWindow
            blur.state = .active
            blur.wantsLayer = true
            blur.layer?.cornerRadius = 13
            blur.layer?.masksToBounds = true
            glass = blur
        }

        let content = PanelRoot(spotify: spotify, model: model,
                                holdOpen: { [weak self] in self?.holdOpen() })
        let hosting = NSHostingView(rootView: content)
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = glass.bounds
        if #available(macOS 26, *), let liquid = glass as? NSGlassEffectView {
            liquid.contentView = hosting
        } else {
            glass.addSubview(hosting)
        }
        // Thin rounded outline, like the system panel's edge. It sits on top of the
        // content, so it must let clicks through.
        let outline = PassThroughView()
        outline.wantsLayer = true
        outline.layer?.cornerRadius = 13
        outline.layer?.borderWidth = 0.5
        outline.layer?.borderColor = NSColor.black.withAlphaComponent(0.35).cgColor
        let container = NSView()
        glass.frame = container.bounds
        glass.autoresizingMask = [.width, .height]
        outline.frame = container.bounds
        outline.autoresizingMask = [.width, .height]
        container.addSubview(glass)
        container.addSubview(outline)
        panel.contentView = container
        panel.onCancel = { [weak self] in
            guard let self else { return }
            if model.editingFocus { model.editingFocus = false } else { close() }
        }
        // Re-measure after anything that can change the content's height:
        // opening/closing the editor, or Spotify's state (track, not running, …).
        refit = model.objectWillChange.merge(with: spotify.objectWillChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak hosting] _ in
                guard let self, let hosting else { return }
                resize(to: hosting.fittingSize)
            }
        resize(to: hosting.fittingSize)
    }

    @objc private func toggle() {
        panel.isVisible ? close() : show()
    }

    private func show() {
        guard let button = statusItem.button, let itemWindow = button.window else { return }
        spotify.refresh()

        // Left edge under the lamp, just below the menu bar, kept on screen.
        let item = itemWindow.convertToScreen(button.convert(button.bounds, to: nil))
        var x = item.minX
        if let screen = itemWindow.screen {
            x = min(x, screen.visibleFrame.maxX - panel.frame.width - 8)
        }
        panel.setFrameTopLeftPoint(NSPoint(x: x, y: item.minY - 4))
        panel.makeKeyAndOrderFront(nil)

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                // Clicks on the lamp also arrive here; toggle() handles those.
                guard let self, !item.contains(NSEvent.mouseLocation) else { return }
                self.close()
            }
        }
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.otherAppActivated() }
        }
    }

    private func close() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        holdOpenUntil = .distantPast
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let appSwitchObserver { NSWorkspace.shared.notificationCenter.removeObserver(appSwitchObserver) }
        outsideClickMonitor = nil
        appSwitchObserver = nil
    }

    /// Spotify comes forward and macOS then hands focus back to the previous app;
    /// neither should close the panel while the new track is starting.
    private func holdOpen() {
        holdOpenUntil = Date().addingTimeInterval(3)
        Task {
            try? await Task.sleep(for: .seconds(3.1))
            // Take keyboard focus back so Esc and space work again.
            if panel.isVisible { panel.makeKey() }
        }
    }

    private func otherAppActivated() {
        if Date() < holdOpenUntil { return }
        close()
    }

    /// Grow or shrink with the content (e.g. the playlist editor), keeping the top edge fixed.
    private func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let top = panel.frame.maxY
        panel.setFrame(NSRect(x: panel.frame.minX, y: top - size.height, width: size.width, height: size.height),
                       display: true)
    }
}

/// A borderless, non-activating panel: it takes clicks and typing without pulling
/// focus away from the app you're in, like Spotlight.
final class MenuPanel: NSPanel {
    var onCancel: () -> Void = {}

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 300, height: 260),
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        // The glass draws its own rounded edge; a window shadow would outline the square frame.
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }

    /// Esc. (Inside the playlist editor, its own Cancel button handles Esc first.)
    override func cancelOperation(_ sender: Any?) { onCancel() }
}

/// The panel's content at its natural size. (A named type rather than `.fixedSize()`
/// inline, which trips a linker bug when the hosting view is captured weakly.)
private struct PanelRoot: View {
    let spotify: SpotifyController
    let model: PanelModel
    let holdOpen: () -> Void

    var body: some View {
        PopoverView(spotify: spotify, model: model, holdOpen: holdOpen).fixedSize()
    }
}

/// A purely decorative view that never takes clicks.
private final class PassThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

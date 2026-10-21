import ServiceManagement
import SwiftUI

@main
struct DeskFMApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var spotify = SpotifyController()

    init() {
        // `build.sh --install` launches with this flag to turn on launch at login.
        if CommandLine.arguments.contains("--enable-login-item") {
            do { try SMAppService.mainApp.register() } catch { NSLog("Desk FM launch-at-login error: \(error)") }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(spotify: spotify)
        } label: {
            Image(nsImage: LampGlyph.menuBarImage)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar apps have no Edit menu, so ⌘C/⌘V/⌘A do nothing in text fields
        // without one. It's never shown; it only provides the key equivalents.
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem()
        editItem.submenu = edit
        let main = NSMenu()
        main.addItem(editItem)
        NSApp.mainMenu = main
    }
}

struct PopoverView: View {
    @ObservedObject var spotify: SpotifyController
    @AppStorage("focusURI") private var focusURI = "spotify:playlist:37i9dQZF1DWZeKCadgRdKQ"
    @AppStorage("focusName") private var focusName = "Deep Focus"
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var editingFocus = false
    @State private var linkDraft = ""
    @State private var nameDraft = ""
    @State private var linkError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if spotify.needsPermission {
                permissionNeeded
            } else if spotify.state == .notInstalled {
                notInstalled
            } else {
                if let track = spotify.track, spotify.state != .notRunning {
                    nowPlaying(track)
                    ProgressBar(spotify: spotify, duration: track.duration)
                    controls
                } else {
                    notRunning
                }
                if editingFocus { focusEditor } else { focusButton }
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
        .onAppear { spotify.refresh() }
    }

    private func nowPlaying(_ track: Track) -> some View {
        HStack(spacing: 12) {
            Group {
                if let art = spotify.artwork {
                    Image(nsImage: art).resizable()
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name).font(.headline).lineLimit(1)
                Text([track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 22) {
            Button(action: spotify.toggleShuffle) {
                Image(systemName: "shuffle")
                    .foregroundStyle(spotify.shuffling ? Color.green : Color.secondary)
            }
            Button(action: spotify.previous) { Image(systemName: "backward.fill") }
            Button(action: spotify.playPause) {
                Image(systemName: spotify.state == .playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 38))
            }
            .keyboardShortcut(editingFocus ? nil : KeyboardShortcut(.space, modifiers: []))
            Button(action: spotify.next) { Image(systemName: "forward.fill") }
            Button(action: spotify.openSpotify) {
                Image(systemName: "arrow.up.forward.app").foregroundStyle(.secondary)
            }
            .help("Open Spotify")
        }
        .font(.system(size: 16))
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var focusButton: some View {
        Button { spotify.play(uri: focusURI) } label: {
            Label("Start \(focusName)", systemImage: "headphones")
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 0.11, green: 0.73, blue: 0.33))
    }

    private var notRunning: some View {
        VStack(spacing: 10) {
            Text("Spotify isn't running").font(.headline)
            Button("Resume last track") { spotify.playPause() }
                .keyboardShortcut(editingFocus ? nil : .defaultAction)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var permissionNeeded: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Desk FM can't control Spotify", systemImage: "lock")
                .font(.headline)
            Text("Turn on Spotify under Desk FM in System Settings → Privacy & Security → Automation.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Open System Settings", action: spotify.openAutomationSettings)
                    .buttonStyle(.borderedProminent)
                Button("Try again", action: spotify.refresh)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var notInstalled: some View {
        VStack(spacing: 10) {
            Text("Spotify isn't installed").font(.headline)
            Text("Desk FM controls the Spotify desktop app.")
                .font(.caption).foregroundStyle(.secondary)
            Link("Download Spotify", destination: URL(string: "https://www.spotify.com/download/mac/")!)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var focusEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Focus playlist").font(.headline)
                Text("In Spotify, right-click a playlist or album, then Share → Copy link.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Link").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    TextField("https://open.spotify.com/playlist/…", text: $linkDraft)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: linkDraft) { _, _ in linkError = nil }
                    Button {
                        if let s = NSPasteboard.general.string(forType: .string) { linkDraft = s }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .help("Paste link")
                }
                if let linkError {
                    Text(linkError).font(.caption).foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Button name").font(.caption).foregroundStyle(.secondary)
                TextField("Deep Focus", text: $nameDraft)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel") { editingFocus = false }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: saveFocus)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private var footer: some View {
        HStack {
            Spacer()
            Menu {
                Button("Change focus playlist…", action: startEditingFocus)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                Divider()
                Button("Quit Desk FM") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .foregroundStyle(.secondary)
    }

    private func startEditingFocus() {
        // Prefill with a Spotify link from the clipboard if there is one, else the current playlist.
        let clip = NSPasteboard.general.string(forType: .string) ?? ""
        if SpotifyController.uri(fromLink: clip) != nil, !clip.hasPrefix("spotify:") {
            linkDraft = clip
        } else {
            let parts = focusURI.split(separator: ":")
            linkDraft = parts.count == 3 ? "https://open.spotify.com/\(parts[1])/\(parts[2])" : focusURI
        }
        nameDraft = focusName
        linkError = nil
        editingFocus = true
    }

    private func saveFocus() {
        guard let uri = SpotifyController.uri(fromLink: linkDraft) else {
            linkError = "That isn't a Spotify playlist or album link."
            return
        }
        focusURI = uri
        let name = nameDraft.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { focusName = name }
        editingFocus = false
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Desk FM launch-at-login error: \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

struct ProgressBar: View {
    @ObservedObject var spotify: SpotifyController
    let duration: Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let pos = spotify.position(at: context.date)
            HStack(spacing: 8) {
                Text(format(pos)).monospacedDigit()
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule().fill(.secondary)
                            .frame(width: duration > 0 ? geo.size.width * pos / duration : 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { point in
                        guard duration > 0 else { return }
                        spotify.seek(to: duration * point.x / geo.size.width)
                    }
                }
                .frame(height: 4)
                Text(format(duration)).monospacedDigit()
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    private func format(_ s: Double) -> String {
        let t = Int(s.rounded(.down))
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

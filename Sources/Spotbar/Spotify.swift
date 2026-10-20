import AppKit
import Foundation

struct Track: Equatable {
    var id: String
    var name: String
    var artist: String
    var album: String
    var duration: Double      // seconds
    var artworkURL: URL?
}

/// Talks to the Spotify desktop app directly via AppleScript, so it keeps working
/// after macOS drops Spotify from its system Now Playing session.
@MainActor
final class SpotifyController: ObservableObject {
    enum State: String { case playing, paused, stopped, notRunning }

    @Published private(set) var state: State = .notRunning
    @Published private(set) var track: Track?
    @Published private(set) var shuffling = false
    @Published private(set) var artwork: NSImage?

    // Position is extrapolated locally between refreshes.
    private var positionAnchor: Double = 0
    private var anchorDate = Date()

    private var timer: Timer?
    private let bundleID = "com.spotify.client"

    init() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard app?.bundleIdentifier == "com.spotify.client" else { return }
                Task { @MainActor in
                    // Spotify takes a moment to answer AppleScript after launch.
                    try? await Task.sleep(for: .seconds(1.5))
                    self?.refresh()
                }
            }
        }
        // Light safety-net poll; notifications do most of the work.
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    func position(at date: Date) -> Double {
        guard state == .playing else { return positionAnchor }
        let p = positionAnchor + date.timeIntervalSince(anchorDate)
        return min(p, track?.duration ?? p)
    }

    // MARK: - Commands

    func playPause() {
        // `play` launches Spotify if needed and resumes the last track.
        run(state == .playing ? "tell application \"Spotify\" to pause"
                              : "tell application \"Spotify\" to play")
        refreshSoon()
    }

    /// Plays a playlist/album by `spotify:` URI, launching Spotify first if needed.
    /// Spotify brings its window to the front whenever it's told to play a URI,
    /// so it gets hidden again; macOS then hands focus back to the previous app.
    func play(uri: String) {
        let script = "tell application \"Spotify\" to play track \"\(uri)\""
        if isRunning {
            run(script)
            keepSpotifyInBackground()
            refreshSoon()
            return
        }
        launchSpotifyInBackground()
        Task {
            // Spotify ignores play commands until it has finished starting up.
            for _ in 0..<10 {
                try? await Task.sleep(for: .seconds(1))
                guard isRunning else { continue }
                run(script)
                try? await Task.sleep(for: .milliseconds(500))
                refresh()
                if state == .playing { break }
            }
            keepSpotifyInBackground()
        }
    }

    private func launchSpotifyInBackground() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.hides = true
        NSWorkspace.shared.openApplication(at: url, configuration: config)
    }

    /// Spotify raises itself a beat after the command, so watch for ~2.5s.
    /// Hiding (rather than activating the previous app) is what reliably works:
    /// macOS won't let a background app hand focus to another app.
    private func keepSpotifyInBackground() {
        Task {
            // Poll fast so the window is hidden within a frame or two of appearing.
            for _ in 0..<100 {
                try? await Task.sleep(for: .milliseconds(25))
                guard let spotify = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
                else { return }
                if spotify.isActive { spotify.hide() }
            }
        }
    }

    /// Accepts a share link (https://open.spotify.com/playlist/ID?si=…) or a spotify: URI.
    static func uri(fromLink link: String) -> String? {
        let s = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("spotify:") { return s }
        guard let url = URL(string: s), url.host?.hasSuffix("spotify.com") == true else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" && !$0.hasPrefix("intl-") }
        guard parts.count >= 2, ["playlist", "album"].contains(parts[0]) else { return nil }
        return "spotify:\(parts[0]):\(parts[1])"
    }

    func next() { run("tell application \"Spotify\" to next track"); refreshSoon() }

    func previous() { run("tell application \"Spotify\" to previous track"); refreshSoon() }

    func toggleShuffle() {
        run("tell application \"Spotify\" to set shuffling to not shuffling")
        refreshSoon()
    }

    func seek(to seconds: Double) {
        run("tell application \"Spotify\" to set player position to \(Int(seconds))")
        positionAnchor = seconds
        anchorDate = Date()
        objectWillChange.send()
    }

    func openSpotify() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    // MARK: - State

    func refresh() {
        // Never query when Spotify is closed: `tell application` would launch it.
        guard isRunning else {
            state = .notRunning
            return
        }
        let script = """
        tell application "Spotify"
            set out to (player state as string)
            try
                set t to current track
                set out to out & linefeed & (id of t) & linefeed & (name of t) & linefeed & (artist of t) ¬
                    & linefeed & (album of t) & linefeed & (duration of t) & linefeed & (player position) ¬
                    & linefeed & (artwork url of t) & linefeed & (shuffling as string)
            end try
            return out
        end tell
        """
        guard let output = run(script) else { return }
        let parts = output.components(separatedBy: "\n")

        state = State(rawValue: parts[0]) ?? .stopped

        guard parts.count >= 9 else { track = nil; return }
        let newTrack = Track(
            id: parts[1], name: parts[2], artist: parts[3], album: parts[4],
            duration: (Double(parts[5]) ?? 0) / 1000,
            artworkURL: URL(string: parts[7])
        )
        positionAnchor = Double(parts[6].replacingOccurrences(of: ",", with: ".")) ?? 0
        anchorDate = Date()
        shuffling = parts[8] == "true"

        if newTrack.artworkURL != track?.artworkURL { loadArtwork(newTrack.artworkURL) }
        track = newTrack
    }

    private func refreshSoon() {
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            refresh()
        }
    }

    private func loadArtwork(_ url: URL?) {
        guard let url else { artwork = nil; return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            if track?.artworkURL == url { artwork = NSImage(data: data) }
        }
    }

    @discardableResult
    private func run(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { NSLog("Spotbar AppleScript error: \(error)") }
        return result?.stringValue
    }
}

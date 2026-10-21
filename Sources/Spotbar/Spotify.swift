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
    enum State: String { case playing, paused, stopped, notRunning, notInstalled }

    @Published private(set) var state: State = .notRunning
    /// The user clicked "Don't Allow" on the Automation prompt (or turned it off later).
    /// macOS never asks again, so they have to re-enable it in System Settings.
    @Published private(set) var needsPermission = false
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

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
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
        if state == .playing {
            run("tell application \"Spotify\" to pause")
            refreshSoon()
        } else {
            // Resumes the last track; launches Spotify in the background if it's closed.
            play(script: "tell application \"Spotify\" to play")
        }
    }

    /// Plays a playlist/album by `spotify:` URI, launching Spotify first if needed.
    /// Spotify brings its window to the front whenever it's told to play a URI,
    /// so it gets hidden again; macOS then hands focus back to the previous app.
    func play(uri: String) {
        play(script: "tell application \"Spotify\" to play track \"\(uri)\"")
    }

    private func play(script: String) {
        guard isInstalled else { state = .notInstalled; return }
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
                if needsPermission { break }
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

    func openAutomationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
    }

    func openSpotify() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    // MARK: - State

    func refresh() {
        // Never query when Spotify is closed: `tell application` would launch it.
        guard isRunning else {
            state = isInstalled ? .notRunning : .notInstalled
            return
        }
        // Each field is read on its own so a podcast, ad or local file missing one
        // (artwork, album…) still shows the rest.
        let script = """
        tell application "Spotify"
            set out to (player state as string)
            set {tid, tname, tartist, talbum, tdur, tart} to {"", "", "", "", "0", ""}
            set {tpos, tshuf} to {"0", "false"}
            try
                set t to current track
                try
                    set tid to (id of t) as string
                end try
                try
                    set tname to (name of t) as string
                end try
                try
                    set tartist to (artist of t) as string
                end try
                try
                    set talbum to (album of t) as string
                end try
                try
                    set tdur to (duration of t) as string
                end try
                try
                    set tart to (artwork url of t) as string
                end try
            end try
            try
                set tpos to (player position) as string
            end try
            try
                set tshuf to (shuffling) as string
            end try
            if tid is "" then return out
            return out & linefeed & tid & linefeed & tname & linefeed & tartist & linefeed & talbum ¬
                & linefeed & tdur & linefeed & tpos & linefeed & tart & linefeed & tshuf
        end tell
        """
        guard let output = run(script) else { return }
        let parts = output.components(separatedBy: "\n")

        state = State(rawValue: parts[0]) ?? .stopped

        guard parts.count >= 9 else { track = nil; artwork = nil; return }
        let art = parts[7].hasPrefix("http") ? URL(string: parts[7]) : nil
        let newTrack = Track(
            id: parts[1],
            name: parts[2].isEmpty ? "Unknown" : parts[2],
            artist: parts[3], album: parts[4],
            duration: (Double(parts[5]) ?? 0) / 1000,
            artworkURL: art
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
        if let error {
            NSLog("Spotbar AppleScript error: \(error)")
            // -1743: the user denied Spotbar permission to control Spotify.
            if (error[NSAppleScript.errorNumber] as? Int) == -1743 { needsPermission = true }
            return nil
        }
        needsPermission = false
        return result?.stringValue
    }
}

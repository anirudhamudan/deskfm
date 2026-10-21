# Desk FM

A radio station for your desk: Spotify controls that never leave your Mac's menu bar,
and one click to start your focus playlist.

I kept losing the Now Playing widget: after Spotify has been paused for a while, macOS
forgets it, the widget disappears, and the play key opens Apple Music instead. Then
it's a trip to the Dock just to hit play. Desk FM talks to the Spotify app directly, so
the controls are always one click away no matter what macOS thinks is "now playing".

## Features

- A little desk lamp in your menu bar that never goes away
- Current track, artwork, and a progress bar you can click to seek
- Play/pause, previous, next, shuffle, open Spotify
- **Start Deep Focus**: one click to start your go-to playlist, even if Spotify is
  closed. Point it at any playlist or album from the gear menu.
- Launch at login
- Works on Apple Silicon and Intel Macs, macOS 14 Sonoma or later

## Install

1. Download `DeskFM-<version>.zip` from the
   [latest release](https://github.com/anirudhamudan/deskfm/releases/latest) and unzip it.
2. Drag **Desk FM.app** into your **Applications** folder.
3. Open it. macOS will block it, because the app isn't signed with a paid Apple
   developer certificate. To allow it:
   - Open **System Settings → Privacy & Security**.
   - Scroll down to the message about Desk FM and click **Open Anyway**, then confirm.

   Or, in Terminal:

   ```bash
   xattr -dr com.apple.quarantine "/Applications/Desk FM.app"
   ```

4. When macOS asks whether Desk FM can control Spotify, click **Allow**. Without this,
   nothing works.
5. Look for the lamp in your menu bar. To start it automatically, open the gear menu in
   the panel and turn on **Launch at login**.

You need the Spotify desktop app installed. Desk FM doesn't use your Spotify account
or the internet, except to load album artwork.

### If something's off

- **The panel says "Desk FM can't control Spotify."** You clicked Don't Allow, and
  macOS won't ask again. Turn it back on in System Settings → Privacy & Security →
  Automation → Desk FM → Spotify.
- **The Spotify window flashes when you click Start.** That's Spotify: it brings
  itself to the front whenever it's told to play a playlist, and Desk FM hides it
  again straight away. Plain play/pause doesn't do this.
- **The lamp isn't in the menu bar.** On MacBooks with a notch, macOS hides menu bar
  icons that don't fit. Quit an app you don't need up there, or use a menu bar manager.

## Uninstall

Quit Desk FM from the gear menu, then drag it from Applications to the Trash.

## Build from source

Needs Xcode (or the Swift toolchain) on macOS 14 or later.

```bash
./build.sh --install
```

That builds `Desk FM.app`, copies it to `/Applications`, launches it, and turns on
launch at login. `./build.sh` alone only builds into `build/`, and `./build.sh --release`
also makes the zip that goes on GitHub releases.

## How it works

Desk FM sends AppleScript commands to the Spotify app and listens for Spotify's own
"playback changed" notifications. It doesn't go through macOS's Now Playing system,
which is the part that keeps forgetting Spotify.

## License

MIT. Desk FM isn't affiliated with or endorsed by Spotify.

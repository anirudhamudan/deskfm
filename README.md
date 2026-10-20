# Spotbar

A tiny macOS menu bar app for Spotify that's always there.

macOS's Now Playing widget forgets Spotify after it's been paused for a while, and the
play key starts opening Apple Music instead. Spotbar talks to the Spotify desktop app
directly (AppleScript), so the controls keep working no matter what macOS thinks is
"now playing".

## Features

- Spotify icon permanently in the menu bar
- Current track, artwork, progress bar (click to seek)
- Play/pause, previous, next, shuffle, open Spotify
- **Start Deep Focus** — one click to start a chosen playlist, even if Spotify is closed.
  Change the playlist from the gear menu (paste any Spotify playlist or album link).
- Launch at login

## Requirements

- macOS 14 or later
- Spotify desktop app
- Xcode or the Swift toolchain, to build

## Build and install

```bash
./build.sh --install
```

This builds `Spotbar.app`, copies it to `/Applications`, launches it, and turns on
launch at login. Use `./build.sh` alone to only build into `build/`.

On first use macOS asks for permission to let Spotbar control Spotify. Click Allow.
Because the app is ad-hoc signed, macOS may ask again after each rebuild.

## Known limitations

- Starting a playlist briefly flashes the Spotify window. Spotify brings itself to the
  front whenever it's told to play a specific playlist; Spotbar hides it again
  immediately. Avoiding it entirely would need the Spotify Web API.
- AppleScript only exposes the current track, so there's no recently played list yet.

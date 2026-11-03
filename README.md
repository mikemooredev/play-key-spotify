# play-key-spotify

Makes the Mac Play key open Spotify instead of Apple Music.

## What it does

- Spotify is closed: opens Spotify and starts playing. Apple Music does not open.
- Spotify is open: lets the key through, so Spotify plays or pauses as normal.

It listens for media key presses with a macOS event tap (a hook that sees key presses before other apps do). When Spotify is closed, it stops the Play key from reaching Apple Music.

## Requirements

- macOS. Built and tested on macOS 14.5 (Apple silicon).
- The Spotify desktop app.
- The Swift compiler. Install it with `xcode-select --install` if you do not have it.

## Build

```
swiftc -O main.swift -o play-key-spotify
```

## Run

```
./play-key-spotify
```

On first run, macOS asks for two permissions:

- Accessibility: allow the program in System Settings, Privacy & Security, Accessibility. The program exits if this is off.
- Automation: allow it to control Spotify. This lets it press play after Spotify opens.

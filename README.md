# PixelClaw

Built PixelClaw because I got bored waiting for Claude Code. It’s a tiny pixel
crab that lives on your Dock, sleeps, wakes on click, and chases apples you
drop.

[![PixelClaw preview](Docs/Assets/video.png)](https://www.youtube.com/watch?v=ni-iOwVd1R0)

## Quick Install

Homebrew:

```sh
brew install masasron/tap/pixelclaw
```

That downloads and opens the latest DMG from GitHub. Then drag `PixelClaw.app`
into `Applications`.

Direct download:

```sh
curl -fL https://github.com/masasron/PixelClaw/releases/download/v1.0.0/PixelClaw.dmg -o PixelClaw.dmg
open PixelClaw.dmg
```

## Requirements

- macOS 12 or later
- Swift 5.9+ toolchain or Xcode with Swift Package Manager support

## Build

```sh
make
```

To run the app:

```sh
make run
```

To build a launchable macOS app bundle:

```sh
make app
open Dist/PixelClaw.app
```

To build a release zip:

```sh
make zip
```

To build a DMG for distribution:

```sh
make dmg
```

To launch with debug logging enabled:

```sh
make debug
```

You can also build directly with Swift Package Manager:

```sh
swift build
swift run PixelClaw --debug
```

## Permissions

PixelClaw uses Accessibility access to read your Dock position and respond to
clicks. The first time you launch it, macOS may ask for permission. If your pet
is not lining up with the Dock correctly, check
`System Settings > Privacy & Security > Accessibility`.

## Controls

- `Option+F`: drop an apple
- Click your pet while it is awake: make it hop in place
- Click your pet while it is sleeping: wake it up
- Click an apple: toss it again

## Project Layout

- `Package.swift`: Swift Package Manager manifest
- `Sources/PixelClaw/Support`: constants, sprite data, shared models, Dock
  geometry helpers
- `Sources/PixelClaw/Views`: AppKit drawing code for the crab, apples, and floor
  shadow
- `Sources/PixelClaw/App`: application state, animation loop, interaction logic,
  and entry point
- `Docs/ARCHITECTURE.md`: high-level structure for contributors

## License

This project is licensed under the [MIT License](LICENSE).

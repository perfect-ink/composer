# AGENTS.md — Composer

Composer is a native SwiftUI macOS app for learning music theory and sketching music: chord progressions, rhythm, MIDI export, circle of fifths, scales, a chord dictionary, and a piano. It has no third-party dependencies. See [README.md](README.md) for the feature list.

## Commands

Requires Xcode 15+. `make setup` installs XcodeGen if it's missing.

- `make` (`make setup dev`): generate `Composer.xcodeproj` from `project.yml` (the project is git-ignored), build Debug into `build/`, and open it.
- `make build`: Release build. `make install` / `make uninstall` / `make reinstall` / `make install-open`: manage `/Applications`.
- `make open` / `make close` / `make clean`; `make help` lists everything.
- `make appstore`, `make metadata VERSION=…`, `make submit VERSION=…`: the Mac App Store build and listing (see `docs/app-store/README.md`).

There is no test target yet.

## Layout

- `Sources/Theory/`: pure music-theory models (`Note`, `Interval`, `Scale`, `Chord`, `Key`, `Progression`, `Rhythm`). Keep these free of UI and audio code.
- `Sources/Audio/`: `AVAudioEngine` playback using the system General MIDI soundbank, plus the metronome.
- `Sources/MIDI/`: the hand-written Standard MIDI File writer and exporter.
- `Sources/Views/`: one view per section; reusable pieces are in `Views/Components/`.
- `Sources/AppState.swift`: shared app state.

## Conventions

- Edit `project.yml`, not the generated project. New files under `Sources/` are picked up on `xcodegen generate`.
- Theory code should stay deterministic and side-effect free, so it can get unit tests later.

## Design principles

Follow the [design principles](docs/rules/design-principles.md) for any UI work.

## After changing code

1. `make dev`

Commit messages are one short, imperative line, like the existing history.

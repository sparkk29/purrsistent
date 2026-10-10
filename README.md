<p align="center">
  <img src="assets/logo.png" alt="Purrsistent logo" width="180">
</p>

<h1 align="center">Purrsistent</h1>

<p align="center">A tiny cat that lives on your Mac desktop and never quite leaves.</p>

---

Purrsistent is a native macOS desktop pet. A small animated cat strolls along the top of your Dock, naps, meows, and reacts when you poke or pick it up. It lives in a transparent, always-on-top window, so it stays out of your way: clicks on the empty space around it go straight through to the apps underneath.

## Features

- **Lives on your desktop**: walks along the top of the Dock (or the bottom of the screen), turns around at the edges, and shows up on every Space and over full-screen apps.
- **Has a mind of its own**: idles, sits, and wanders at random, and dozes off after about 2 minutes without attention.
- **Responds to you**: click it for a happy jump and a meow, or drag it anywhere and let go to watch it fall back down.
- **Sounds**: meows, a surprised chirp when picked up, a thud on landing, and a soft purr while asleep.
- **Stays out of the way**: no Dock icon, and clicks on transparent pixels pass through.
- **Menu bar controls**: everything is in the paw icon in the menu bar (or right-click the cat).
- **Customizable**: replace the artwork and sounds with your own files without touching code.

## Requirements

- macOS 13 Ventura or later
- Swift 5.9 or later. The Xcode Command Line Tools are enough (`xcode-select --install`); full Xcode isn't required.

## Build and run

```bash
./scripts/bundle.sh
open build/Purrsistent.app
```

`bundle.sh` builds a release binary, generates the app icon, copies the sprites and sounds, and wraps everything into an ad-hoc signed `build/Purrsistent.app`. Move it to `/Applications` if you want to keep it.

For quick iteration during development you can also run it unbundled from the repo root:

```bash
swift run
```

## Using Purrsistent

| Action | What happens |
| --- | --- |
| Click the cat | Happy jump and a meow |
| Drag the cat | It dangles, then falls back down when released |
| Right-click (or Control-click) the cat | Opens the settings menu |
| Leave it alone for ~2 minutes | It falls asleep and purrs |

The menu bar icon and the right-click menu offer the same options:

- **Show / Hide Pet**
- **Size**: Small, Medium, Large
- **Speed**: Slow, Normal, Fast
- **Stay Still**: no walking, just idling, sitting, and sleeping
- **Sounds** on/off and **Volume**: Low, Medium, High
- **Launch at Login**: only works from the bundled `.app`
- **Quit**

Settings are saved between launches.

## Custom artwork and sounds

Purrsistent ships with a placeholder cat and sounds that are drawn and synthesized in code. They're also exported as files in `Resources/`, and any files you put there take priority.

### Sprites (`Resources/Sprites/`)

Animations: `idle`, `walk`, `sit`, `sleep`, `drag`, `fall`, `happy`.

- Use a PNG sequence (`walk_0.png`, `walk_1.png`, ...) or a single horizontal strip of square frames (`walk.png`).
- Draw the character **facing right**. Left-facing frames are mirrored automatically.
- Transparent pixels are click-through, so keep the background fully transparent.

### Sounds (`Resources/Sounds/`)

Effects: `meow`, `chirp`, `thud`, `purr`.

- Supported formats: `.wav`, `.aiff`, `.caf`, `.mp3`, `.m4a`.
- Add variations as `meow_0.wav`, `meow_1.wav`, ... and one is picked at random each time.
- `purr` loops while the cat sleeps, so it should loop cleanly.

After changing assets, run `./scripts/bundle.sh` again.

### Regenerating the defaults

```bash
swift build
.build/debug/Purrsistent --export-sprites Resources/Sprites
.build/debug/Purrsistent --export-sounds Resources/Sounds
.build/debug/Purrsistent --export-logo assets/logo.png
```

## Project structure

```
Sources/Purrsistent/
  main.swift               App entry point and asset-export commands
  AppDelegate.swift        Wires up the pet and the menu bar
  PetWindow.swift          Transparent, always-on-top panel
  PetView.swift            Draws the current frame, mouse handling, pixel hit-testing
  PetController.swift      30 fps loop: movement, gravity, dragging, sound cues
  PetStateMachine.swift    Behaviors and weighted random transitions
  SpriteAnimator.swift     Loads, mirrors, and steps through animation frames
  SpriteFactory.swift      Draws the built-in placeholder cat
  SoundPlayer.swift        Loads and plays sound effects and loops
  SoundFactory.swift       Synthesizes the built-in placeholder sounds
  IconFactory.swift        Draws the app icon and logo
  MenuBarController.swift  Menu bar icon and settings menu
  Settings.swift           Persisted preferences
Resources/
  Sprites/                 Animation frames
  Sounds/                  Sound effects
scripts/bundle.sh          Builds Purrsistent.app
assets/logo.png            Logo used in this README
```

## Roadmap

- Multiple monitors and walking on top of window title bars
- Reacting to the cursor, time of day, and system events like low battery
- More characters and a character picker

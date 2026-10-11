<p align="center">
  <img src="assets/logo.png" alt="Purrsistent logo" width="180">
</p>

<h1 align="center">Purrsistent</h1>

<p align="center">A tiny cat that lives on your Mac desktop and never quite leaves.</p>

---

Purrsistent is a native macOS desktop pet. A small animated cat strolls along the top of your Dock, naps, grooms, meows, and reacts when you stroke it, poke it, or toss it across the screen. It lives in a transparent, always-on-top window, so it stays out of your way: clicks on the empty space around it go straight through to the apps underneath.

<p align="center">
  <img src="assets/coats.png" alt="Orange, Midnight, Silver, and Snowball coats" width="480">
</p>

<p align="center">
  <img src="assets/styles.png" alt="Cartoon, Pixel, Silhouette, and Anime styles" width="640">
</p>

## Features

- **Lives on your desktop**: walks along the top of the Dock (or the bottom of the screen), wanders across to your other monitors, and shows up on every Space and over full-screen apps.
- **Has a mind of its own**: idles, sits, grooms, yawns, scratches an itch, and wanders at random. It loafs when it's bored, dozes off after about 2 minutes without attention (sooner late at night), and wakes up with a big stretch.
- **Plays**: a happy cat kneads, rolls onto its back, and chases its own tail.
- **Notices you**: turns to look at your cursor when it's nearby, and sometimes crouches, wiggles, and pounces at it.
- **Loves attention**: stroke it with the cursor and it closes its eyes and purrs. Click it for a happy hop and a meow.
- **Throwable**: drag it and fling it. It flies, bounces off screen edges, and skids to a stop.
- **Treats and mood**: give it a fish treat and it trots over to eat it. Its mood rises with attention and slowly fades when it's ignored, and a happier cat plays more.
- **Break reminders**: optionally reminds you to stretch, drink water, or rest your eyes, in a little speech bubble.
- **Coats**: Orange, Midnight, Silver, and Snowball, or your own artwork.
- **Styles**: Cartoon, Pixel (chunky 32×32 pixel art), Silhouette (a dark shape with glowing eyes), and Anime (a fluffy kitten with big glossy eyes, cheek tufts, and cel shading). Any style works with any coat.
- **Sounds**: real cat recordings for meows, a surprised chirp, and a soft purr, plus a thud on landing. Pick a voice: Classic, Kitten, or Tomcat.
- **Stays out of the way**: no Dock icon, and clicks on transparent pixels pass through.
- **Menu bar controls**: everything is in the paw icon in the menu bar, or right-click the cat.

## Requirements

- macOS 13 Ventura or later
- Swift 5.9 or later. The Xcode Command Line Tools are enough (`xcode-select --install`); full Xcode isn't required.

## Build and run

```bash
./scripts/bundle.sh
open build/Purrsistent.app
```

`bundle.sh` builds a release binary, generates the app icon, copies any custom sprites and the sounds, and wraps everything into an ad-hoc signed `build/Purrsistent.app`. Move it to `/Applications` if you want to keep it.

For quick iteration during development you can also run it unbundled from the repo root:

```bash
swift run
```

## Using Purrsistent

| Action | What happens |
| --- | --- |
| Move the cursor back and forth over the cat | It purrs and its mood goes up |
| Click the cat | Happy hop and a meow |
| Drag and release (or fling) the cat | It flies, bounces off edges, and lands with a thud |
| Right-click (or Control-click) the cat | Opens the menu |
| Click a speech bubble | Dismisses it |
| Leave it alone for ~2 minutes | It falls asleep and purrs (after ~45 seconds at night) |

The menu bar icon and the right-click menu offer the same options:

- **Show / Hide Pet**
- **Mood**: how the cat is feeling: Grumpy, Bored, Content, or Happy
- **Give Treat**: drops a fish for the cat to find and eat
- **Coat**: Orange, Midnight, Silver, Snowball, plus Custom when you've added your own sprites
- **Style**: Cartoon, Pixel, Silhouette, Anime (not available with the Custom coat)
- **Size**: Small, Medium, Large
- **Speed**: Slow, Normal, Fast
- **Stay Still**: no wandering, pouncing, or tail chasing; it still sits, grooms, stretches, loafs, and sleeps
- **Sounds** on/off
- **Voice**: Classic (a steady adult cat), Kitten (high, squeaky mews), Tomcat (a talkative tom), plus Custom when you've added your own sounds. Picking one plays a sample meow.
- **Volume**: Low, Medium, High
- **Break Reminders**: Off, or every 25, 45, or 60 minutes
- **Launch at Login**: only works from the bundled `.app`
- **Quit**

Settings and mood are saved between launches.

## Custom artwork and sounds

Purrsistent's cat is drawn in code. Its sounds are real recordings in `Resources/Sounds/` (see [Credits](#credits)), with synthesized fallbacks built in, so it still works with no asset files at all. You can swap in your own.

### Sprites (`Resources/Sprites/`)

Put PNGs in `Resources/Sprites/`, rebuild, and pick **Coat → Custom**.

Animations: `idle`, `walk`, `sit`, `sleep`, `drag`, `fall`, `happy`, `petted`, `yawn`, `groom`, `eat`, `stretch`, `scratch`, `knead`, `rollOver`, `loaf`, `pounce` (the crouch and wiggle), `leap`, `tailChase`.

- Use a PNG sequence (`walk_0.png`, `walk_1.png`, ...) or a single horizontal strip of square frames (`walk.png`).
- Any animation you leave out falls back to the built-in cat.
- Draw the character **facing right**. Left-facing frames are mirrored automatically.
- Transparent pixels are click-through, so keep the background fully transparent.

To start from the built-in cat, export its frames (optionally in another coat or style) and edit them:

```bash
swift build
.build/debug/Purrsistent --export-sprites Resources/Sprites --coat silver --style anime
```

### Sounds (`Resources/Sounds/`)

Effects: `meow`, `chirp`, `thud`, `purr`.

Each voice has its own folder (`Classic/`, `Kitten/`, `Tomcat/`). Files in the selected voice's folder win; anything missing there comes from `Resources/Sounds/` itself, which holds the shared `purr` and `thud`. To use your own cat, put its sounds in `Resources/Sounds/Custom/`, rebuild, and pick **Voice → Custom**.

- Supported formats: `.wav`, `.aiff`, `.caf`, `.mp3`, `.m4a`.
- Add variations as `meow_0.wav`, `meow_1.wav`, ... and one is picked at random each time.
- `purr` loops while the cat sleeps or is being stroked, so it should loop cleanly.
- Any effect without a file falls back to a synthesized version.

After changing assets, run `./scripts/bundle.sh` again.

### Regenerating the defaults

```bash
swift build
.build/debug/Purrsistent --export-sounds SynthesizedSounds   # synthesized fallback sounds, for reference
.build/debug/Purrsistent --export-logo assets/logo.png
```

## Project structure

```
Sources/Purrsistent/
  main.swift               App entry point and asset-export commands
  AppDelegate.swift        Wires up the pet and the menu bar
  PetWindow.swift          Transparent, always-on-top panel
  PetView.swift            Draws the current frame, mouse handling, pixel hit-testing
  PetController.swift      30 fps loop: movement, throwing, petting, treats, sound cues
  PetStateMachine.swift    Behaviors and weighted random transitions
  Mood.swift               Persisted mood that fades over time
  Treat.swift              The fish treat
  BubbleWindow.swift       Speech bubble above the pet
  BreakReminder.swift      Break reminder timer and messages
  SpriteAnimator.swift     Loads, mirrors, and steps through animation frames
  SpriteFactory.swift      Draws the built-in cat, its coats and styles, and the treat
  PixelArt.swift           Turns a vector drawing into pixel art
  AnimeCatFactory.swift    Rigged anime kitten: jointed legs, keyframed poses, fur tufts, cel shading
  SoundPlayer.swift        Loads and plays sound effects and loops
  SoundFactory.swift       Synthesizes fallback sounds
  IconFactory.swift        Draws the app icon and logo
  MenuBarController.swift  Menu bar icon and menu
  Settings.swift           Persisted preferences
Resources/
  Sprites/                 Optional custom animation frames
  Sounds/                  Shared purr and thud, plus one folder of meows and chirps per voice
scripts/bundle.sh          Builds Purrsistent.app
assets/                    Logo and images used in this README
```

## Roadmap

- Walking on top of app windows and sitting on the menu bar
- Reacting to system events like low battery
- More animals, not just cats

## Credits

The cat sounds are real recordings. Each was trimmed, faded, and loudness-matched, and the purr was cut into a seamless loop.

| Files | Source | Author | License |
| --- | --- | --- | --- |
| `Classic/meow_*` | [Cat_meow.wav](https://freesound.org/people/cribbler/sounds/511448/) | cribbler | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `Classic/chirp_*` | [Cat Chirps.wav](https://freesound.org/people/Tyler31898/sounds/634174/) | Tyler31898 | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `Kitten/*` | [Kitten meows](https://freesound.org/people/Luke100000/sounds/476918/) | Luke100000 | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `Tomcat/*` | [Tom cat meow.wav](https://freesound.org/people/tosha73/sounds/506723/) | tosha73 | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `purr_0` | [Purr (10 sec loopable).ogg](https://commons.wikimedia.org/wiki/File:Purr_(10_sec_loopable).ogg) | Insanejeff at English Wikipedia | Public domain |

The landing `thud` is synthesized by `SoundFactory.swift`.

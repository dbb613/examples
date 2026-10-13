<!--
title: 'Breach: a first-person shooter built with Godot 4'
description: 'A level-based FPS that runs natively on Apple Silicon Macs. Built with Godot 4 and no external assets. Not a Serverless Framework example.'
framework: none
platform: macOS
language: GDScript
authorLink: 'https://github.com/dbb613'
authorName: 'dbb613'
authorAvatar: 'https://avatars.githubusercontent.com/dbb613'
-->

# Breach

A level-based first-person shooter built with [Godot 4](https://godotengine.org).
It runs natively on Apple Silicon Macs using the Metal renderer.

The game has three levels, three weapons and three enemy types. It also has
doors, a keycard and a locked door, health and ammo pickups, a HUD, and pause,
death and level-complete screens. Everything is generated in code, including
the meshes, textures and sound effects. You don't need to download any assets.

## Run it on your Mac

1. Install Godot 4.4 or newer. The standard build is a Universal app with
   native Apple Silicon support. Either:
   - `brew install --cask godot`, or
   - download it from https://godotengine.org/download/macos
2. Open Godot. In the Project Manager, click **Import** and select
   `godot-fps/project.godot`.
3. Press **⌘B** (or the ▶ Play button) to run.

## Controls

| Action | Key |
| --- | --- |
| Move | W A S D (or arrow keys) |
| Look | Mouse / trackpad |
| Fire | Left click |
| Reload | R |
| Switch weapon | 1 / 2 / 3 or the scroll wheel |
| Sprint | Shift |
| Jump | Space |
| Pause | Esc or P |

On a MacBook trackpad, enable *Tap to click* or use a mouse. Click-and-drag
on a trackpad works, but it's awkward in a shooter. To change mouse
sensitivity, edit `mouse_sensitivity` in `scripts/player.gd`.

## Make a standalone .app

1. In Godot, choose **Editor → Manage Export Templates → Download and Install**.
2. Choose **Project → Export → Add… → macOS**.
3. Set *Binary Format → Architecture* to `universal` or `arm64`, then click **Export Project**.

For a personal build you can leave code signing set to *ad-hoc*. The first
time you open the app, macOS Gatekeeper asks you to approve it: right-click
the app and choose **Open**.

## Project layout

```
project.godot          Project settings and autoloads
scenes/main.tscn       Entry scene (one node; everything else is built in code)
scripts/
  main.gd              Game flow: title, level loading, pause, win/lose
  game.gd              Autoload "Game": shared state, pathfinding, stats
  sfx.gd               Autoload "Sfx": procedural sound effects
  levels.gd            The campaign: ASCII maps + per-level colours
  map_grid.gd          ASCII map parsing helpers
  level_builder.gd     Turns a map into walls, lights, doors, enemies, pickups
  player.gd            Movement, mouse look, weapons, health, keycard
  enemy.gd             Enemy types and AI (idle → hunt → attack)
  projectile.gd        Enemy bolts
  door.gd              Sliding doors, including locked doors
  pickup.gd            Health, ammo and keycard pickups
  exit_pad.gd          Level exit
  hud.gd               HUD and menus
tests/
  validate_levels.gd   Checks maps are well-formed and completable
  smoke_test.gd/.tscn  Plays every level headlessly (shoot, doors, key, exit)
```

## Making levels

Levels are ASCII maps in `scripts/levels.gd`, and each character is one 3 m
cell:

```
#  wall          .  floor        P  player start     E  exit
d  door          D  locked door  k  red keycard
h  health        a  ammo         g  grunt  s  soldier  b  brute
```

To add a level, append a dictionary to `LEVELS`. Then run the validator.
It catches broken rows, misplaced doors, unreachable keys and missing exits:

```sh
godot --headless --path . -s res://tests/validate_levels.gd
godot --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn
```

On macOS the `godot` binary is at
`/Applications/Godot.app/Contents/MacOS/Godot`.

## Ideas for next steps

- Swap in real models and sounds. For example, drop `.glb` files into the
  project and replace the primitives in `player.gd` and `enemy.gd`.
- Add a weapon pickup instead of starting with all three weapons.
- Add mouse sensitivity and FOV settings to the pause menu.
- Hand-build levels in the Godot editor with `GridMap` or CSG instead of ASCII.
- Add controller support. Godot maps gamepads through the same `InputMap`
  actions that `main.gd` registers.

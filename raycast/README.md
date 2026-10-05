# Monsieur Pierre for Raycast

Control [Monsieur Pierre](https://github.com/lolesterrr/oneko-woah), the
desktop cat that chases your cursor, without leaving Raycast.

## Commands

- **Toggle Cat** — show or hide the cat, starting Monsieur Pierre if needed
- **Change Skin** — pick from all 27 sprites, with previews
- **Set Speed** — slow, normal, or fast
- **Quit Monsieur Pierre** — quit the app

The extension requires the Monsieur Pierre app (macOS 11+), from the
[releases page](https://github.com/lolesterrr/oneko-woah/releases/latest) or
built with `./build.sh`.

All commands talk to the app through its `oneko://` URL scheme, so the
extension needs no permissions of its own.

## Development

The extension lives in the
[oneko-woah repo](https://github.com/lolesterrr/oneko-woah/tree/main/raycast),
where the skin thumbnails in `assets/skins/` are generated from the sprite
sheets with `swift tools/makethumbs.swift Resources raycast/assets/skins`.

# Chronicles of the Idle Wanderer

A **3D idle-adventure web game** built with **Godot 4.7.1** and low-poly 3D models authored in **Blender 5.2.1**. A hero auto-explores a procedurally themed world, earning gold and essence over time while a randomly generated plot unfolds.

## Features

- **Randomly generated plot** every new game (seeded — stable across reloads of the same run)
- **Idle economy** — gold + essence per second, 9 upgrades across income / travel / gear / companions
- **5 unlockable zones / chapters**, each re-theming the 3D world (ground, fog, sky, sun) and advancing the story
- **Offline earnings** (clamped to 8h at 50% rate) + **auto-save** to browser storage, with a welcome-back popup
- **3D scene** — hero, trees, rocks, chests, crystals, enemies; third-person follow camera, procedural sky, fog, soft shadows
- **Cross-platform input** — desktop keyboard/mouse (WASD/arrows + drag-orbit) **and** mobile virtual joystick + action buttons + touch, auto-detected and fully responsive

## Play locally

The exported web build lives at the repository root. Serve it with any static file server:

```sh
python3 -m http.server 8000
```

Then open <http://localhost:8000/> in a browser. (A static server is required — opening `index.html` directly via `file://` will not load the WebAssembly.)

## Deployment (GitHub Pages)

This repo deploys automatically to GitHub Pages via `.github/workflows/deploy.yml`:

- On every push to `main` (or a manual "Run workflow"), the workflow uploads the repository root as a Pages artifact and publishes it — no Godot rebuild in CI, since the exported build is committed.
- Enable it once under **Settings → Pages → Build and deployment → Source: GitHub Actions**.
- The build is a **single-threaded WebGL2** export, so it needs **no COOP/COEP headers** and works on GitHub Pages as-is.

## Repository layout

| Path | Purpose |
|------|---------|
| `index.html`, `index.js`, `index.wasm`, `index.pck`, icons, service worker | Exported Godot web build (served by GitHub Pages) |
| `godot-src/` | Godot 4.7.1 project source (open in the Godot editor to develop) |
| `godot-src/tools_blender/` | Blender scripts used to author the 3D models |
| `.github/workflows/deploy.yml` | GitHub Pages deployment workflow |

## Rebuilding the web export

Open `godot-src/` in Godot 4.7.1, then export the **Web** preset (or headless:
`godot --headless --export-release "Web" <output>/index.html`) and copy the result to the repo root.

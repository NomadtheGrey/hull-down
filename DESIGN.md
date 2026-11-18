# Hull Down — design record

## Pinned (Adam's words)

- **Name:** Hull Down — pinned 2026-11-18, "for now" (working title).
- **Basis:** Battlezone (Atari, 1980) — first-person tank combat on an
  endless plain, geometric obstacles, enemy tanks and UFOs, radar scope,
  periscope-view framing. A "slightly" more modern version — his word,
  slightly in quotes.
- **Engine:** Godot 4 (GL Compatibility, so the tablet keeps up).
- **Two visualization modes, player's choice** (2026-11-18):
  1. Vector / wireframe look — built FIRST.
  2. 3D models — slid in later, beside the vector mode.
  Consequence: game logic and world state stay renderer-agnostic from
  the start; a visual mode is a skin over the same game, never a fork.
- **Workflow:** repo NomadtheGrey/hull-down; Marlowe builds on WIP,
  Adam pulls main only; merges happen on Adam's explicit word only.
- **Display** (2026-11-18): the game stretches to fit — project stretch
  mode canvas_items, aspect expand — so a published build fills any
  screen instead of staying locked to the editor viewport size. F11 /
  the FULLSCREEN button toggles true fullscreen.
- **Mode option lives in the game** (2026-11-18): VECTOR / 3D MODELS
  buttons in the HUD; the 3D button stays disabled until that mode is
  populated.

## Built

- Scaffold (Merge #1, on main): bootable greybox plain.
- Vector build 1 (WIP): drivable first-person tank (main.gd owns all
  game state; collision is circle-vs-obstacle math, no physics
  dependency), cannon with tracer + ray-hit against obstacle boxes,
  vector_renderer.gd draws grid / obstacles / horizon mountains as
  unshaded green line meshes. Headless-verified: clean 180-frame boot,
  collision push-out and ray-hit tests pass.

## Draft / open

- The exact scope of "slightly more modern" — still to agree with Adam.
  Candidates, none pinned: twin-stick-style tank steering vs the
  original's twin-lever feel; guided shells; a horizon with mountains
  and the volcano; score/lives structure kept arcade-plain.
- Controls on tablet (touch) vs laptop (keys) — undesigned.
- Whether the vector mode is drawn with real 3D wireframe meshes or a
  shader/line pass — a build decision for the vector landing, informed
  by tablet performance.

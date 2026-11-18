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
- **Multiplayer later** (2026-11-18): wired eventually using the same
  mechanics as BioForge and Mass Rattle (host-run rooms, room codes,
  relay in the BioForge-relay / Cloudflare Worker family). Until
  then: SOLO / MATCH pills up top, MATCH disabled.
- **Never assume a PC** (2026-11-18): touch controls on phones and
  tablets ship simultaneously with keyboard/mouse buildouts. On PC,
  the mouse rotates the camera (pointer capture steering).

## Built

- Scaffold (Merge #1, on main): bootable greybox plain.
- Vector build 1 (Merge #2, on main): drivable first-person tank
  (main.gd owns all game state; collision is circle-vs-obstacle math,
  no physics dependency), cannon with tracer + ray-hit against
  obstacle boxes, vector_renderer.gd draws grid / obstacles / horizon
  mountains as unshaded green line meshes. Headless-verified: clean
  180-frame boot, collision push-out and ray-hit tests pass.
- Vector build 2 (WIP): the "Space doesn't fire" fix — build 1's shot
  WAS firing, but the tracer ran from the eye down its own axis, so
  it projected to an invisible dot for 90 ms. Shots now draw from a
  low-right gun muzzle to the impact point, with an impact burst and
  a reticle pulse; HUD buttons are focus-none so Space can never be
  swallowed as a UI press; left-click also fires. Plus: 3 bot tanks
  (spawn 55-85 m out, chase with crude obstacle steering, fire with a
  fair random spread — no oracle aim), one-shot kills, hull 3 hits /
  3 tanks / game over + Enter restart, score, and a heading-up radar
  scope (radar.gd — red enemy blips, faint obstacles, sweep arm).
  Enemy tracers burn amber so danger reads. All numbers draft.
  Headless-verified: clean boot, Space-through-the-input-pipeline
  fires, kill/score, enemy hit, AI closing, radar orientation tests
  all pass.
- Vector build 3 (WIP) — Adam's five playtest points, one by one:
  (1) Enemy spawns enforced to a 70-100 m ring (fallback included —
  no more materialising on top of the player), and on respawn any
  hostile within 40 m is pushed back out to the ring; 3 s spawn
  protection. (2) Cannon fire is now a travelling shell (72 m/s
  player, 54 m/s bots, a whisper of gravity), drawn as a bright
  streak — hits are physical, not raycasts; the ray survives only
  to converge the aim. (3) Pyramids collide as pyramids: shells use
  the true sloped cross-section and tanks meet the narrowed
  footprint at hull height, not the base's cube. (4) Getting hit
  flashes the screen red, shakes the camera and flags the status
  line; getting destroyed freezes the action 1.5 s under a TANK
  DESTROYED banner, then respawns in place (no more mystery
  "teleport to the centre") under a TANK READY banner. (5) The
  battlefield is endless and procedural: deterministic 60 m chunks
  generated 5x5 around the player (same chunk, same field, forever),
  grid and mountains follow the player. Waves are real now: WAVE n
  brings 2+n hostiles (max 4 at once), +250 on a clear, counter in
  the HUD. Headless-verified: 14/14 tests (chunk determinism, field
  at +600 m, spawn ring, shell flight time 0.5 s to a kill, pyramid
  shell/tank shapes, hit/death/respawn, wave flow) and a clean
  300-frame boot. MERGED as Merge #4 (PR #4, d193489) 2026-11-18.
- Build 4 (WIP): SOLO / MATCH pills top-right (SOLO the live mode,
  MATCH disabled until multiplayer); the VECTOR/3D/FULLSCREEN row
  moved to the bottom-left to make room. Touch pads (LEFT / RIGHT /
  FWD / BACK / FIRE, hold-to-drive) appear automatically on
  touchscreen devices and feed the same turn/drive path as the
  keyboard. Mouse steering on PC via pointer capture. Decorative
  HUD labels no longer swallow view clicks. Headless-verified:
  12/12 tests, clean boot.

## Draft / open

- The exact scope of "slightly more modern" — still to agree with Adam.
  Candidates, none pinned: twin-stick-style tank steering vs the
  original's twin-lever feel; guided shells; a horizon with mountains
  and the volcano; score/lives structure kept arcade-plain.
- Controls on tablet vs laptop — settled in build 4 (touch pads +
  mouse steering, simultaneous with keyboard); the twin-lever feel
  for the pads is still undesigned.
- Whether the vector mode is drawn with real 3D wireframe meshes or a
  shader/line pass — a build decision for the vector landing, informed
  by tablet performance.

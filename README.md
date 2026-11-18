# Hull Down

BattleZone Reimagined — a "slightly" more modern take on Atari's 1980
first-person tank game, built in Godot 4.

## Status

VECTOR mode: you drive a tank first-person across an endless green
line-drawn plain — obstacles are generated procedurally in chunks
around you forever, and the grid and mountain ring travel with you.
Bot tanks arrive in waves (watch the WAVE counter and the radar scope
at the top of the screen, red blips, heading-up). Cannon fire is a
travelling shell, not a laser. Enemies always spawn 70-100 m out.
Your hull takes 3 hits per tank, you have 3 tanks, and getting blown
up is now very hard to miss. Score 100 per kill, 250 per wave. The
in-game options show VECTOR active and 3D MODELS disabled — that mode
arrives later and reads the same game state.

Controls: W/S or arrows drive, A/D turn, Space or left-click fires,
F11 fullscreen. The display stretches to fill any window or screen.

## The loop

- Marlowe builds on the **WIP** branch (his workspace).
- Adam pulls **main** only — nothing merges WIP -> main without Adam's word.
- Clone it in GitHub Desktop (laptop) or MGit (tablet), open in Godot, run.

See DESIGN.md for the pinned decisions and open questions.

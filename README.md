# Hull Down

BattleZone Reimagined — a "slightly" more modern take on Atari's 1980
first-person tank game, built in Godot 4.

## Status

VECTOR mode: you drive a tank first-person across a green line-drawn
plain (ground grid, box and pyramid obstacles, a mountain ring on the
horizon). Three bot tanks hunt you — watch the radar scope at the top
of the screen (red blips, heading-up). Your cannon kills in one shot;
theirs takes your hull 3 hits at a time, and you have 3 tanks. Score
100 per kill. The in-game options show VECTOR active and 3D MODELS
disabled — that mode arrives later and reads the same game state.

Controls: W/S or arrows drive, A/D turn, Space or left-click fires,
F11 fullscreen. The display stretches to fill any window or screen.

## The loop

- Marlowe builds on the **WIP** branch (his workspace).
- Adam pulls **main** only — nothing merges WIP -> main without Adam's word.
- Clone it in GitHub Desktop (laptop) or MGit (tablet), open in Godot, run.

See DESIGN.md for the pinned decisions and open questions.

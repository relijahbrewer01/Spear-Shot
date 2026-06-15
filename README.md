# Spear Shot

Current milestone: `Spear Shot v0.3.4 - Phase 1 Final`

## Game concept

Spear Shot is a small top-down survival prototype built in Godot 4.

You only own one spear. Throwing it can clear enemies, but it also leaves you unarmed until you physically recover it. The main tension comes from deciding when it is safe to chase the landed spear while enemies close in.

## How to run it

1. Open the project folder in Godot 4.
2. Run `Main.tscn`, or use the project main scene.

If Godot is available on your command line, you can also run the project from this folder with a Godot 4 executable, for example:

```powershell
godot4 --path .
```

The game keeps a low internal resolution of `384x216` and opens at a default displayed size of `1536x864`. Rendering uses nearest-neighbor filtering with integer-scaled `16:9` presentation, so resizing preserves crisp pixels and uses letterboxing or pillarboxing instead of blurry fractional scaling.

## Controls

- `W`, `A`, `S`, `D`: move
- Right mouse button: move to the clicked destination and show a brief trap-style ground marker
- Mouse: aim
- Left mouse button or `Q`: throw spear
- `Shift`: dodge toward the current aim direction
- `Spacebar`: dodge using movement direction first, then click-move direction, then aim fallback
- `Escape` or `P`: pause, or begin the faster `3 2 1` resume countdown
- Left or right mouse button while paused: begin the faster `3 2 1` resume countdown and consume that click
- `R`: restart after death

## HUD layout

- Active play keeps only a small `SCORE` label in the top-right corner
- Health is shown as world-space pips under Akedra in a shallow arc instead of a boxed HUD panel
- Pause uses a simple dark overlay with `PAUSED`, and game-over controls stay interactive after death

## Art direction

- The visual pass keeps the arena readable first: muted daylight tones, clear silhouettes, and bright Charger telegraphs over a medium-value floor instead of a dark moody backdrop
- The player, enemies, Charger, and spear now use small locally generated pixel sprites with lightweight bob/pulse animation instead of pure debug shapes
- The Charger telegraph stays intentionally high-contrast so deaths read as timing mistakes rather than surprise collisions
- Charger visuals, shadow, and telegraph now stay synchronized to the same moving gameplay body instead of running on separate transform paths

## Combat feedback

- Extremely close spear hits trigger a tiny hit stop to punctuate desperate point-blank throws without affecting the normal pause state
- Akedra's contact-damage footprint is slightly smaller than his movement/body footprint so near misses feel a bit fairer
- Dodges use a brief removable sprite modulation change during the active invulnerable movement window instead of adding new Phase 2 effects
- The shared dodge cooldown starts when the dodge begins, not when it ends

## Asset generation

- `art/arena/arena_floor.png`: original arena floor texture with worn off-center scuffs, dirt patches, and bright boundary stones
- `art/sprites/player_hunter.png`: hunter/player sprite
- `art/sprites/enemy_creature.png`: base enemy sprite
- `art/sprites/charger_beast.png`: Charger sprite
- `art/sprites/spear_hunter.png`: spear sprite
- `music/quiet_hunter_loop.wav`: original calm retro loop generated locally for the MVP
- `tools/generate_phase1_assets.py`: reproduces the arena and sprite art assets locally
- `tools/generate_music.py`: synthesizes the background music loop locally as uncompressed `44.1 kHz`, `16-bit`, stereo `.wav`

## Scene/script structure

- `Main.tscn` and `scripts/main.gd`: overall game flow, spawning, scoring, timer, restart, and screen shake
- Run restarts reset gameplay state in place so window size, position, and maximized state are preserved
- `Arena.tscn` and `scripts/arena.gd`: arena visuals, play bounds, and enemy edge spawn positions
- `Player.tscn` and `scripts/player.gd`: movement, aiming, health, invulnerability, and hurt feedback
- `Spear.tscn` and `scripts/spear.gd`: the single spear state loop (`HELD`, `FLYING`, `LANDED`)
- `scripts/spear_trail.gd`: non-rotating deterministic spear trail renderer
- `Enemy.tscn` and `scripts/enemy.gd`: the normal enemy, shared enemy helpers, contact damage, separation, scoring, and death feedback
- `Charger.tscn` and `scripts/charger.gd`: Charger telegraph, locked dash, recovery, and distinct visuals
- `HUD.tscn` and `scripts/hud.gd`: minimal score, pause, and game-over UI
- `scripts/player_health_pips.gd`: world-space health pip display attached under the player
- `scripts/destination_marker.gd`: brief right-click destination feedback marker
- `scripts/high_score_store.gd`: local high-score loading and saving
- `tools/generate_sfx.py`: local retro-style placeholder sound generation
- `tools/generate_phase1_assets.py`: local pixel-art-style sprite and arena generation
- `tools/generate_music.py`: local background music generation
- `tools/bugfix_audit.py`: lightweight static audit for Phase 1 spawn wiring, scaling, minimal HUD, pause support, and audio bus setup

## Enemy behavior

- Normal enemy: slow direct pursuit, worth `1` point
- Charger: unlocks later, chases briefly, telegraphs with a visible dash line, commits to one dash direction, then recovers, worth `3` points

## Scoring and high score

- Normal enemy score: `1`
- Charger score: `3`
- High score is saved locally in `user://highscore.save`
- Invalid or missing save data falls back safely to `0`
- The game-over screen shows the saved high score and marks a new record clearly

## Main adjustable values

- `scripts/player.gd`
  - `move_speed`
  - `destination_reach_distance`
  - `invulnerability_duration`
  - `damage_hit_radius`
  - `dodge_duration`
  - `dodge_distance`
  - `dodge_cooldown`
- `scripts/spear.gd`
  - `spear_speed`
  - `max_range`
  - `held_distance`
  - `landed_marker_radius`
  - `landed_marker_pulse_speed`
- `scripts/enemy.gd`
  - `move_speed`
  - `score_value`
  - `separation_distance`
  - `separation_strength`
- `scripts/charger.gd`
  - `chase_duration_min`
  - `chase_duration_max`
  - `telegraph_duration`
  - `dash_speed`
  - `dash_max_distance`
  - `recover_duration`
  - `telegraph_line_length`
  - `telegraph_shake_strength`
- `scripts/main.gd`
  - `base_spawn_interval`
  - `minimum_spawn_interval`
  - `spawn_interval_drop_per_second`
  - `base_enemy_speed`
  - `enemy_speed_bonus_per_second`
  - `maximum_enemy_speed_bonus`
  - `close_hit_stop_distance`
  - `close_hit_stop_duration`
  - `close_hit_stop_time_scale`
  - `charger_unlock_time`
  - `charger_spawn_chance_at_unlock`
  - `charger_spawn_chance_growth_per_second`
  - `maximum_charger_spawn_chance`
  - `default_window_scale`
- `scripts/player_health_pips.gd`
  - `max_supported_pips`
  - `vertical_offset`
  - `pip_spacing`
- `scripts/destination_marker.gd`
  - `display_duration`
  - `base_radius`
  - `pulse_distance`
- `scripts/arena.gd`
  - `play_margin`
  - `boundary_color`
  - `marking_color`
- `default_bus_layout.tres`
  - `Music` bus volume
  - `SFX` bus volume

## Known limitations

- There are currently two enemy types, both using simple direct movement logic
- Art and music are intentionally simple local placeholder assets rather than a full content pipeline
- Enemy avoidance is intentionally lightweight and not full pathfinding

## Features intentionally left for later

- More enemy types
- Upgrades or progression systems
- Menus outside the in-game restart flow
- Additional arenas or level structure

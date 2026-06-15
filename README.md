# Spear Shot

Current milestone: `Spear Shot v0.5.0 - Encounter Director`

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
- `Shift`: dodge toward aim, cancel prior movement intent, and require previously held movement keys to be released before they move again
- `Spacebar`: dodge using movement direction first, then click-move direction, then aim fallback while preserving movement continuity
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
- Shielded enemies use a broad body plus visible hide/wood/bone plate primitives, keeping the protected state readable without a magical glow
- The Charger telegraph stays intentionally high-contrast so deaths read as timing mistakes rather than surprise collisions
- Charger visuals, shadow, and telegraph now stay synchronized to the same moving gameplay body instead of running on separate transform paths

## Combat feedback

- Extremely close spear hits trigger a tiny hit stop to punctuate desperate point-blank throws without affecting the normal pause state
- Akedra's contact-damage footprint is slightly smaller than his movement/body footprint so near misses feel a bit fairer
- Akedra now stays upright during normal movement and faces left/right through horizontal sprite flipping instead of rotating upside down
- Dodges now read through a full body roll and a short fading afterimage trail, keeping the spear aim independent from the body animation
- Dodge movement lasts `0.20` seconds, travels `36` pixels, and uses a `2.00` second shared cooldown
- A separate `0.10` second damage-immunity grace window begins when dodge movement ends, allowing Akedra to emerge cleanly before normal contact damage resumes
- `Shift` dodges toward aim, clears click-to-move, and suppresses only the WASD keys already held until each is released
- `Spacebar` dodges along current movement and preserves held WASD or click-to-move continuity afterward
- A new right-click issued during either active dodge is buffered, replaces any earlier buffered click, and begins moving Akedra on the first normal frame after the roll
- A tiny world-space exertion wisp beside Akedra shrinks with the real cooldown and gives one restrained glint when dodge becomes ready
- A locally generated physical swoosh blends displaced air, cloth movement, body weight, and a small foot scuff once per valid dodge
- The shared dodge cooldown starts when the dodge begins, not when it ends

## Asset generation

- `art/arena/arena_floor.png`: original arena floor texture with worn off-center scuffs, dirt patches, and bright boundary stones
- `art/sprites/player_hunter.png`: hunter/player sprite
- `art/sprites/enemy_creature.png`: base enemy sprite
- `art/sprites/charger_beast.png`: Charger sprite
- `art/sprites/shielded_enemy.png`: broad Shielded enemy body sprite
- `art/sprites/spear_hunter.png`: spear sprite
- `music/quiet_hunter_loop.wav`: original calm retro loop generated locally for the MVP
- `audio/wave_warning.wav`: restrained local warning cue for authored encounter telegraphs
- `audio/shield_break.wav`: local physical crack/thud cue for Shielded shield break
- `tools/generate_phase1_assets.py`: reproduces the arena and sprite art assets locally
- `tools/generate_phase4_assets.py`: reproduces the Shielded enemy body sprite locally
- `tools/generate_music.py`: synthesizes the background music loop locally as uncompressed `44.1 kHz`, `16-bit`, stereo `.wav`

## Scene/script structure

- `Main.tscn` and `scripts/main.gd`: overall game flow, spawning, scoring, timer, restart, and screen shake
- Run restarts reset gameplay state in place so window size, position, and maximized state are preserved
- `Arena.tscn` and `scripts/arena.gd`: arena visuals, play bounds, and enemy edge spawn positions
- `Player.tscn` and `scripts/player.gd`: movement, aiming, health, invulnerability, upright facing, and dodge readability visuals
- `scripts/player_dodge_trail.gd`: fixed-pool dodge afterimages sampled from Akedra's body visual
- `scripts/player_dodge_cooldown_indicator.gd`: world-space exertion wisp and brief ready glint driven by the shared dodge cooldown
- `Spear.tscn` and `scripts/spear.gd`: the single spear state loop (`HELD`, `FLYING`, `LANDED`)
- `scripts/spear_trail.gd`: non-rotating deterministic spear trail renderer
- `Enemy.tscn` and `scripts/enemy.gd`: the normal enemy, shared enemy helpers, contact damage, separation, scoring, and death feedback
- `Charger.tscn` and `scripts/charger.gd`: Charger telegraph, locked dash, recovery, and distinct visuals
- `ShieldedEnemy.tscn` and `scripts/shielded_enemy.gd`: two-hit Shielded enemy, shield-break stagger, and exposed death through the shared score path
- `HUD.tscn` and `scripts/hud.gd`: minimal score, pause, and game-over UI
- `scripts/player_health_pips.gd`: world-space health pip display attached under the player
- `scripts/destination_marker.gd`: brief right-click destination feedback marker
- `scripts/encounter_director.gd`: authored wave scheduling, population caps, state transitions, and strict cleanup
- `scripts/encounter_telegraph.gd`: readable world-space edge warning renderer
- `scripts/high_score_store.gd`: local high-score loading and saving
- `tools/generate_sfx.py`: local retro-style placeholder sound generation
- `tools/generate_phase1_assets.py`: local pixel-art-style sprite and arena generation
- `tools/generate_music.py`: local background music generation
- `tools/bugfix_audit.py`: lightweight static audit for Phase 1 spawn wiring, scaling, minimal HUD, pause support, and audio bus setup
- `tools/encounter_director_audit.py`: static Phase 3 encounter, safety, and warning-audio audit
- `tools/EncounterDirectorRuntimeAudit.tscn`: focused runtime audit for Rush, Pincer, and Charger Hunt
- `tools/EncounterIntegrationAudit.tscn`: Main-scene telegraph, SFX, spawn, cleanup, recovery, and restart audit
- `tools/shielded_enemy_audit.py`: static Phase 4.1 Shielded enemy contract audit
- `tools/ShieldedEnemyRuntimeAudit.tscn`: runtime audit for Shielded hit ordering, STOPPED spear behavior, score, stagger, and ambient cap removal

## Enemy behavior

- Normal enemy: slow direct pursuit, worth `1` point
- Charger: unlocks later, chases briefly, telegraphs with a visible dash line, commits to one dash direction, then recovers, worth `3` points
- Shielded: ambient-only armored enemy, first thrown-spear hit breaks the shield and stops the spear for no score, second hit kills for `2` points

## Encounter director

- Ambient survival spawning now gives way to temporary authored events after roughly `28-34` seconds
- A bright world-space edge bracket and one restrained warning sound announce each wave for `1.75` seconds
- Ambient spawning pauses during the telegraph, active wave, and `3.0` second recovery window
- Ambient resumes afterward with a fresh interval calculated from the current survival-time difficulty
- `Rush` sends four Normals from one announced edge
- `Pincer` alternates six Normals between two opposite announced edges
- `Charger Hunt` sends two Normals followed by one Charger from one announced edge
- Each wave has its own start pressure budget: `Rush` at five or fewer hostiles, `Charger Hunt` at four or fewer, and `Pincer` at three or fewer
- Tunable safety caps begin at `10` total hostiles, `9` Normals, and `2` Chargers
- Shielded enemies count toward total hostile pressure, have a dedicated cap of `1`, and do not count as Normals or Chargers
- Shielded ambient spawns unlock around `55` seconds with a small capped weight, and capped/locked Shielded candidates are removed before choosing among remaining ambient types
- The first minute uses an effective one-Charger limit so the ceiling of two does not become the design target
- Wave spawns stay at least `72` pixels from Akedra and `36` pixels from a landed spear
- If no fair edge point is available, the spawn waits and retries instead of using an unsafe fallback
- A wave completes only after all scheduled spawns occurred and every enemy tagged to that wave died or exited the tree

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
  - `dodge_exit_invulnerability_duration`
  - `dodge_spin_turns`
  - `horizontal_facing_dead_zone`
  - `dodge_trail_afterimage_count`
  - `dodge_trail_sample_interval`
  - `dodge_trail_lifetime`
- `scripts/player_dodge_cooldown_indicator.gd`
  - `enabled`
  - `world_offset`
  - `wisp_color`
  - `ready_glint_color`
  - `ready_glint_duration`
- `scripts/spear.gd`
  - `spear_speed`
  - `max_range`
  - `held_distance`
  - `stopped_hit_landing_clearance`
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
- `scripts/shielded_enemy.gd`
  - `movement_speed_scale`
  - `stagger_duration`
  - `knockback_distance`
  - `knockback_duration`
  - `shield_break_effect_duration`
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
  - `shielded_unlock_time`
  - `shielded_spawn_chance_at_unlock`
  - `shielded_spawn_chance_growth_per_second`
  - `maximum_shielded_spawn_chance`
  - `landed_spear_spawn_safe_radius`
  - `blocked_spawn_retry_interval`
  - `default_window_scale`
- `scripts/encounter_director.gd`
  - `first_wave_time_min`
  - `first_wave_time_max`
  - `inter_wave_interval_min`
  - `inter_wave_interval_max`
  - `rush_start_population_threshold`
  - `pincer_start_population_threshold`
  - `charger_hunt_start_population_threshold`
  - `total_hostile_cap`
  - `normal_hostile_cap`
  - `charger_hostile_cap`
  - `shielded_hostile_cap`
  - `first_minute_charger_cap`
  - `spawn_retry_interval`
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

- There are currently three enemy types, all using intentionally simple movement logic
- Art and music are intentionally simple local placeholder assets rather than a full content pipeline
- Enemy avoidance is intentionally lightweight and not full pathfinding

## Features intentionally left for later

- More enemy types
- Ring encounter formations
- Opportunity encounters such as a Heart Runner, kept separate from hostile population slots
- Wave reward selection driven by encounter completion signals
- Upgrades or progression systems
- Menus outside the in-game restart flow
- Additional arenas or level structure

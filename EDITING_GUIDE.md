# Editing guide

Everything below is editable in the Godot **Inspector**. Hover any field for its tooltip.
Changes apply the next time you press **F5 / Run**.

## Making a new level

1. **Scene → New Scene → 2D Scene**, rename the root (e.g. `Level2`), save it in `Scenes/`.
2. From the FileSystem dock, drag **`Scenes/Prefabs/tether_rig.tscn`** into the scene.
   That one node is both characters, the cord, camera, HUD, anxiety filter and pause menu.
   **Where you put it is where the pair spawns** (Wisp at the rig's origin, Ember 60 px left).
3. Add ground under it: Add Child Node → search **Block** (StaticBody2D), set `size`.
4. Press **F6** (Run Current Scene). That's it.

Optional, all from Add Child Node: `Zone` (checkpoints, phase changes, endings, kill floor),
`TetherAnchor` (rings), `CrumbleBlock`, `Plate` + `Gate`, `DialogueTrigger`.
No KILL zone? Falling `fall_respawn_depth` (1500 px) below the lowest checkpoint respawns you.
To make a level the game starts in: Project → Project Settings → Application → Run → Main Scene.

**Intro on a black screen** (Level1 does this):
1. Select the level's `TetherRig` → Intro → tick **`start_black`**.
2. Add a `DialogueTrigger` around the spawn point. Its steps: your DialogueLines, then a
   **DialogueFade** (FROM_BLACK, `duration`) as the last step. Put a short DialogueWait first
   for a beat of silence. Bubbles show on the black; input is locked until the reveal is
   halfway done. DialogueFade TO_BLACK works the same way for endings and scene cuts.
3. **Cord reveal** (Level1 does this): after the last line, use three steps instead of one DialogueFade:
   1. **DialogueCall** → Target `TetherRig`, Method `reveal_tether` (no args): the cord fades in alone
      on the black and holds. It stays in front of the black and the characters.
   2. **DialogueFade** FROM_BLACK: the scene fades in.
   3. **DialogueCall** → Target `TetherRig`, Method `tether_behind_characters`: back to normal order.
   Set the reveal up on TetherRig → Intro: `tether_reveal_sound` (+ `_volume_db`), `tether_reveal_time`
   (cord fade-in), `tether_reveal_hold` (cord alone on black). Args `[rope_time, hold]` override them
   for one call (-1 = use the Intro setting).

**Per-level overrides:** select the TetherRig in a level and change anything in the Inspector
(e.g. a different `phase_profiles` list, or start a level at phase III by listing only that
profile). Overrides only affect that level. To change Wisp/Ember everywhere, open
`tether_rig.tscn` itself; to change them in one level only, right-click the rig →
**Editable Children**.

## Where things live

| To change... | Select / open |
|---|---|
| Anything about a **phase** (cord, AI, pull-back, tug, swap, visuals) | `Data/Phases/phase_1_together.tres`, `phase_2_closer.tres`, `phase_3_inseparable.tres` (double-click) |
| A **character** (speed, jump, weight, grip, sprite, reel tremble, bubble colour) | `Wisp` / `Ember` in `Scenes/Prefabs/tether_rig.tscn` |
| **Cord physics** shared by every phase (stiffness, reel speed, break force, look, sounds) | `Tether` in `tether_rig.tscn` |
| Phase order, camera, sever bonus, debug keys, fall safety net | `TetherRig` root (in `tether_rig.tscn`, or per level on the instance) |
| Level geometry, rings, checkpoints, phase changes, endings | Nodes under `Level`, `Anchors`, `Zones` |
| Dialogue and scripted events | Nodes under `Dialogue` (DialogueTrigger) |
| **Fonts** for speech bubbles, messages, titles and subtitles | `TetherRig` root → **Fonts** group (see [Fonts](#fonts)) |
| **Position / colour / shadow** of the title card, centered message and FPS counter | `HUD` → `TitleCard`, `Message`, `FPS` in `tether_rig.tscn` (see [Positioning the title card, message and FPS counter](#positioning-the-title-card-message-and-fps-counter)) |
| A **web (browser) build** and hosting it online | `CraveFX_Assessment/Builds/Web/`, outside the project (see [EXPORT_GUIDE.md](EXPORT_GUIDE.md)) |
| Volume, music | Pause menu (Esc) / `SoundManager` autoload / Audio bus panel |

---

## 1. Phase II constraints (cord slack, memory, anxious partner)

Open **`Data/Phases/phase_2_closer.tres`**.

| Group | Field | What it does | Now |
|---|---|---|---|
| Cord | `max_length` | Longest the cord can be in this phase (tightens to it gradually) | 320 |
| | `rest_length` | Length it eases back to when you're both standing | 150 |
| | `comfort` | Beyond this distance you count as "apart" (filter + memory) | 110 |
| Tension memory | `shrink_after` | Seconds apart before the cord starts shortening itself (0 = off) | 1.2 |
| | `shrink_speed` | How fast it shortens, px/s (it never grows back) | 40 |
| | `leash_floor` | Shortest it can ratchet down to | 150 |
| Partner AI | `follow_distance` | How close it stays | 50 |
| | `predict` | How far ahead of you it moves (s of your velocity) | 0.35 |
| | `mirror_jump_chance` | Chance it copies your jump, even into a pit | 1.0 |
| | `safe_drop_height` | Tallest ledge (px) it walks off on its own if there's floor below; 0 = never drops. Set per phase (all default 200) | 200 |
| Swap | `control_bleed` | Your input still drives the old body this long after a swap | 0.12 |
| Look & feel | `anxiety` / `floaty` | Cold filter strength / how mushy your movement gets when apart | 0.8 / 0.5 |

### How the cord shortens (read this before tuning)

Two different lengths are in play. Keep them apart in your head:

- **The cord** - how long the rope is *right now*. The player changes it: reel in (shorter), give slack
  (longer). When both stand on the ground, a reeled-in cord eases back out to `rest_length`.
- **The ceiling** - the *most* slack the player can give. Think of it as the length of rope left on the
  spool. The cord can never be longer than the ceiling. **Shortening only ever moves the ceiling.**

The ceiling moves in two situations:

1. **A new phase starts.** The ceiling slides down to the new `max_length` (at the Tether node's
   `tighten_speed`, 90 px/s), e.g. 440 → 320 entering phase II takes about 1.3 s.
2. **You stay apart too long (phase II's "tension memory").** It works like a timer:
   - "Apart" = the two are further than `comfort` apart, measured **along the cord** (through a ring
     if hooked), not in a straight line.
   - While apart, a timer counts up. Once it passes `shrink_after`, the ceiling drops by `shrink_speed`
     px every second, for as long as you stay apart.
   - Come back within `comfort` and the timer drains (twice as fast as it filled), but the ceiling
     **stays where it got to**. It never grows back, not even after dying. It stops at `leash_floor`.

**Worked example (phase II now):** the ceiling starts at 320. Walk more than 110 px apart: nothing for
1.2 s, then the ceiling drops 40 px/s. Stay apart 3 more seconds → 320 - 120 = 200. Come back
together: it stays 200 for the rest of the phase. The whole budget is (320 - 150) / 40 ≈ **4 seconds**
of shrinking (plus the 1.2 s grace each time you drift apart) before it hits the 150 floor.

| To make it... | Change |
|---|---|
| more forgiving | raise `comfort` (more room before you count as apart) or `shrink_after` (longer grace) |
| harsher | lower `comfort` / `shrink_after`, or raise `shrink_speed` |
| bottom out shorter or longer | `leash_floor` (the smallest the ceiling can get) |
| switch it off | `shrink_after` = 0 |
| start shorter | `max_length` |

Rules of thumb:
- Keep `leash_floor` ≤ `max_length` (a higher floor is treated as `max_length`, so nothing shrinks - that's
  how phase III has it off).
- `rest_length` above the current ceiling is ignored - the cord rests at the ceiling instead.
- If `comfort` is *smaller* than `rest_length` (phase II: 110 vs 150), a fully relaxed cord already counts as
  "apart", so standing still at full rest length slowly eats the budget. Intended pressure in phase II;
  set `comfort` ≥ `rest_length` if you don't want that.
- The cord turns hotter/redder as the ceiling gets shorter, so the player can see the memory.
- While testing: **F5** puts the ceiling back to the phase's `max_length`; **Shift+F1** shows the live
  cord length and ceiling ("cap").

Slack you give with RMB is capped by the current cord ceiling. How fast slack pays out
(`slack_speed`) and how fast you reel (`reel_speed`) are on the **Tether** node, because
they're the same in every phase. Press **F5** in-game to reset the cord memory while tuning.

## 2. Character sprites and animations

**Wisp and Ember already use the sketch-based art** (`Art/Characters/`). Their animations are
`wisp_frames.tres` / `ember_frames.tres`, built from `*_spritesheet.png` (2x size, 160 px cells,
24 fps; the `.json` next to each sheet lists the rows). They're assigned on the `Wisp` / `Ember`
nodes in `Scenes/Prefabs/tether_rig.tscn`, so every level uses them:

| Setting | Value | Why |
|---|---|---|
| `sprite_scale` | 0.5 | the sheets are drawn at 2x for sharpness |
| `sprite_offset` | Wisp (0, -20), Ember (0, -17) | puts the art's feet on the bottom of the collision box |
| `art_height` | Wisp 44, Ember 55 | the "you" marker, "..." and speech bubbles sit above the head/hair |
| `swing_sprite_offset` | (0, 4) | swing frames are drawn around the hands: puts them on the cord |

To go back to the plain shapes, clear `sprite_frames` on a node. To make your own art instead,
follow the steps below (replace `sprite_frames` with your own SpriteFrames).

Besides the names in the table, these are used when present: `rise` (going up after the `jump`
take-off), `land` (just touched down), `slack` (paying out cord), `hook` (just hooked a ring).
One-shot animations (loop off) hold their last frame until the next animation starts.

Each character draws its placeholder shape until you give it art.

1. Select `Wisp` (or `Ember`). In **Sprite (optional)**, click `sprite_frames` → **New SpriteFrames**, then click it to open the SpriteFrames panel at the bottom.
2. Create animations with these exact names (only `idle` is required; any missing one falls back to `idle`):

   | Name | Plays when |
   |---|---|
   | `idle` | standing still |
   | `run` | walking (faster than `run_anim_threshold`) |
   | `jump` / `fall` | airborne, going up / coming down |
   | `swing` | airborne on a taut cord (hanging, swinging) |
   | `reel` | planted and hauling the other one in |
   | `dragged` | being dragged along the ground by the cord |
   | `stagger` | yanked by a phase III tug |
   | `left_behind` | the one you abandoned after severing |

3. Drag frames in, set FPS and loop per animation.
4. Line it up: `sprite_offset` moves the art relative to the body, `sprite_scale` resizes it, and `sprite_faces_right` says which way your art faces (it flips automatically).
5. Make the **collision** match the art: `shape` (RECT/CIRCLE) and `size` on the same node.

What still works with sprites: jump/land squash, the reel tremble, and greying
out when left behind. The "you" marker and "..." still draw on top.

## 3. Phase III pull-back and tug

Open **`Data/Phases/phase_3_inseparable.tres`**.

**Pull-back** is the partner planting its feet when you start to leave, so the cord holds you.

| Field | What it does | Now |
|---|---|---|
| `hold_on_chance` | Chance it holds on each time you start walking away (0-1) | 1.0 |
| `hold_on_time` | How long it holds each time; longer means a harder pull | 0.45 s |
| `hold_on_cooldown` | Minimum gap between hold-ons. **This is the frequency knob**: raise it to pull back less often | 0 s |

**Tug** is the yank you feel when you pull away against it.

| Field | What it does | Now |
|---|---|---|
| `tug_enabled` | On/off | on |
| `tug_force` | How hard you must pull away before it counts (W = one Wisp-weight). Lower = tugs more easily | 1.3 |
| `tug_impulse` | Strength of the yank back (px/s) | 300 |
| `tug_stagger` | How long you lose control after a tug | 0.22 s |
| `tug_cooldown` | Minimum time between tugs | 0.9 s |
| `panic_time` | How long the partner panics afterwards (closes in, jumps blindly) | 1.2 s |
| `tug_camera_shake` | Screen shake per tug (px) | 6 |

Related in the same file: `max_length` 120 (the short leash), `follow_distance` 30,
`swap_delay` 0.3 (new body hesitates), `control_bleed` 0.3 (old body still obeys you).
Use **F4** (slow-motion) to watch a tug frame by frame.

---

## 4. Other tools

### Phases
- Any phase can use any behaviour: e.g. give phase II a mild tug (`tug_enabled`, high `tug_force`) or phase I a little `predict`.
- **Add a phase IV:** duplicate a `.tres`, edit it, add it as the 4th entry of the TetherRig's `phase_profiles`, and place a PHASE zone with `phase = 4`.
- Phases only escalate; the cord's memory survives respawns.
- **Severing (hold Q)** only works in phases with `can_sever` ticked (Cord group). Only phase III has it on.
  How long it must be held: TetherRig -> Sever -> **`time_to_sever`** (seconds, default 2.5). The stretch sound,
  camera shake and the ring around the body build up over that time.
  `TetherRig.sever_tether()` from a DialogueCall still cuts the cord in any phase.

### Debug keys (TetherRig → Debug → `debug_tools`; turn off before sharing a build)
| Key | Does |
|---|---|
| F1 | Toggle the **FPS counter** (top left, "FPS: 60"). On by default; untick `show_fps` in TetherRig → Debug to start with it off. Works even with `debug_tools` off |
| Shift+F1 | Toggle the debug readout (top, under the FPS counter) and controls reminder (bottom). Both start hidden; tick `show_debug_text` / `show_controls` in TetherRig → Debug to start with them on |
| F2 | Jump to the next phase |
| F3 | Teleport both to the next checkpoint (wraps around) |
| F4 | Slow-motion toggle (`slow_motion_scale`, default 0.25) |
| F5 | Reset cord memory to the phase maximum |

### Dialogue and scripted events (DialogueTrigger)
- `activated_by`: EITHER character, only the CONTROLLED one, or BOTH inside together.
- `one_shot`: untick to replay every time.
- `debug`: tick to switch a trigger OFF while testing (drawn red with "DEBUG: OFF" in the editor). If it's an intro
  that fades in from black, the level starts uncovered instead, so you can play straight away. Untick before sharing a build.
- Copy/paste freely: pasted or duplicated steps (single slots, whole arrays, or Ctrl+D on a trigger) are made unique
  automatically, so editing one never changes another. No "Make Unique" needed.
- Steps you can add: **DialogueLine** (speech bubble, BBCode), **DialogueCall** (call a method),
  **DialogueWait** (pause N seconds), **DialogueMusic** (start/stop music or ambience; empty stream = stop),
  **DialogueFade** (fade from/to black; speech bubbles stay visible on black).
- Methods on the **TetherRig** made for DialogueCall (drag the TetherRig node onto `target`):

  | Method | Args | Use |
  |---|---|---|
  | `show_message` | text, seconds (default 2.5), font (optional) | Centered text that fades in and out |
  | `show_title` | title, subtitle (optional), title font (optional), subtitle font (optional) | Big title card, like the phase titles |
  | `show_ending` | text, font (optional) | Darken the screen and leave a final line up |
  | `lock_input` | seconds | Cutscene: ignore the player for a while |
  | `fade_from_black` / `fade_to_black` | duration | Same as a DialogueFade step |
  | `reveal_tether` | (none; optional rope_time, hold) | Intro: cord fades in alone on the black, drawn in front |
  | `tether_behind_characters` / `tether_in_front` | (none) | Put the cord back behind the characters / bring it to the front |
  | `shake_camera` | amount | Emphasis |
  | `go_to_phase` | phase number | Escalate the relationship at a story beat |
  | `sever_tether` | (none) | Cut the cord from a script |
  | `swap` | (none) | Force a perspective swap |

  Args go in order, e.g. `show_message` → `["Something's wrong.", 3.0]`; ones with a default can be left out.
  **Wait until done** (on by default): the next step waits for messages, titles and fades to finish.
  Untick it to let the conversation carry on while a title or message is showing.

### Characters (Wisp / Ember nodes)
`run_speed`, `jump_height`, `time_to_apex` (jump feel), `mass` and `grip` (who holds whom),
`swing_pump`, the **Reel feedback** group (tremble strength/rate, `reel_squash`), `bubble_tint`,
and `speaker` (GIRL/BOY for dialogue).

### Cord, shared (Tether node)
`reel_speed`, `slack_speed`, `reel_max_force`, `reel_brace` (extra grip while reeling),
`can_break` (off = the cord only breaks when the player holds Sever; on = it can also snap
from strain), `break_force` / `break_time` (when it snaps, only used if `can_break` is on), `stiffness` / `damping` (elasticity),
`anchor_range` (ring hook reach), `sever_hold_time`, plus the **Reel / slack feedback**
group (tints, shimmer, flow dots, `reel_sound` / `slack_sound` and their volumes).

### TetherRig root
Camera follow speed / lean / look-ahead, `checkpoint_partner_radius`,
`sever_speed_mult` / `sever_jump_mult` (how good movement feels after severing), and
`fall_respawn_depth`.
- **Messages**: `sever_message` (shown when the cord is cut, "It's over.") and `fall_messages` - when anyone falls
  to their death one line is picked at random (never the same twice in a row). Add, remove or edit lines in the list.
- **Sever** and **Audio** groups: the cut sound, `on_sever` steps, level music/ambience and game-event sounds.
  See `AUDIO_GUIDE.md`.

### Art: the meadow look (Level1_Visual)
`Scenes/Level1_Visual.tscn` is Level1 with art applied - same layout, triggers and dialogue. Purely visual:
- **LevelArt** node (`Scenes/Prefabs/level_art.tscn`, top of the scene): sky + sun, fog-streak clouds, three
  parallax background layers, meadow flowers, dark earth and chasm shading, drifting dust, foreground grass,
  screen finish (vignette, grain), silhouette characters and yellow glowing rings. Every colour, amount and
  parallax speed is in its Inspector groups. The sky/backdrop/dust/silhouettes only show when the game runs.
- **Block → `look`**: PLAIN (flat colour) or MEADOW (grass, flowers, rock edges). Only the drawing changes -
  collision stays exactly `size`. New blocks start PLAIN; set MEADOW to match the level.
- **MeadowTree** (`Decor/EndTree`, by the exit): change `tree_seed` for a different tree, plus trunk/branch/leaf settings.
- To dress another level: drop in `level_art.tscn`, set its blocks to MEADOW.
- Level1 and Level1_Visual are separate files: layout edits to one do NOT carry over to the other.
- Level1_Visual's left edge: no WallLeft. The field continues (`Level/I_GroundLeft`, scenery only) with
  `Decor/StartTree`; `Bounds/LeftBorder` is an invisible wall at x = -200 (where WallLeft's face was), and
  `Dialogue/LeftBorderLine` plays Wisp's "The other way, silly!" once. Move the wall and the trigger together.
- Characters are silhouettes everywhere by default (`silhouette` in `Scripts/character.gd`), not only in the art levels.

### Art: the forest edge (Level2_Visual)
`Scenes/Level2_Visual.tscn` is Level2 with art applied - same layout and triggers, built from Level2. Differences:
WallLeft is gone (floor continues as `Level/I_GroundLeft`, `Decor/StartTree`, `Bounds/LeftBorder` + the same
one-time line), an end tree past the exit, a few decor trees on wide platforms (`Decor/Tree_A`..`F`, no collision),
and the two fireworks were lowered 13 px / 1 px so they stand on the ground.
- **LevelArt** settings for the overcast forest: `overcast` (0 = clear sky; ~0.9 = heavy cloud deck), cloud deck
  light/dark colours and `cloud_wind`; `backdrop` = FOREST_EDGE (tree clumps with open plain between - `woodland`
  sets how much is trees); `foreground_trees` (dark trunks passing in front; 0 = none) and its opacity.
  Level1_Visual uses the same node with `overcast` 0 and MEADOW_HILLS, so it looks as before.
- Level2 and Level2_Visual are separate files: layout edits to one do NOT carry over to the other.
- Small hill blocks (I_Ground23/30-42 that make the ground uneven) sit at the top of the `Level` list so they draw
  behind the main ground - in Godot the lower a node is in the list, the more in front it draws.

### Art: the deep forest (Level3_Visual)
`Scenes/Level3_Visual.tscn` is Level3 with art applied - same layout and triggers, built from Level3. Differences:
WallLeft is gone (replaced by `Decor/StartTree` + `Bounds/LeftBorder`, same as Level2_Visual; Level3's floor already
runs far enough left), a bare dead tree at the end (`Decor/DeadTree`), tall decor trees on wide platforms
(`Decor/Tree_A`..`H`, no collision; D and G are dead), and the five fireworks lowered 1-6 px to stand on the ground.
The branches in this level have grey-brown dead leaves (`leaf_color` changed on each copy; everything else still
follows the prefab).
- **LevelArt → Deep forest** (used when `backdrop` = DEEP_FOREST):
  - `trunk_rows` / `trunk_density`: how many rows of trunks and how crowded they are.
  - `trunk_far` / `trunk_near`: trunk colour in the farthest row (lost in the fog) and the nearest one.
  - `fog` (between the rows), `ground_fog` (low on the forest floor), `front_fog` (drifting in FRONT of the level
    along the bottom of the screen - keep it low or platforms get hard to read). Fog colour is `haze`.
  - `canopy` + `canopy_color`: the leaves shading the top of the screen (0 = none).
  - `light_shafts`, `shaft_color`, `shaft_opacity`: the dim light falling through the leaves (0 = none).
- **LevelArt → Screen finish → `desaturate`**: drains colour from the whole picture (0.82 here = almost black and
  white). Strong colours (yellow rings and rocket bands, the cord) keep a little of theirs so they stay readable.
  `desaturate_tint` is the colour the grey leans toward. Level1/Level2 leave it at 0.
- **Dead trees**: any MeadowTree with `leaves` unticked is bare branches with twigs; its wood colour is `leaf_color`.
- Level3 and Level3_Visual are separate files: layout edits to one do NOT carry over to the other.
- A boulder stacked on another (Test_KeyBarrier6) has `base_grass` off so no grass floats under it. Untick it
  on any boulder that isn't sitting on the ground.

### Foreground (all *_Visual levels, LevelArt → Foreground grass)
- `foreground_fade_after_fall` / `foreground_fade_distance`: the grass and big trunks in front stay locked to the
  camera (jumps and drops to lower ground change nothing). Fall more than `fade_after_fall` px below where you last
  stood (into a pit) and they fade out over the next `fade_distance` px, then fade back in once you're standing.
- `foreground_tree_see_through`: a foreground trunk fades to this opacity while either character is behind it.

### Main menu (`Scenes/MainMenu.tscn`, the game's first scene)
Everything is a node you can move in the editor - nothing is placed by code.
- **Text**: `UI/Root/Title` (the TETHER image, `Art/UI/title_tether.png`), `UI/Root/Subtitle`, `UI/Root/ClickToStart`.
  Drag them in the 2D view or set anchors/offsets in the Inspector; font, size and colour are in each Label's
  Theme Overrides. They sit on their own CanvasLayer, so the screen grading doesn't darken them.
- **Backdrop**: `LevelArt` (sky, sun, rays, hazy hills, motes - same settings as the levels), `Hill` (a MenuHill:
  rise position/width/height, colours, grass) and `Tree` (a MeadowTree - move it, scale it, change its seed).
- **Ambient motion** (all Inspector settings; 0 = still): LevelArt -> Ambient motion (`cloud_drift`, `grass_sway`,
  `sun_breathe`, `ray_drift`) and `dust_count`/`dust_speed`; Tree -> `sway`, `sway_speed`; Hill -> `grass_sway`;
  MainMenu -> `camera_drift`, `camera_drift_period`. Tree and hill-grass sway are done on the GPU
  (`Shaders/sway.gdshader`), so they cost almost nothing. Any level can use the same settings.
- **MainMenu root**: `first_scene` (where "click to start" goes), fade in/out times, the prompt's pulse, and optional
  `menu_music` / `start_sound`. A click, key, controller button or tap starts the game.

### Credits (`Scenes/Credits.tscn`, after Level3's exit)
Black screen; `FirstLine` fades in, holds, fades out; a pause on black; `SecondLine` fades in and stays. A click,
key, button or tap then goes back to the main menu. Both lines are Labels you can move and restyle in the editor.
On the root: `menu_scene`, `music` (+ volume and fade in) and the **Timing** group (`start_delay`, `first_fade_in`,
`first_hold`, `first_fade_out`, `black_gap`, `second_fade_in`, `leave_fade`). Level3_Visual's LevelExit has
`next_scene = "Credits"`.

### Prefabs - edit one file, every copy follows
Each copy in a level only stores its position (and anything you change on that copy, shown with a ↺ revert
arrow in the Inspector). To change all of them, open the prefab and edit its root node.
- **Branch** `Scenes/Prefabs/crumble_branch.tscn` (CrumbleBlock): `crumble_delay`, `respawn_delay`; Look (bark,
  leaves, twigs); Feel (`shake_strength` before it snaps, `break_particles`, `regrow_fade`); Sound: `creak_sound`
  (starts to give), `break_sound`, `regrow_sound`, each with a volume. Collision is always exactly `size`.
- **Boulder** `Scenes/Prefabs/boulder.tscn`: `rock_seed` (shape), stone/rim-light/moss colours, `chunks`, optional
  `break_sound`. Collision is the full `size` box (191×200), so the level plays the same as before.
- **Firework** `Scenes/Prefabs/firework_key.tscn` (KeyItem, FIREWORK look): body/band/glow colours, `burst_colors`,
  `travel_time` + `arc_height` (the rocket's flight), `shake`, `burst_sparks`; Sound: `collect_sound` (touched),
  `launch_sound` (flight), `impact_sound` (obstacle destroyed). Connect targets as for KeyItem below. Place it so
  its stick ends on the ground: the rocket's centre is 22 px above the surface.
- **Ring** `Scenes/Prefabs/tether_anchor.tscn` (TetherAnchor): `hook_sound` (cord hooks on) and `release_sound`,
  each with a volume. Used by every ring in Level1_Visual, Level2_Visual and Level3_Visual. (Ring colour/glow there is set by
  LevelArt's `ring_color`/`ring_glow`.)

### Level pieces
- **Resize handles** (Box Resize plugin, `addons/box_resize/`): select a Block, CrumbleBlock, Gate, Zone,
  Plate or DialogueTrigger and drag the orange squares on its edges/corners. Snaps to 8 px (hold **Ctrl** for free),
  shows the size while dragging, and Ctrl+Z undoes it. If no handles appear: Project → Project Settings → Plugins → tick Box Resize.
  Change the snap step with `SNAP` at the top of `addons/box_resize/plugin.gd`.
- **Block** / **CrumbleBlock** / **Gate**: position = top-left; resize with `size`. Crumble: `crumble_delay`, `respawn_delay`. Gate: point `plate_path` at a Plate.
- **KeyItem** (`Scenes/Prefabs/key_item.tscn`, or Add Node → KeyItem): touch it and every node in its `targets`
  bursts apart (spark along the link, fragments in the obstacle's colour, tiny shake) and is gone for good.
  Connect: select the key → Inspector `targets` → Add Element → drag the obstacle (usually a Block) from the
  Scene dock onto the slot. One key can clear several obstacles. Dashed lines in the editor show the links
  (red X = missing target). Also: `activated_by`, `travel_time`, `shake`, `fragments`, colour/size/bob, optional
  collect/launch/impact sounds, `debug`. Callable from a DialogueCall as `trigger_key`. `look` = FIREWORK
  (rocket that flies to the target and explodes; the default) or GEM (diamond + spark along the link).
  Targets with their own break (Boulder) break their own way. Test setup: prototype
  `Mechanics/Test_Key` → `Level/Test_KeyBarrier`.
- **TetherAnchor** (ring): drag anywhere; the faint circle shows hook range. Prefer the prefab (see Prefabs).
- **LevelExit** (`Scenes/Prefabs/level_exit.tscn`, or Add Node → LevelExit): walk in → fade to black → load
  `next_scene`, and the next level fades in. Type a scene name without `.tscn` (`prototype`, `Level1`,
  `Levels/Level2`); names are looked up in `SCENES_FOLDER` at the top of `Scripts/Level/level_exit.gd`
  (`res://Scenes/`). The box shows green "EXIT → name" in the editor, or red if the scene can't be found.
  Also: `fade_time`, `activated_by` (EITHER / CONTROLLED / BOTH), `debug` (switch it off while testing).
  From a DialogueCall: Target `TetherRig`, Method `go_to_scene`, Args `["Level2"]` (or `["Level2", 2.0]` for the fade).
- **Zone**: `kind` = KILL / CHECKPOINT / PHASE / STAY / EXIT. PHASE uses `phase`; STAY uses `stay_time`.
- Ending text is in `Scripts/main.gd` (the TetherRig script) → `_check_zones()` (search "You stayed").

### Audio
- **Full guide: `AUDIO_GUIDE.md`** (music, ambience, triggers, the sever moment, every sound slot).
- Bus volumes: pause menu sliders, or the **Audio** panel at the bottom of the editor (buses: Master, Music, Sfx).
- Dialogue blip loudness: each DialogueLine's `text_volume` (default -10 dB).
- Controls: `Scripts/main.gd` → `_ensure_input()`, or define the same action names in Project Settings → Input Map (those win).

### Fonts

The font files live in `Fonts/` (each family in its own folder, with its `OFL.txt` licence):

| Text | Default font | Default size | Set by |
|---|---|---|---|
| Speech bubbles (every DialogueLine) | `Fonts/Neucha/Neucha-Regular.ttf` | 14 | TetherRig → Fonts → `dialogue_font`, `dialogue_font_size` |
| Centered messages (`show_message`, respawn fades, ending text) | `Fonts/DM_Serif_Display/DMSerifDisplay-Regular.ttf` | 26 | TetherRig → Fonts → `message_font`, `message_font_size` |
| Title card, main line (phase titles, `show_title`) | `Fonts/DM_Serif_Display/DMSerifDisplay-Regular.ttf` | 30 | TetherRig → Fonts → `title_font`, `title_font_size` |
| Title card, subtitle line | `Fonts/DM_Serif_Display/DMSerifDisplay-Regular.ttf` | 20 | TetherRig → Fonts → `subtitle_font`, `subtitle_font_size` |

Every font slot takes a `.ttf`, `.otf`, `.woff`/`.woff2`, or a `FontVariation` `.tres`. To change one,
**drag the file from the FileSystem dock onto the slot** in the Inspector. To go back to the
default, click the slot's ↺ revert arrow. If you clear a slot (right-click → Clear), that text
uses Godot's built-in font.

**Which font wins.** The most specific setting is used:

1. The font set on that one line, title or call (see below)
2. The TetherRig's **Fonts** group on the level's TetherRig instance (that level only)
3. The TetherRig's **Fonts** group in `Scenes/Prefabs/tether_rig.tscn` (every level)

#### Change a font for the whole game
Open `Scenes/Prefabs/tether_rig.tscn`, select the **TetherRig** root, expand **Fonts**, and drag
the new font onto `dialogue_font`, `message_font`, `title_font` or `subtitle_font`. Change the
matching `_font_size` if the new font looks too big or too small. Each font is a little bigger or
smaller than another at the same size (Neucha looks smaller than DM Serif at the same px).
Display/serif fonts like DM Serif have very thin strokes: below about 18 px they almost vanish
over the bright sky, which is why the subtitle defaults to 20. To add a drop shadow back to any of
the HUD texts, see "Colours and shadows" under Positioning the title card, message and FPS counter.

#### Change a font for one level
Select the `TetherRig` instance inside the level scene (e.g. `Level1.tscn`) and change its
**Fonts** group there. The level shows that field as overridden, and the other levels keep
the rig's fonts.

#### Change the font of one line of dialogue
Select the DialogueTrigger, open its `steps`, expand the **DialogueLine**, and drag a font onto
its **`font`** slot. Set **`font_size`** above 0 to change the size for that line too.
Empty `font` / `font_size = 0` = use the TetherRig's `dialogue_font` / `dialogue_font_size`.
BBCode works as before. `[font=res://Fonts/...ttf]word[/font]` and `[font_size=20]word[/font_size]`
also switch font or size for just a few words.

#### Change the font of one phase title
Double-click the phase `.tres` in `Data/Phases/` → **Title card** → drag a font onto
**`title_font`** (main line) and/or **`subtitle_font`**. Empty = the TetherRig's defaults.

#### Change the font of one scripted message or title (DialogueCall)
The font goes in the call's `args` array, after the normal arguments:

- `show_message` → `["Something's wrong.", 3.0, <font>]`
- `show_title` → `["Honeymoon", "Year 0", <title font>, <subtitle font>]`
- `show_ending` → `["The end.", <font>]`

In the Inspector: expand `args` → **Add Element** → click the new element's type icon (pencil) →
choose **Object** → drag the font file onto it. All earlier args must be filled in, so to set a
message font you must also give the seconds (e.g. `2.5`). To change **only the subtitle** of a
title, leave the 3rd element as **Nil** (null = default title font) and put the font in the 4th.

#### Add a new font file
1. In Explorer, copy the `.ttf`/`.otf` into a new folder under `Fonts/` (e.g. `Fonts/MyFont/`),
   with its licence file. You can also drag it from Explorer into the FileSystem dock.
2. Switch back to Godot. It imports the file automatically (a `.import` file appears next to it).
3. Drag it onto any font slot above.

Optional, in the **Import** dock (select the font file): `Antialiasing`, `Hinting`, `Generate Mipmaps`,
or `Multichannel Signed Distance Field` (MSDF) for text that stays sharp when scaled. Click **Reimport** after changing these.

#### Tweaks without a new file (FontVariation)
FileSystem → right-click `Fonts/` → **New Resource → FontVariation**, save it (e.g.
`Fonts/neucha_wide.tres`), set its `base_font` to the font file, then adjust `spacing_glyph`
(letter spacing), `spacing_space`, `variation_embolden` (thicker/thinner), etc. Drag the `.tres` onto
any font slot, the same as a `.ttf`.

#### Bold and italic in speech bubbles
Neucha has no bold or italic file, so for `[b]` and `[i]` the bubble uses a thickened / slanted copy
of whatever font the line uses. How strong this is: `BOLD_EMBOLDEN` and `ITALIC_SLANT` at the top of
`Scripts/Dialogue/speech_bubble.gd`. To use a real italic file for a few words, use BBCode:
`[font=res://Fonts/YourFont-Italic.ttf]word[/font]` (add the italic .ttf to `Fonts/` first).

#### Not covered by these settings
The F1 debug readout, the controls reminder, the pause menu and the editor-only labels still use
Godot's default font. Code: `Scripts/hud.gd` (`set_fonts`, `show_message`, `show_title`),
`Scripts/Dialogue/speech_bubble.gd` (`_apply_font`), `Scripts/main.gd` (Fonts group).

### Positioning the title card, message and FPS counter

These are real nodes you can see and drag in the editor:

```
TetherRig
└─ HUD
   ├─ TitleCard   (moves the title + subtitle together)
   │  ├─ Title     (main line, e.g. "Honeymoon")
   │  └─ Subtitle  (e.g. "Year 0", stacks under the title automatically)
   ├─ Message     (show_message, respawn fades, ending text)
   └─ FPS         (FPS counter, top left)
```

1. Open `Scenes/Prefabs/tether_rig.tscn` and switch to the **2D** view.
2. Find the blue rectangle: that's the game screen (1280×720). The HUD's sample text
   ("Honeymoon / Year 0", "Something's wrong.", "FPS: 60") is drawn in it, in the real fonts and sizes from
   TetherRig → Fonts. Zoom out (or press F with the HUD selected) if you can't see it.
3. Click `TitleCard`, `Message` or `FPS` in the Scene dock and **drag it** in the 2D view. Drag its edge
   handles to make the box wider or narrower (text is centered in the box, and long messages wrap at its width).
4. Press F5. The game uses those positions. The sample text is editor-only; in game the labels start empty.

Tips:
- **Anchors** (the green pins / Layout → Anchors Preset in the toolbar) decide what the position is relative
  to. TitleCard is anchored to the **top center**, Message to the **center**, FPS to the **top left**, so
  they stay in place on any window size or shape. If you move Message near the bottom, change its preset to
  **Center Bottom** so it stays near the bottom on tall/wide windows.
- Exact values: Inspector → **Layout → Transform → Position / Size** (or the anchor offsets).
- **Gap between title and subtitle:** TitleCard → Theme Overrides → Constants → `separation` (px, can be negative).
- **Colours and shadows:** select Title / Subtitle / Message / FPS → Theme Overrides → Colors
  (`font_color`, `font_shadow_color`, `font_outline_color`) and Constants (`shadow_offset_x/y`, `outline_size`).
- **Fonts and sizes** still come from TetherRig → Fonts (setting a font on these labels directly gets
  overwritten when the game starts). The FPS counter's size is on the FPS node itself (`font_size`).
- **Change it in `tether_rig.tscn`, not in a level.** Level1_Visual has *Editable Children* on its TetherRig,
  so anything you change on these labels inside the level (and save) becomes a level-only override that wins over
  the rig. If a change to the rig doesn't show up in a level, open the level, select the label, and click the
  revert arrow next to the overridden property (or delete that property's line under the level's node).
- Hide the preview while editing levels: select `HUD` → untick **`editor_preview`** (editor only, no effect in game).
  In a level scene the preview shows at the screen position (around the world origin), not over the level.
- Everything scales with the window, because Project Settings → Display → Window → Stretch → Mode is `canvas_items`.

### Web build
Exporting the game for browsers, testing it locally, and hosting it on GitHub Pages are all covered step by
step in **[EXPORT_GUIDE.md](EXPORT_GUIDE.md)**.

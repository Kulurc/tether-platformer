# Audio guide

Every sound in the game goes through the **SoundManager** autoload (`Scenes/Autoload/sound_manager.tscn`,
script `Scripts/Autoload/sound_manager.gd`). Nothing makes its own one-off audio players any more.

- **Sound effects** use `play_sound(sound, volume_db)`. It adds a small random pitch change, so repeated
  sounds don't sound identical. Everything with an exported sound slot below calls it for you.
- **Music** and **ambience** each have one player: `MusicPlayer` and `AmbiencePlayer`. Only one track
  plays on each at a time.
- **Buses** (Audio tab at the bottom of the editor): `Sfx` for effects, `Music` for music and ambience.
  Add effects (reverb, a low-pass for muffled moments) or set overall volumes there.

Volumes everywhere are in **dB**:

| dB | Meaning |
| --- | --- |
| 0 | As imported |
| -6 | About half as loud |
| -20 | Quiet |
| -80 | Silent |

## Importing files
- **Formats:** WAV for short effects, OGG for music and ambience (much smaller).
- **Looping music or ambience:** select the file in the FileSystem dock, tick **Loop** in the Import dock,
  then click **Reimport**. WAVs used as the cord's reel/slack loops are looped automatically.
- **Folders:** keep files under `Audio/`, e.g. `Audio/Music/`, `Audio/Ambience/`, `Audio/Sfx/`.

## The game's music (`Audio/Music/`)
All tracks were converted to OGG and loudness-matched to -18 LUFS, so at 0 dB they all sound equally loud.
They loop (Import dock -> Loop is ticked on each). The original files are kept in your Downloads folder.

| Where | Track | Set on | When |
| --- | --- | --- | --- |
| Main menu | `vampires_piano.ogg` | MainMenu -> `menu_music` | From the start; fades out when the player clicks to start |
| Level1_Visual | `harp.ogg` (-0.9 dB, 10% down) | TetherRig -> Audio -> `level_music` (in the level) | Silent through the black intro; fades in once the level is visible; fades out with the screen at the exit |
| Level2_Visual | `next_to_you.ogg` (-0.9 dB, 10% down) | same | same |
| Level3_Visual | `forest.ogg` | same | same, and cut dead when the cord is severed (TetherRig -> Sever -> `stop_music_on_sever`, ticked in this level) |
| Phase III | `dark_ambience_loop.ogg` | `phase_3_inseparable.tres` -> Sound -> `loop_sound` (-16 dB, 5 s fade in) | Under the level music while in phase III; stops dead when the cord is cut |
| Credits | `vampires_piano.ogg` | Credits -> `music` | From the start; keeps playing into the main menu (the menu sees the same track already playing and doesn't restart it) |

- Level music never plays over a black screen: the TetherRig waits until the black cover is fully gone,
  then fades the track in over `level_audio_fade` (3 s).
- To add a new track: drop it in `Audio/Music/`, tick **Loop** in the Import dock and Reimport. For matching
  loudness, normalise it to about -18 LUFS first (any audio editor's "loudness normalize"), or adjust its
  `*_volume_db` setting by ear.

## Music and ambience

### 1. Start them with the level
Select **TetherRig** in the level → **Audio** group:

| Setting | What it does |
| --- | --- |
| `level_music` | Starts (fades in) when the level loads |
| `level_ambience` | Same, for the ambience player |
| `level_audio_fade` | Fade-in time in seconds |
| `level_music_volume_db` / `level_ambience_volume_db` | Starting volumes |

- Leave a slot empty to keep whatever is already playing. Music carries over between levels, because
  the SoundManager stays alive when the scene changes.
- If the same track is already playing, it is not restarted.

### 2. Change them as the player walks: triggers
Use a **DialogueTrigger** (the same area node the dialogue uses) with a **DialogueMusic** step:
1. Add a DialogueTrigger under the level's `Dialogue` node. Drag its orange handles to cover the area
   where the change should happen.
2. Set `one_shot` on if it should only fire the first time.
3. In `steps`, add **New DialogueMusic**:

| Setting | What it does |
| --- | --- |
| `stream` | The new track. **Empty = stop.** |
| `ambience` | Off = the music player, on = the ambience player |
| `fade` | Seconds. Changing tracks fades the old one out and the new one in. 0 = hard cut |
| `volume_db` | Volume of the new track |
| `volume_only` | Keeps the current track and just moves its volume to `volume_db` (ducking). Use it to dip the music under an important line, then add a second DialogueMusic to bring it back to 0 |

You can mix these with dialogue in one trigger, for example:
`DialogueMusic (fade music down)` → `DialogueLine` → `DialogueLine` → `DialogueMusic (back up)`.

### 3. One-shot sounds from a trigger
In a trigger's `steps`, add **New DialogueSound**:

| Setting | What it does |
| --- | --- |
| `sound` | The sound to play |
| `volume_db` | Its volume |
| `exact_pitch` | No random pitch change |
| `wait_until_done` | The next step waits for the sound to finish |

### 4. From code or a DialogueCall
Target the SoundManager node at `/root/SoundManager`:

| Method | What it does |
| --- | --- |
| `play_music_fade(stream, fade, volume_db)` | Start or change the music with a fade. A null stream fades it out |
| `play_ambience_fade(stream, fade, volume_db)` | Same, for the ambience |
| `stop_music(fade)` / `stop_ambience(fade)` | Stop, with an optional fade |
| `set_music_volume(db, fade)` / `set_ambience_volume(db, fade)` | Duck or restore without stopping |
| `play_sound(stream, db)` | One-shot effect with the random pitch change |
| `play_sound_exact(stream, db, pitch)` | One-shot effect at a fixed pitch |

The original `play_music` / `play_ambience` (no fade) still work as before.

## The sever moment ("TACK!")
**TetherRig → Sever** group:

| Setting | What it does |
| --- | --- |
| `sever_sound` / `sever_volume_db` | Plays the instant the cord is cut, always at the exact same pitch |
| `on_sever` | Steps that run in order at that moment. Same step types as a DialogueTrigger |

Example: cut the ambience dead, let the silence sit, then bring in something new:
1. `DialogueMusic`: `ambience` on, `stream` empty, `fade` 0 (instant silence).
2. Optionally `DialogueMusic`: music, `volume_only` on, `volume_db` -80, `fade` 0.
3. `DialogueWait`: 2 seconds.
4. `DialogueMusic`: the new ambience, `fade` 4.

Any `DialogueCall` works here too (camera shake, a title, a method on your own node).

The rig also emits a **`severed`** signal at the same moment. Connect it in the Node dock if you
prefer signals.

Severing is only possible in phase III. Each phase file has a `can_sever` setting under Cord, and
only `phase_3_inseparable.tres` has it on.

## Sounds already in the game (`Audio/Sfx/`)
All generated for this project (the recipe is `Audio/Sfx/_make_sfx.py.txt`). One-shots go through
`play_sound`, so each play has a slightly different pitch.

| Sound | File | Where it's set | Volume |
| --- | --- | --- | --- |
| Footsteps (4, picked at random) | `Footsteps_Grass_Run_01..04.wav` (NOX Sound) | rig → Wisp/Ember → `footstep_sounds` | -14 dB, one step per 84 px walked (`step_distance`) |
| Landing | `Footsteps_Grass_Jump_Land_01.wav` (NOX Sound) | rig → Wisp/Ember → `land_sound` | -9 dB |
| Jump take-off | none (`jump_sound` empty) | rig → Wisp/Ember → `jump_sound` | - |
| Switch characters | `swap_woosh.wav` | rig → `swap_sound` | -16 dB |
| Hook onto a ring | `hook_klink.wav` | `tether_anchor.tscn` → `hook_sound` | -10 dB |
| Rocket launch | `rocket_launch.wav` | `firework_key.tscn` → `launch_sound` | -6 dB |
| Rocket impact / boulder breaks | `boulder_break.wav` | `boulder.tscn` → `break_sound` (the rocket's own `impact_sound` is empty) | +2 dB |
| Branch starts to give / breaks | `branch_creak.wav`, `branch_snap.wav` | `crumble_branch.tscn` | -14.5 / -12 dB |
| Cord snaps (fixed pitch) | `tether_snap.wav` | rig → Sever → `sever_sound` | 0 dB |
| Holding Q (loop, rises as you hold) | `sever_strain_loop.wav` | rig → Tether → `sever_strain_sound` | -10 dB |
| Reel / slack (loops) | `Audio/reel_loop.wav`, `slack_loop.wav` | rig → Tether | -13 / -15 dB |
| Phase III heartbeat (loop) | `heartbeat_loop.wav` | `phase_3_inseparable.tres` → Sound → `loop_sound` | -6 dB, 3 s fade in |

- **Holding Q** also shakes the camera, building up to TetherRig → Sever → `sever_hold_shake` (px);
  the shake, the stretch sound and the heartbeat all stop the instant the cord snaps.
- **Any phase can have its own loop**: open its `.tres` → Sound → `loop_sound` (fades in with the
  phase, fades out if a later phase takes over, stops dead when the cord is cut).

## Sound effect slots (where each sound lives)

| What | Where | Slots |
| --- | --- | --- |
| Footsteps, jump, landing | `Scenes/Prefabs/tether_rig.tscn` → **Wisp** and **Ember** → Sound group | `footstep_sounds` (list: each step picks one at random, so add 3-5 variations), `step_distance` (px per step), `jump_sound`, `land_sound`, `land_min_speed` (softer landings are silent), `partner_volume_offset_db` (the body you're NOT controlling plays quieter) |
| Swap, fall, respawn, checkpoint, new phase | TetherRig → Audio group | `swap_sound`, `fall_sound`, `respawn_sound`, `checkpoint_sound`, `phase_sound` |
| Intro cord reveal | TetherRig → Intro group | `tether_reveal_sound` |
| Sever | TetherRig → Sever group | `sever_sound` + `on_sever` |
| Cord reel in / pay out (loops) | TetherRig → Tether → Reel / slack feedback | `reel_sound`, `slack_sound` + volumes and fade time |
| Ring hook / release | `Scenes/Prefabs/tether_anchor.tscn` | `hook_sound`, `release_sound` |
| Branch creak / snap / regrow | `Scenes/Prefabs/crumble_branch.tscn` | `creak_sound`, `break_sound`, `regrow_sound` |
| Boulder breaking | `Scenes/Prefabs/boulder.tscn` | `break_sound` |
| Firework touched / flying / impact | `Scenes/Prefabs/firework_key.tscn` | `collect_sound`, `launch_sound`, `impact_sound` |
| Speech blips | Each DialogueLine | `text_sound`, `text_volume` |

Set a slot on the **prefab** (open the prefab file) and every level uses it. Set it on one copy in a
level and only that copy changes (it shows a ↺ revert arrow in the Inspector).

## Quick recipes
- **A level's music and ambience:** TetherRig → Audio → `level_music` + `level_ambience`.
- **Music swells as you reach a place:** a DialogueTrigger there → DialogueMusic (new track, fade 3).
- **Silence before a big moment:** DialogueTrigger → DialogueMusic (music, empty stream, fade 2) and the
  same for ambience.
- **Muffle everything** (e.g. underwater or numbness): add a LowPassFilter effect to the Master bus in the
  Audio tab. Toggling it from a script is `AudioServer.set_bus_effect_enabled(0, 0, true)`.

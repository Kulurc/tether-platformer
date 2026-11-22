# Tether - codependency sandbox

The game starts at `Scenes/MainMenu.tscn` (main scene). `Scenes/prototype.tscn` is the original test sandbox.

| Input | Keyboard / mouse | Gamepad |
|---|---|---|
| Move / jump | A D (arrows) / Space, W | Left stick / A |
| Swap who you are | R | X |
| Hook / let go of a ring | E | RB |
| Reel in (hold) | LMB | RT |
| Slack out (hold) | RMB | LT |
| Sever (hold 1 s) | Q | Y |
| Restart / debug | Backspace / F1 | Back |

## The two of them

| | Wisp (white rect) | Ember (amber circle) |
|---|---|---|
| Run | 240 | 200 |
| Jump | 112 px (clears the phase II climb) | 80 px (can't) |
| Mass / grip | 1.0 / 2.4 W | 1.5 / 3.0 W |
| Role | reaches places | holds things down |

Either can be controlled. The other runs on `PartnerAI` and simply follows: it walks your
way and jumps gaps and steps it can clear (it checks its own jump reach). When it can't,
it stops and shows "...".

## Who holds (the rule)

A body is **planted** when its feet are down and it isn't trying to move (whether you or
the AI is driving it). A planted body ignores the cord until the *smoothed* pull beats its
grip. If both are planted, the lower grip gives way first. **Whoever is reeling digs in
(+1.5 W)**, so the rule a player learns is: *the one reeling holds; the other one comes.*

## The three phases (`Data/Phases/*.tres` - see EDITING_GUIDE.md)

Phases only escalate, and the cord's memory survives respawns.

| | I. Together | II. Closer | III. Inseparable |
|---|---|---|---|
| Cord ceiling | 440 | 320, then **ratchets down to 150** while you're apart > 1.2 s | 120 |
| AI | *mirror*: walks your way, competent | *anxious*: predicts you, stays closer, **copies your jumps** (sometimes into pits) | *clinging*: closest; **holds on 0.45 s** when you leave; panics after a tug |
| Pulling away | drag | drag + cord shortens | **tug**: >1.3 W away = yanked back + 0.22 s stagger, partner panics |
| Swap | clean | your input drives the old body for 0.12 s | new body **hesitates 0.3 s** while the **old one still obeys you 0.3 s**; marker vanishes |
| Look-alike | 0 | 35% colour + outline | 80% |
| Separation feel | faint | cold, grey, vignette; **your movement goes floaty** | full |
| Closeness feel | warm, slow pulse | same | same |

The sandbox (≈2 min) teaches each phase:
1. **I:** small gap and step (the AI jumps them). Then a 220 px gap with a ring: swing across, then reel the other one over.
2. **II:** a crumble bridge (the anxious AI copies your jump and falls; you reel it up), then a 96 px climb only Wisp can make. If you're Ember, you have to swap.
3. **III:** a small gap (tugs, panic), a lit nook, and a plate-held door.
   - **Stay:** stand in the nook together for 3 s, ending *"You stayed."*
   - **Leave:** the partner won't stay on the plate while you're tethered. Hold Q to sever; now neither follows the other. Swap, park one on the plate, swap back, walk out. Ending: *"You are free. It is unbearable."*

## Game-feel decisions (and why)

| Decision | Why |
|---|---|
| One rule for "planted", shown live in the F1 readout | Previous version felt random; now it's predictable from what you see |
| Reeler gets +1.5 W grip | Without it, light Wisp reeling heavy Ember got pulled into the gap instead (playtested) |
| Slipping is decided on smoothed tension | Single-frame jolts (landings) no longer flip who's holding |
| Tug keyed to *force*, not stretch | Stretch-based tug never fired; force-based fires exactly when the partner holds on |
| Tug: 300 px/s yank, 0.22 s stagger, 0.9 s cooldown, small camera shake | Felt, readable, not a stun-lock |
| Leash shrinks 40 px/s after 1.2 s apart (phase II) | Slow enough to notice and react; permanent so it means something |
| Gate closes the instant the plate is released | A 0.4 s grace let the leader slip through while the partner just walked over the plate |
| Swap during a hook releases the hook | Hook belongs to whoever is driving |
| Severed: both bodies 1.2x speed/jump, partner stops following | "It feels like a good platformer again", and you get two individuals back |
| Separation degrades *your* control (floaty) rather than the partner pulling | The concept asks for withdrawal to be felt, not seen |

## Difficulty stance

Gentle precision, with the friction coming from the relationship, not from the jumps.
- Instant respawn at checkpoints. Checkpoints only save if your partner is with you.
- The cord catches nearly every fall; the AI's mistakes become rescues, not deaths.
- Phase III is *deliberately annoying* (hesitation, tugs, input bleed). Keep it short; it is
  the argument, not the challenge.
- Measured in scripted runs: phase I ring haul, phase II climb + haul, phase III sever-and-plate
  solution, and the stay ending all complete. The cord didn't break in normal play; the peak was a 4.1 W jolt when Ember fell on the short phase III cord (break is 4.2 W).

## Open decisions for you

1. **Sound:** the concept leans on audio (a steady pulse when close, a thin tone when apart). Nothing is in yet; want a generated placeholder?
2. **Muscle memory:** the AI copying your routes and timing isn't implemented (record your inputs and replay them in phase III?).
3. **Can you re-tether after severing?** Currently no. The concept suggests relief *and* guilt on re-tethering.
4. **Phase III tug strength:** right now it's annoying-by-design. Playtest whether it reads as "toxic" or just "bad controls" (the debug readout shows when it fires).
5. **No look-alike blending:** the two bodies always keep their own colour and outline (removed, it didn't fit the theme).

## Dialogue triggers (`Scripts/Dialogue/`)

1. Add an **Area2D**, attach `dialogue_trigger.gd` (or add a `DialogueTrigger` node). With no
   collision shape of its own it uses `size` (top-left = position); add your own
   CollisionShape2D to override. Fires when either character enters; `one_shot` by default.
2. In **Steps**, add slots and pick **New DialogueLine** or **New DialogueCall**:
   - **DialogueLine** - `speaker` (GIRL = Wisp, BOY = Ember, via each Character's `speaker`),
     `message` (multiline), `text_speed` (letters/s, 0 = instant), `text_volume` (dB added:
     0 normal, -100 silent, +10 louder), `text_sound` (blip per letter, pitch randomised by
     `SoundManager.play_sound`), `appear_time` (s after fully typed, default 5).
   - **DialogueCall** - drag a node onto `target`, type `method`, optional `args`. If the
     method is a coroutine (`await`s), the sequence waits for it.
3. Bubbles follow the speaker, use the speaker's `bubble_tint`, show no name. If two triggers
   fire together, the second waits for the first.

Examples in the sandbox: `Dialogue/Intro` (ends with a DialogueCall that shows the phase I
title), `Dialogue/II_Closer`, `Dialogue/III_Inseparable`. Placeholder blips: `Audio/`.

## Audio & pause

- `SoundManager` autoload (`Scenes/Autoload/sound_manager.tscn`): Music and Ambience players on
  the **Music** bus; `play_sound` uses **Sfx**. Buses live in `default_bus_layout.tres`.
- **Esc** (or Start) pauses: the whole SceneTree stops, so bodies keep position *and*
  velocity; tweens, bubbles and crumbling blocks freeze. SoundManager runs while paused so
  music keeps playing. Master / Music / SFX sliders are saved to `user://settings.cfg`.

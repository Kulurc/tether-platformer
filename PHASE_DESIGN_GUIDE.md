# Tether — Phase Design Guide

A guide for level designers: what each relationship phase **feels like**, what it **changes**, and
**how to build levels for it**. All numbers are the current values in `Data/Phases/*.tres`.
To change one, open that file in Godot and edit the field named in `code`.

---

## The arc in one minute

| | **I. Together** (Year 0, honeymoon) | **II. Closer** (Year 3, conflict) | **III. Inseparable** (Year 7, threshold) |
|---|---|---|---|
| **The feeling** | Light, free, playful. Being tied together is a bonus. | The tie starts to cost something. Space is punished; closeness is rewarded. | Suffocating. You can't move without them, and they won't let you go. |
| **The cord** | Long and forgiving | Shrinks every time you drift apart | Permanently short |
| **The partner** | Your mirror: walks when you walk | Anxious: moves before you, copies every jump | Clinging: plants its feet every time you leave, yanks you back |
| **Your body** | Normal | Mushy and floaty when apart | Very mushy when apart, delayed when you swap |
| **The screen** | Warm, a hint of cold when apart | Cold and vignetted when apart | Fully cold when apart; your silhouettes blur together |
| **The player learns** | "We're a team." | "Don't wander off." | "I can't do anything alone... should I cut it?" |

**The rule of thumb:** every phase takes away a freedom the player enjoyed in the phase before.
Build each level so the player *misses* the previous phase.

---

## Everything at a glance

What each setting means in plain words, and its value in each phase.

### The cord

| Setting | What it means for the player | I | II | III |
|---|---|---|---|---|
| `max_length` | Furthest apart the two can ever be (px) | **440** | **320** | **120** |
| `rest_length` | Length the cord relaxes to when you both stand still | 200 | 150 | 90 |
| `comfort` | Beyond this distance you count as "apart" (screen goes cold) | 170 | 110 | 70 |
| `shrink_after` | Seconds apart before the cord starts shortening itself | off | **1.2 s** | off (already short) |
| `shrink_speed` | How fast it shortens (px/s). **It never grows back.** | – | 40 | – |
| `leash_floor` | Shortest the cord can shrink to | 440 | **150** | 120 |

### The partner (AI)

| Setting | What it means for the player | I | II | III |
|---|---|---|---|---|
| `ai_mode` | MIRROR walks the way you walk; FOLLOW only closes the distance | MIRROR | FOLLOW | FOLLOW |
| `follow_distance` | How close it tries to stay (px) | 90 | 50 | **30** |
| `predict` | Moves *before* you do (seconds of your speed it guesses ahead) | 0 | **0.35** | 0 |
| `mirror_jump_chance` | Chance it copies your jump, **even into a pit** | 0 | **100%** | 0 |
| `safe_drop_height` | Tallest ledge it will walk off by itself (px) | 200 | 200 | 200 |
| `hold_on_chance` | Chance it plants its feet when you walk away | 0 | 0 | **100%** |
| `hold_on_time` | How long it holds on each time | – | – | 0.45 s |
| `hold_on_cooldown` | Minimum gap between hold-ons | – | – | 0 s (every time) |

### The tug (phase III only)

| Setting | What it means for the player | III |
|---|---|---|
| `tug_enabled` | Pulling away hard enough yanks you back | **on** |
| `tug_force` | How hard you must pull before it counts (1 W = one body's weight) | 1.3 W |
| `tug_impulse` | Strength of the yank back toward them (px/s) | 300 |
| `tug_stagger` | How long you lose control after a yank | 0.22 s |
| `tug_cooldown` | Minimum gap between yanks | 0.9 s |
| `panic_time` | After a yank the partner panics: runs and jumps at you blindly | 1.2 s |
| `tug_camera_shake` | Screen shake on a yank (px) | 6 |

### Swapping (Tab)

| Setting | What it means for the player | I | II | III |
|---|---|---|---|---|
| `swap_delay` | The body you swap into ignores you for this long | 0 | 0 | **0.3 s** |
| `control_bleed` | Your input still moves the *old* body for this long | 0 | 0.12 s | **0.3 s** |

### Look & feel

| Setting | What it means for the player | I | II | III |
|---|---|---|---|---|
| `anxiety` | Strength of the cold filter + vignette when apart (and the warm pulse when close) | 0.25 | 0.8 | **1.0** |
| `floaty` | How much being apart degrades *your* movement (see below) | 0 | 0.5 | **1.0** |

**What `floaty` does:** when you're apart, your gravity drops by up to 30% and your acceleration by up to 45%,
scaled by how far apart you are. Jumps get higher and floatier, and turning gets sluggish. It only
affects the body you control, and only while tethered.

---

## Measurements that never change

Use these to size gaps, steps and ledges. They are the same in every phase.

| Measurement | Value | Design meaning |
|---|---|---|
| Wisp jump height | **112 px** | Tallest step she can climb alone |
| Ember jump height | **130 px** (Level1 override; prefab default 112) | Tallest step he can climb alone |
| Jump reach (flat, full run-up) | **~155 px** Wisp / **~142 px** Ember | Widest gap each can clear alone. Ember is a little slower (220 vs 240 run speed). |
| Partner's comfortable jump | 90% of the above | The AI only attempts jumps within 90% of its height/reach |
| Hook range | **180 px** | How close you must be to a ring to press E |
| Reel / slack speed | 170 / 220 px/s | How fast the cord shortens / lengthens on LMB / RMB |
| Reel strength | **3.2 W** | Reeling can lift a planted partner (grip 2.4 W) but stalls above 3.2 W |
| Cord snaps | **4.2 W for 0.35 s** | Pulling too hard for too long = "The tether gave way." (respawn) |
| Cord stretch | +40 px beyond its length | Hard stretch limit before it holds firm |
| Checkpoint | Partner within **220 px**, or cord severed | Checkpoints only save if you arrive together |
| After severing (hold Q for `time_to_sever`, 2.5 s, phase III only; no more swapping) | **+20% run speed, +20% jump speed** (≈ 44% higher jumps: ~161 px Wisp / ~187 px Ember; reach ~205–225 px) | Free is faster... and lonely |

**Rule of thumb for gaps:** a gap is safe for the **partner** only if it's under ~140 px (90% of the
shorter reach). Anything wider has to be solved with the cord: reel them across, swing from a ring, or
swap and carry the other one over.

---

## Phase I — Together (Year 0: honeymoon)

> *"Two of you. Either one can lead."*

**Intention:** the tether is a gift. Show everything the two of you can do *together* that one couldn't
do alone. No punishment and no pressure; mistakes are cheap.

**What the player experiences**
- A long cord (440 px). They can wander, explore and come back.
- The partner mirrors them, so it feels like moving one happy body.
- Separation is barely noticed (a faint cold tint past 170 px).
- Swapping is instant; either character can lead.

**Build for it**
- **Teach every verb**, one at a time, with room to play:
  1. walk together
  2. jump a small gap (under 140 px)
  3. a step one can climb and the other can't (between 112 and 130 px: Ember can, Wisp can't). The player swaps to Ember, climbs, and **reels** Wisp up.
  4. the first **ring**: hook (E) and swing
  5. **slack** (RMB) to let the partner down a drop
- Make the cord feel like a **superpower**: ledges taller than both jumps (over 130 px) that you can
  only beat by one climbing and reeling the other up, and wide gaps you can only cross by swinging.
- Generous spaces: wide flat ground, gentle steps, rings with safe ground under them.
- Put **distance** in the level (the cord is long here), so phase II can take it away.

**Avoid**
- Pits that kill you for a small mistake.
- Anything that requires being far apart for a long time (save that contrast for phase II).

**Mood:** sunshine, colour, open sky (the Level1_Visual meadow).

---

## Phase II — Closer (Year 3: conflict)

> *"The cord remembers how far apart you were."*

**Intention:** closeness becomes an obligation. Being apart now has a **lasting cost**: the cord
shrinks and never gives the length back. The partner gets anxious: it rushes ahead and copies you
even when it's dangerous.

**What the player experiences**
- The cord starts at 320 px. Stay further apart than 110 px for more than 1.2 s and it starts
  shrinking at 40 px/s, down to 150 px. **Separation is spent from a budget that never refills.**
- The partner (FOLLOW, 50 px) **predicts** your movement and **copies every jump**, even into pits.
- When apart, your own movement goes mushy and floaty, and the screen goes cold.
- Swapping has a tiny lag: for 0.12 s the old body still answers your input.

**Build for it**
- **Temptation to split up:** sections that are *easier* if one goes ahead alone (a pressure plate held
  by one while the other crosses, a shortcut only one can reach). They work, but they cost cord length
  for the rest of the level. Let the player feel that cost later.
- **Jump copying:** place a pit right after a jump the player *wants* to make, so the partner copies them
  into the pit. The player then has to **reel** or **catch** them.
  - Crumble blocks and narrow ledges make this sharper.
  - The partner jumps on the same beat as you, so give landings room for two.
- **Order your obstacles by cord length:** early obstacles can need around 300 px of cord, later
  ones around 150 px. A careful player arrives with more cord than a careless one, so give careless
  players a way through that's harder, not impossible.
- Rings still work, but swings now need you to be closer together.
- Keep gaps under about 140 px unless you mean to force a reel or swing.

**Avoid**
- Areas where the shortened cord makes the level **impossible** (no softlocks). Everything must be
  doable at the 150 px floor.
- Requiring frame-tight swaps (there's a 0.12 s delay).

**Mood:** duller colours, overcast. The world is "much more dull/stale" (from the notebook).

---

## Phase III — Inseparable (Year 7: threshold)

> *The cord is short. They won't let you go.*

**Intention:** codependency at its peak. You can't take a step without them; they hold on every time you
try to leave, and pulling away hurts. The level should make the player ask: *should I cut the cord?*

**What the player experiences**
- A fixed, very short cord: **120 px** (plus 40 px of stretch).
- **Every time** you walk away, the partner plants its feet for 0.45 s. You move in short, stuttering
  bursts.
- Pull away harder than 1.3 W and you get **yanked back** (300 px/s): you lose control for 0.22 s, the
  camera shakes, and the partner panics for 1.2 s, running and jumping at you blindly.
- Swapping is delayed (0.3 s) and blurred (0.3 s of input bleed).
- Apart = fully cold screen and very floaty, unreliable movement.

**Build for it**
- **Short, tight steps.** Gaps under about **100 px**, because both bodies must cross while staying
  within about 120 px of each other.
- **Everything is done together.** Jumps, climbs and swings all happen in lock-step. Rings should be close
  together with low swings.
- **Slow, deliberate pacing.** The hold-on and tug make movement stutter, so don't time anything tightly.
  No chases, no crumbling floors under pressure.
- **Make severing tempting.** Put spots where cutting the cord (hold Q for `time_to_sever`, 2.5 s - only possible in phase III) is *clearly* easier:
  a gap only a free body can clear (when free, reach rises to about 205–225 px and jump height by about 44%),
  or a climb that's miserable while tethered.
- **The final stretch** (from the notebook): a long stairway. Two ways through:
  - **Drag the partner with you:** slow, constant tugs and reeling, but possible. It leads to the
    STAY or "You left together" ending.
  - **Sever and walk on:** fast and easy. It leads to the EXIT ending: "You are free. It is unbearable."
  - Make **both** paths possible. The choice is the point.

**Avoid**
- Anything requiring the two of you to be more than about 120 px apart (impossible here).
- Timed swaps or precise solo platforming (input is delayed and blurred on purpose).
- Kill pits where a single tug can throw you in; it feels unfair rather than meaningful.

**Mood:** stale, near monochrome. Only the cord keeps its colour.

---

## Placing phases in a level

- **Phase zones** (`Zone` node, kind = PHASE, `phase` = 1, 2 or 3): walking into one escalates the phase.
  Phases **never go backwards**.
- When the cord's max length drops on a phase change, it **tightens gradually** (90 px/s). Don't put a
  hazard right after a phase zone.
- Each phase shows its title card when it starts (turn it off with `show_title`).
- **Checkpoints** only save when the partner is within 220 px. Put them where the two naturally stand
  together: tops of climbs, after a swing lands.
- **Endings** (also zones):
  - **STAY:** both inside, still tethered, for 3 s → *"You stayed. There was nowhere else to be."*
  - **EXIT** while severed → *"You are free. It is unbearable."*
  - **EXIT** together → *"You left together."*

## Quick checklist for any new section

- [ ] Every gap is checked against the partner's reach (about 140 px), not just the player's.
- [ ] Every step taller than one character's jump has a reel or swing solution.
- [ ] Phase II: still solvable at the 150 px cord floor.
- [ ] Phase III: nothing requires being more than about 120 px apart; nothing is timed tightly.
- [ ] Checkpoints sit where both naturally end up together.
- [ ] The section takes away something the player enjoyed in the previous phase.

*Debug keys while testing: **F2** next phase, **F3** next checkpoint, **F4** slow motion, **F5** reset
cord memory. Shift+F1 shows the live readout: cord length, cap, tension, who's planted.*

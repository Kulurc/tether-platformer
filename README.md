# Tether

A two-character platformer about a relationship, tied together by a cord. Made in Godot 4.5.1.

**Play in the browser:** https://kulurc.github.io/Platformer/ (keyboard and mouse)

| Input | Keys |
|---|---|
| Move / jump | A, D / Space |
| Switch character | Tab |
| Hook a ring | E |
| Reel in / pay out | Left mouse / right mouse |
| Cut the cord (late in the game) | Hold Q |

## Repository layout

| Path | What it is |
|---|---|
| `project.godot` | Open this folder in Godot 4.5.1 |
| `Scenes/` | `MainMenu` → `Level1_Visual` → `Level2_Visual` → `Level3_Visual` → `Credits`. `Level1-3` are the un-dressed source layouts the `_Visual` levels were built from; `prototype` is the original test sandbox |
| `Scripts/`, `Shaders/`, `Data/` | Game code, shaders and the phase settings (`Data/Phases/*.tres`) |
| `Art/`, `Audio/`, `Fonts/` | Sprites, music and sound effects, fonts |
| `docs/` | The exported web build that GitHub Pages serves (don't edit by hand; re-export) |

## Guides

- `EXPORT_GUIDE.md`: exporting the web build and hosting it on GitHub Pages
- `EDITING_GUIDE.md`: editing levels, art, characters, menu and credits
- `AUDIO_GUIDE.md`: music, ambience and sound effects
- `PHASE_DESIGN_GUIDE.md`, `DESIGN.md`: how the relationship phases work and the design notes

## Credits

A game by Kyle Asuncion.

- Music: `harp.ogg`, `next_to_you.ogg`, `forest.ogg` (add the composers / sources here)
- Ambience: "Dark Ambience Loop" by Iwan Gabovitch; `dusk_pig_farm_ambiance.ogg` (add source)
- Footsteps: NOX Sound Essentials

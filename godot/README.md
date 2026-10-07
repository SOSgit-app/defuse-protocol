# Defuse Protocol — Godot port

Native Quest / desktop path. The live WebXR game is unchanged in `../public/`.

## Open it

1. Godot **4.3+** (4.7.2 is fine).
2. Open this `godot/` folder → **Project → Reload Current Project** (autoloads `Sound` / `Prefs`).
3. Press **Play**.

## Play loop

- **Home:** difficulty, optional seed, Settings, Start Mission.
- **Desktop:** drag to orbit, scroll zoom, click modules, **Esc** pause.
- **Quest:** OpenXR lasers + trigger, left **Y** pause (Resume / Settings / Main Menu).
- **End:** restart same seed, new bomb, or main menu.

Settings: per-difficulty timer & strikes, optional Uninvited Fly (desk fan on the left kills it).

## Modules

| Type | Name |
| --- | --- |
| wires | Wire Cutting |
| symbols | Symbol Matching |
| memory | Memory Sequence |
| morse | Morse Code (SND / RST / TX) |
| logicgrid | Joint Functions (+ clipboard) |
| ordnance | Weapons Release |
| comms | Radio Net |
| threatplot | Threat Plot |
| brevity | Brevity Code |

Logic matches `server/modules/*.js` and `data/modules/*.json` (under `godot/data/modules/`).

Do not deploy `godot/` to GitHub Pages — classroom play stays on  
https://sosgit-app.github.io/defuse-protocol/

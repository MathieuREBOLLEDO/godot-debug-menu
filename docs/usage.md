# User guide

What every menu and tool does. For the code side, see the
[API reference](api.md).

## The bar

```
wide screen  : [Core] [★ Favorites] [Objects] [Scene] [Cheats] [your menus]   …   ● REC  🖱 Both  ⚙
narrow screen: [Core] [‹ Objects ›] [your menus ▾]                            …   ● REC  ⚙
```

- **Core** and your game's menus stay on the left; **REC** and **⚙ Settings**
  on the right.
- When the bar runs out of room, the middle menus fold into a single field:
  the ‹ › arrows (or the mouse wheel) cycle through them, and the mouse mode
  moves to the bottom of your first menu (or of Core).
- Your game's menus are never folded: the one named after the project
  (`application/config/name`) and those declared with
  `DebugMenu.set_game_menu("Name")`.
- Hovering a menu opens it; clicking its button keeps it open. `▸` marks a
  submenu, opened on hover, to the right or left depending on space.
- On mobile, a three-finger tap (fingers down together, lifted quickly,
  without sliding) shows or hides the bar.

### Menu tree

```
Core     Console · Performance · Free camera · Screenshot
         Time ▸     ☐ Time controls · Speed and frame stepping · Recordings
         Display ▸  ☐ Performance overlay · Input display · Selection outline
                    · Collision shapes · Navigation
                    Physics ▸   ☐ Collision shapes · Center of mass · Velocity
                                · Trajectory (3 s) · Contacts and normals
                    Gizmos ▸    ☐ one checkbox per category (Default, ...)
                    Grid ▸      ☐ World grid · Cell under the mouse
                                · Occupied cells · Sprite frames · Grid settings
                    Dithering ▸ ☐ Dithering · Dithering settings
         Screen ▸   ☐ Safe area · 16:9 · 4:3 · 19.5:9 · 21:9
Objects  Inspector · Physics · Signals · Watch · Variable finder
Scene    Node tree · Node events · Resources · Snapshots and seed · Reload scene
Cheats   Cheat codes
```

## Windows

- **☆** adds a window to **Favorites**; the **pin** keeps it on screen while
  the bar is hidden.
- The session is restored at launch: open windows, positions, sizes, pins
  and the last selection.
- **Mouse modes** (the 🖱 button cycles them; also in Settings > General):
  **Debug** (clicks outside the windows don't reach the game), **Game**
  (windows let clicks through), **Both**. The Settings window always stays
  clickable.
- **Language**: Settings > Language (English / Français), kept between
  runs. Open windows are reopened at the same place; their internal state
  (for example the Inspector history) starts over.

## Selecting an object

There is one selected object for the whole menu, and every object window
follows it. Select with the **picker** (F8, needs a collision shape, except
for Sprite2D and UI controls), the search field of the selection bar, a
click in any list, or a click on an object value. In lists, a click selects
and a double-click opens the Inspector.

## Objects

- **Inspector**: the object's variables, with type, initial value and current
  value, plus a one-minute history. `Init*` means the value when the object
  was selected (Godot doesn't expose the default of non-exported variables).
  Current values are editable: checkbox for bool, number field (with
  `@export_range` bounds) or list for enums, text for String, NodePath,
  vectors and Color (`1, 2` is enough for a Vector2; the pipette button picks
  a color). Objects, arrays and Rect2 are read-only. The eye icon adds a
  variable to Watch.
- **Watch**: the variables you follow, grouped by object, live and editable.
  × removes one, Clear (two clicks) empties the list. The list is kept
  between runs by node path: a variable whose object isn't loaded is hidden
  and comes back when it is. Double-click opens the object in the Inspector.
- **Variable finder**: searches loaded objects for a variable by name (and
  optionally by value: `true`, `Player`…). Scope: active objects, inactive,
  all, or the selection and its children. Godot's built-in properties are
  optional. Up to 200 results, refreshed as you type.
- **Signals**: log of the signals emitted by the selected object (time,
  frame, arguments), with a text filter and a "script signals only" option.
  Keeps the last 500 emissions. Signals with more than 6 arguments aren't
  listened to.
- **Physics**: the body linked to the selection (itself, its parent or a
  direct child): layers, motion, shapes, and the lists "touching now",
  "can touch (mask)" and "by layer", each highlightable.

## Scene

- **Node tree**, **Node events**, **Resources**: what is loaded, in which
  order, what was freed and what is still in memory, with Godot's counters at
  the bottom.
- **Reload scene** (also the `reload` command): applies the fixed seed if
  there is one, otherwise a new seed.
- **Seed** (Snapshots and seed window, `seed [value | random]` command):
  shows the current seed; "fixed seed" reapplies it at launch and on every
  reload (kept between runs). Only Godot's global random functions (`randi`,
  `randf`…) are affected: your own `RandomNumberGenerator` objects and the
  autoloads placed before `DebugMenu` aren't.
- **Snapshots** (window, `snapshot [name]` and `restore [n]` commands): a
  photo of the scene in memory (10 at most, lost when the game closes),
  restorable several times. Kept: nodes (even those created at runtime),
  stored properties, script variables (a referenced node is found again by
  its path), the selection. Not kept: autoloads, Timer, Tween, AnimationPlayer
  position, physics internal state, randomness. A resource modified at
  runtime is shared. `_ready()` runs again (a node that creates children in
  `_ready()` creates them again).

## Time

- **Pause** (F7) and **next frame** (F10). One frame = one
  `_physics_process` and one `_process` for the game's nodes (autoloads
  placed before `DebugMenu` don't follow exactly).
- **Speed and frame stepping**: fine speed slider and frame-by-frame playback
  with a delay.
- **REC** (F9): reloads the scene and records the player's actions (the
  state of every InputMap action on every physics frame). A second press,
  pausing or closing the game stops the take, and Recordings opens.
- **Recordings**: Play (or double-click), Stop, Restart, progress and drift.
  The scene is reloaded with the same random seed and `time_scale`, and the
  game recomputes everything. During a replay, the bar's speed is a faithful
  slow motion (x1 at most). Limits: the mouse isn't recorded, autoloads aren't
  reset, your `RandomNumberGenerator` objects aren't reseeded.

## Tools

- **Console**: Enter runs, ↑ / ↓ history, Tab completes; the debug menu
  shortcuts are off while typing. Built-in commands: `help`, `clear`,
  `pause`, `resume`, `step`, `speed`, `reload`, `select`, `tp`, `screenshot`,
  `seed`, `snapshot`, `restore`, `quit`. On Godot 4.5+, the log also shows the
  game's prints, warnings and errors, with filters.
- **Performance**: graphs of the last 30 seconds (FPS, frame and physics
  time, draw calls, nodes, objects, orphans, memory, video memory); a compact
  overlay can be checked in Core > Display.
- **Free camera** (Ctrl+F): replaces the game camera, which comes back
  untouched on exit; the game is paused during the flight (optional).
  - 3D (an active Camera3D): FPS movement with W A S D (Z Q S D on AZERTY,
    labels follow the keyboard), E / Q up / down, Shift faster, hold right
    click to look around, wheel for speed (view size for an orthographic
    camera). FOV, speed and sensitivity in the window.
  - 2D: W A S D, wheel zooms toward the mouse, drag with the right or middle
    button.
  - Runs in real time, even when the game is paused or slowed.
  - Left click teleports the player (`DebugMenu.set_player`) where you click
    (3D: where the click hits the scene, otherwise 10 m in front of the
    camera), velocity reset. If the player has a `debug_teleport(position)`
    method, it is called instead.
- **Screenshot** (F12, Core > Screenshot or `screenshot`): the debug menu is
  hidden during the capture; PNG saved in `user://debug_menu/screenshots`,
  path printed in the console.

## Display

Every drawing in the game can be turned off from Core > Display, and screen
guides from Core > Screen.

- **Collision shapes**: every CollisionObject2D near the screen, colored by
  type (static, rigid, character, area). TileMapLayer collisions (Godot 4.3+)
  are refreshed every 2 s.
- **Navigation**: NavigationRegion2D polygons, and the path, target and
  radius of each NavigationAgent2D.
- **Physics overlays**: center of mass, velocity, 3 s trajectory, contacts
  and normals.
- **Gizmos**: shapes drawn by your game (`DebugMenu.draw_line`…), one
  checkbox per category.
- **Grid**: one line per cell over the game, stronger every 5 cells, column
  and row numbers, level frame; at the bottom left, cell, screen and level
  sizes in cells and pixels.
  - *Cell under the mouse*: highlighted with its coordinates.
  - *Occupied cells*: cells more than half filled by a tile (TileMapLayer,
    4.3+) or a StaticBody2D, one color per collision layer, with a legend.
  - *Sprite frames*: every visible Sprite2D, AnimatedSprite2D, and every
    TextureRect / ColorRect placed in the world, with name, image size and
    place in cells.
  - Cell size: Grid settings (manual), otherwise `DebugMenu.set_grid()`,
    otherwise the tiles of the first TileMapLayer, otherwise 16 px.
- **Input display**: the game actions currently pressed (with strength when
  analog) and mouse buttons, at the bottom of the screen; also shown during
  a replay.
- **Dithering**: a full-screen filter under the debug drawings: Bayer matrix
  2, 4 or 8, levels per channel, pixel size, strength, color / gray /
  two-color palette. Kept between runs.
- **Screen guides**: the safe area (on desktop: the screen without the
  taskbar) with the rest darkened, and the largest centered frame of each
  aspect ratio (turned for portrait) to see what another screen would crop.

## Cheats

The Cheat codes window (Alt+C) has a Base tab, then one tab per category of
your game's cheats (`DebugMenu.add_cheat`).

- **No clip** (Ctrl+G): the player (`DebugMenu.set_player`, a physics body)
  loses its collisions and its `_physics_process` and flies with the arrows,
  W A S D, stick or d-pad (3D: E / Q up / down, movement follows the camera;
  Shift faster). Everything is restored when it stops. A player with a
  `debug_set_noclip(on)` method handles it itself.
- **Invincible** (Alt+V): calls `debug_set_invincible(on)` on the player, or
  your game reads `DebugMenu.cheats.invincible`.
- **Speed** (Alt+1 to Alt+5): picking a speed unfreezes the game.
- **Freeze** (Ctrl+D): the debug menu pause (same as F7).

## Global menu (optional)

Shown only in projects whose `project.godot` has a `project_init/version`
setting (written by the companion *project_init* addon); otherwise nothing of
it is loaded. It lists the project settings, current scene, pause state and
autoloads, and opens any autoload in the Inspector.

## Settings (⚙)

Language, mouse mode, appearance (accent, background, size, font) and
shortcuts. Everything is saved per machine in `user://` and never changes
your project.

Shortcut keys are physical (same position on every layout: Alt+& to Alt+( on
AZERTY for speeds). An action already present in `project.godot` keeps its
key: check it has its Ctrl / Alt in Project > Project Settings > Input Map.

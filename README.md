# Debug Menu for Godot 4

An in-game debug menu bar for Godot 4: inspect and edit objects while the
game runs, pause and step frames, record and replay inputs, draw debug
shapes, run console commands, toggle cheats, and plug your own windows into
the same bar.

- Godot **4.0 or newer**, typed GDScript, **no dependencies**.
- Works in the editor, in debug builds and in release exports (and can be
  removed from an export, see [Removing it from an export](docs/export.md)).
- Interface in English and French, switchable in-game.
- Mouse, keyboard, gamepad and touch (three-finger tap on mobile).

## Installation

1. Copy the `addons/debug_menu` folder into your project's `addons/` folder
   (create it if needed), so you get `res://addons/debug_menu/plugin.cfg`.
2. In Godot, open **Project > Project Settings > Plugins** and enable
   **Debug Menu**.
3. Run the game and press the key under <kbd>Esc</kbd>
   (<kbd>`</kbd> on QWERTY, <kbd>²</kbd> on AZERTY) to show the bar.

Enabling the plugin adds an autoload named `DebugMenu` and the input actions
for its shortcuts. An action that already exists in your project keeps its
key. Disabling the plugin removes the autoload.

## What's in the bar

| Menu | Tools |
|---|---|
| **Core** | Console, Performance graphs, Free camera, Screenshot, Time (pause, frame stepping, speed, input recordings), Display overlays (collisions, navigation, physics, gizmos, grid, dithering, input display), Screen guides (safe area, aspect ratios) |
| **Favorites** | Any window you star with ☆ |
| **Objects** | Inspector (live, editable variables with one-minute history), Physics, Signals log, Watch list, Variable finder |
| **Scene** | Node tree, Node events, Resources, Snapshots and random seed, Reload scene |
| **Cheats** | No clip, invincible, game speed, freeze, plus your game's own cheats |
| **Your menus** | Whatever your game adds with `DebugMenu.add_entry()` |

Every tool is described in the [user guide](docs/usage.md).

## Default shortcuts

All of them can be changed in-game in **⚙ Settings**. Keys are physical: they
stay at the same place whatever the keyboard layout.

| Key | Action |
|---|---|
| <kbd>`</kbd> / <kbd>²</kbd> | Show / hide the bar |
| <kbd>F7</kbd> | Pause / resume |
| <kbd>F10</kbd> | Next frame (the first press pauses) |
| <kbd>F8</kbd> | Picker: click an object to select it |
| <kbd>F9</kbd> | REC: record / stop |
| <kbd>F12</kbd> | Screenshot |
| <kbd>Ctrl</kbd>+<kbd>F</kbd> | Free camera |
| <kbd>Alt</kbd>+<kbd>C</kbd> | Cheat codes window |
| <kbd>Ctrl</kbd>+<kbd>G</kbd> | No clip |
| <kbd>Alt</kbd>+<kbd>V</kbd> | Invincible |
| <kbd>Alt</kbd>+<kbd>1</kbd> … <kbd>5</kbd> | Game speed x0.25 / x0.5 / x1 / x2 / x4 |
| <kbd>Ctrl</kbd>+<kbd>D</kbd> | Freeze / unfreeze |

## Quick start: hook your game in

```gdscript
# player.gd (a CharacterBody2D)
extends CharacterBody2D

var god_mode: bool = false

func _ready() -> void:
	# Free camera teleport, no clip and invincible act on this node.
	DebugMenu.set_player(self)

	# A checkbox and an action in a "My Game" menu.
	DebugMenu.add_toggle("My Game", "God mode",
			func() -> bool: return god_mode,
			func(on: bool) -> void: god_mode = on)
	DebugMenu.add_action("My Game", "Respawn", respawn)

	# A console command: type "give coins 100".
	DebugMenu.add_command("give", _give, "Give an item", "<item> <amount>")

func respawn() -> void:
	global_position = Vector2.ZERO

# The returned value is printed in the console.
func _give(args: PackedStringArray) -> String:
	if args.size() < 2:
		return "Usage: give <item> <amount>"
	return "Gave %s %s" % [args[1], args[0]]

func _physics_process(_delta: float) -> void:
	# A debug arrow for one frame, in its own category (Core > Display > Gizmos).
	DebugMenu.draw_arrow(global_position, global_position + velocity * 0.2,
			Color.CYAN, 0.0, "Player")
```

Your own windows, built with a few lines of code, are covered in the
[API reference](docs/api.md).

> If you plan to remove the debug menu from some exports, reach it through
> `get_node_or_null("/root/DebugMenu")` instead of the global `DebugMenu`
> name. See [Removing it from an export](docs/export.md).

## Documentation

- [User guide](docs/usage.md): every menu and tool.
- [API reference](docs/api.md): the `DebugMenu` functions and custom windows.
- [Theming](docs/theming.md): colors, fonts and sizes.
- [Removing it from an export](docs/export.md).

## License

[MIT](LICENSE). The bundled Montserrat font is under the SIL Open Font
License (`addons/debug_menu/fonts/OFL.txt`).

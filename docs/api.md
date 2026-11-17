# API reference

Everything goes through the `DebugMenu` autoload. Menu names use `/` for
submenus: `"My Game/Player"` creates a *Player* submenu in *My Game*.
Menu and entry names are translated when they exist in the addon's
dictionary, and shown as written otherwise.

> If some exports remove the debug menu (see [export](export.md)), use
> `var dm := get_node_or_null("/root/DebugMenu")` and check it for `null`
> instead of the global `DebugMenu` name.

## Menus

| Function | What it does |
|---|---|
| `add_entry(menu, entry, scene: PackedScene)` | Adds a window. The scene's root must be a `Window` (see [custom windows](#custom-windows)). |
| `add_toggle(menu, entry, getter: Callable, setter: Callable)` | Adds a checkbox. `getter() -> bool`, `setter(on: bool)`. Its state is kept between runs. |
| `add_action(menu, entry, action: Callable)` | Adds an entry that runs a function without opening a window. |
| `set_game_menu(menu)` | Marks a menu as one of your game's: kept on the left, never folded. The menu named after the project is one already. |
| `set_language("en" \| "fr")` | Changes the interface language. |

```gdscript
DebugMenu.add_entry("My Game", "Enemies", preload("res://debug/enemies_window.tscn"))
DebugMenu.add_toggle("My Game/Player", "Infinite ammo",
		func() -> bool: return infinite_ammo,
		func(on: bool) -> void: infinite_ammo = on)
DebugMenu.add_action("My Game", "Skip level", skip_level)
```

## Player and cheats

| Function | What it does |
|---|---|
| `set_player(node)` | The player used by the free camera (teleport) and the no clip / invincible cheats. A `Node2D` or `Node3D`; a physics body for no clip. Call it again when the player is recreated. |
| `add_cheat(category, name, action: Callable)` | A button in the *category* tab of the Cheat codes window. The same name replaces the previous one: declare it again each run if the function targets the current game. |
| `cheats.invincible`, `cheats.noclip` | Current cheat states (read-only for your game). |

Optional methods your player can implement:

| Method | Called when |
|---|---|
| `debug_teleport(position)` | The free camera teleports the player (instead of setting its position). |
| `debug_set_noclip(on: bool)` | No clip toggles (the player handles it itself). |
| `debug_set_invincible(on: bool)` | Invincible toggles. |

## Console

```gdscript
# add_command(name, callable, description = "", usage = "")
DebugMenu.add_command("give", _give, "Give an item", "<item> <amount>")

func _give(args: PackedStringArray) -> String:
	return "Gave %s %s" % [args[1], args[0]]   # the returned value is printed
```

`args` holds the words after the command name; quotes group words
(`say "hello there"` gives one argument). `take_screenshot()` takes a
screenshot like F12.

## Gizmos

Debug shapes in 2D world coordinates, each with a checkbox per category in
Core > Display > Gizmos.

```gdscript
draw_line(from, to, color = Color.YELLOW, duration = 0.0, category = "", width = 2.0)
draw_arrow(from, to, color = Color.YELLOW, duration = 0.0, category = "", width = 2.0)
draw_circle(center, radius, color = Color.YELLOW, duration = 0.0, category = "", filled = false, width = 2.0)
draw_rect(rect, color = Color.YELLOW, duration = 0.0, category = "", filled = false, width = 2.0)
draw_text(position, text, color = Color.WHITE, duration = 0.0, category = "")
```

`duration = 0` draws for one frame: call it again every frame (from
`_physics_process`, it lasts until the next physics step). Otherwise it is a
time in seconds.

## Grid

`set_grid(cell_size: Vector2, bounds: Rect2 = Rect2(), major_every: int = 5)`
sets the grid of Core > Display > Grid for the current scene (forgotten on
scene change). The corner of `bounds` is the grid origin.

## Objects, scene and time

| Function | What it does |
|---|---|
| `select(object)` | Selects an object (every object window follows it). |
| `inspect(object)` | Selects it and opens the Inspector. |
| `show_physics(node)` | Selects it and opens the Physics window. |
| `watch_variable(node, "variable")` | Adds a variable to Watch and opens the window. |
| `reload_scene()` | Reloads the scene (with the fixed seed if one is set). |
| `snapshots.take("name")`, `snapshots.restore(index)` | Scene snapshots. |
| `random_seed.set_fixed(true, 1234)` | Fixes the global random seed. |
| `disable()` | Removes the debug menu for this run. |

## Custom windows

A window is a scene whose root is a `Window` node, with a script that extends
the addon's base window. You describe its content in `_build()`, line by
line, in display order; the addon applies its theme.

`res://debug/speed_window.tscn`: a `Window` node with a `title`, a `size`
and this script:

```gdscript
extends "res://addons/debug_menu/ui/debug_window.gd"

func _build() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		add_note("No player in the scene.")
		return
	add_section("Movement")
	add_slider(player, &"speed", "Speed", 0.0, 800.0, 10.0, "px/s")
	add_hint("Horizontal speed on the ground.")
	add_check("Can jump", func() -> bool: return player.can_jump,
			func(on: bool) -> void: player.can_jump = on)
	add_button("Respawn", player.respawn)
	add_status(func() -> String: return "Speed: %d" % player.speed)
```

```gdscript
DebugMenu.add_entry("My Game", "Speed", preload("res://debug/speed_window.tscn"))
```

### Building blocks

| Group | Functions |
|---|---|
| Fixed top and bottom | `add_selection_bar()`, `add_status(getter)` |
| Text | `add_section(title)`, `add_label(text)`, `add_note(text)` (status, always shown), `add_hint(text)` (a `?` bubble explaining the previous line), `add_live_label(getter)`, `add_value(object, property, text)` |
| Fields | `add_slider`, `add_check`, `add_property_check`, `add_button`, `add_buttons`, `add_option`, `add_color`, `add_spin`, `add_text_field`, `add_tabs`, `add_node_list`, `add_custom(control)` |
| Automatic | `add_properties(object)`: one field per `@export` |

Signatures:

```gdscript
add_slider(target, property: StringName, text, min, max, step, unit = "")
add_property_check(target, property: StringName, text)
add_check(text, getter: Callable, setter: Callable)
add_button(text, on_pressed: Callable)
add_buttons(text, labels: Array, on_pressed: Callable)        # on_pressed(index)
add_option(text, options: Array, selected: int, on_selected: Callable)
add_color(text, value: Color, edit_alpha: bool, on_changed: Callable)
add_spin(text, value, min, max, step, on_changed: Callable)
add_text_field(text, value: String, placeholder: String, on_submitted: Callable)
add_tabs(titles: Array, current: int, on_changed: Callable)
add_node_list(getter: Callable, height = 110.0)
add_custom(control: Control, fill = false)
add_properties(target, only_group = "")
```

- `rebuild()` runs `_build()` again when the structure changes (new tab,
  different list).
- An object window starts with `add_selection_bar()` and follows
  `DebugMenu.selection` rather than keeping its own selection.
- If your window overrides `_ready()` or `_process()`, call `super()`.

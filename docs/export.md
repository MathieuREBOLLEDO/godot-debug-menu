# Removing it from an export

By default the debug menu is active everywhere, release exports included.
To turn it off in an export preset, add one of these tags in
**Project > Export > (your preset) > Features > Custom features**:

| Tag | Effect |
|---|---|
| `no_debug_menu` | The addon files are exported, but `DebugMenu` removes itself at launch. Safe for any game. |
| `strip_debug_menu` | The addon files are **not** exported; the autoload is replaced by a tiny scene that removes itself at launch. |

`strip_debug_menu` only works if none of your game's files reference the
addon (`preload`, `extends`, paths…). Otherwise the export keeps the files,
only turns the menu off at launch, and an error lists the files involved.

## Writing code that survives both

With either tag, `/root/DebugMenu` no longer exists by the time your game's
`_ready()` runs. Calls through the global `DebugMenu` name would then fail,
so reach it this way:

```gdscript
func _ready() -> void:
	var debug_menu: Node = get_node_or_null("/root/DebugMenu")
	if debug_menu != null:
		debug_menu.set_player(self)
		debug_menu.add_action("My Game", "Respawn", respawn)
```

You can also remove it for a single run from code with
`DebugMenu.disable()`.

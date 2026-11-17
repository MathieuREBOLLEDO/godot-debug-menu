extends "res://addons/debug_menu/ui/debug_window.gd"

## Core > Display > Grid > Grid settings : taille d'une case et lignes
## marquées, réglées à la main (prioritaire sur le jeu et les tuiles), ou
## retour au réglage automatique.


func _build() -> void:
	var grid: Node = _grid()
	if grid == null:
		add_note(T.t("DebugMenu not found: the grid needs the addon to be active."))
		return
	add_live_label(func() -> String:
		return T.t("Cell: %s px (%s)") % [grid.call("size_text", grid.get("cell_size")), T.t(grid.get("source"))])
	var cell_size: Vector2 = grid.get("cell_size")
	add_spin(T.t("Cell width (px)"), cell_size.x, 1.0, 1024.0, 1.0, func(value: float) -> void:
		_set_manual(Vector2(value, (grid.get("cell_size") as Vector2).y), grid.get("major_every")))
	add_spin(T.t("Cell height (px)"), cell_size.y, 1.0, 1024.0, 1.0, func(value: float) -> void:
		_set_manual(Vector2((grid.get("cell_size") as Vector2).x, value), grid.get("major_every")))
	add_spin(T.t("Marked line every"), grid.get("major_every"), 1.0, 100.0, 1.0, func(value: float) -> void:
		_set_manual(grid.get("cell_size"), int(value)))
	add_button(T.t("Automatic"), func() -> void:
		grid.call("clear_manual")
		rebuild())
	add_hint(T.t("Automatic: the size given by the game (DebugMenu.set_grid), otherwise the tiles of the first TileMapLayer, otherwise 16 px."))


func _set_manual(cell_size: Vector2, major_every: int) -> void:
	_grid().call("set_manual", cell_size, major_every)


func _grid() -> Node:
	var debug_menu: Node = get_debug_menu()
	return debug_menu.get("grid_overlay") if debug_menu != null else null

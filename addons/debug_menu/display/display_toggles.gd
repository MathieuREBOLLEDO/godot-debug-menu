extends RefCounted

## Cases des sous-menus Core > Display et Core > Screen :
##   Display : overlays (performance, entrées), contour de la sélection,
##             toutes les collisions, navigation,
##             Physics ▸ (physique du corps sélectionné),
##             Gizmos ▸ (une case par catégorie, ajoutée quand le jeu dessine
##             dans une nouvelle catégorie),
##             Grid ▸ (grille du monde, case sous la souris, cases occupées,
##             cadres des sprites, fenêtre Grid settings) ;
##   Screen  : safe area et formats d'écran.
## Libellés en anglais, traduits à l'affichage.

const Gizmos = preload("res://addons/debug_menu/display/gizmos.gd")
const ScreenGuides = preload("res://addons/debug_menu/display/screen_guides.gd")
const GRID_WINDOW: PackedScene = preload("res://addons/debug_menu/display/grid/grid_window.tscn")
const DITHERING_WINDOW: PackedScene = preload("res://addons/debug_menu/display/dithering_window.tscn")


static func register(debug_menu: Node, display_menu: String, screen_menu: String) -> void:
	var layer: Node = debug_menu.get("display_layer")
	_add_visibility(debug_menu, display_menu, "Performance overlay", debug_menu.get_node("PerfOverlay"))
	_add_visibility(debug_menu, display_menu, "Input display", debug_menu.get_node("InputOverlay"))
	_add_property(debug_menu, display_menu, "Selection outline", debug_menu.get_node("SelectionHighlight"), &"enabled")
	_add_property(debug_menu, display_menu, "Collision shapes", layer.get("collision_drawer"), &"enabled")
	_add_property(debug_menu, display_menu, "Navigation", layer.get("navigation_drawer"), &"enabled")
	var overlay: Node = layer.get("physics_overlay")
	var physics_entries: Array = [
		["Collision shapes", &"show_shapes"],
		["Center of mass", &"show_center"],
		["Velocity", &"show_velocity"],
		["Trajectory (3 s)", &"show_trail"],
		["Contacts and normals", &"show_contacts"],
	]
	for entry in physics_entries:
		_add_property(debug_menu, display_menu + "/Physics", entry[0], overlay, entry[1])
	# Gizmos : une case par catégorie, au premier dessin dans cette catégorie.
	var gizmos: Node = layer.get("gizmos")
	gizmos.connect("category_added", func(category: String) -> void:
		var entry: String = "Default" if category == Gizmos.DEFAULT_CATEGORY else category
		debug_menu.call("add_toggle", display_menu + "/Gizmos", entry,
				func() -> bool: return gizmos.call("is_category_shown", category),
				func(on: bool) -> void: gizmos.call("set_category_shown", category, on))
	)

	var grid: Node = debug_menu.get("grid_overlay")
	_add_property(debug_menu, display_menu + "/Grid", "World grid", grid, &"show_grid")
	_add_property(debug_menu, display_menu + "/Grid", "Cell under the mouse", grid, &"show_hover")
	_add_property(debug_menu, display_menu + "/Grid", "Occupied cells", grid, &"show_occupancy")
	_add_property(debug_menu, display_menu + "/Grid", "Sprite frames", grid.get("element_frames"), &"enabled")
	debug_menu.call("add_entry", display_menu + "/Grid", "Grid settings", GRID_WINDOW)

	_add_visibility(debug_menu, display_menu + "/Dithering", "Dithering", debug_menu.get_node("Dithering"))
	debug_menu.call("add_entry", display_menu + "/Dithering", "Dithering settings", DITHERING_WINDOW)

	var guides: Node = debug_menu.get_node("ScreenGuides")
	_add_property(debug_menu, screen_menu, "Safe area", guides, &"show_safe_area")
	for ratio in ScreenGuides.RATIOS:
		var ratio_name: String = ratio[0]
		debug_menu.call("add_toggle", screen_menu, ratio_name,
				func() -> bool: return guides.call("is_ratio_shown", ratio_name),
				func(on: bool) -> void: guides.call("set_ratio_shown", ratio_name, on))


static func _add_property(debug_menu: Node, menu: String, entry: String, target: Object, property: StringName) -> void:
	debug_menu.call("add_toggle", menu, entry, func() -> bool: return target.get(property), func(on: bool) -> void: target.set(property, on))


static func _add_visibility(debug_menu: Node, menu: String, entry: String, target: Object) -> void:
	_add_property(debug_menu, menu, entry, target, &"visible")

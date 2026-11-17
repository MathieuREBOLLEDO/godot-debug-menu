extends CanvasLayer

## Grille du monde (Core > Display > Grid), par-dessus le jeu :
## - grille : une ligne par case, plus marquée toutes les major_every cases,
##   numéros de colonne en bas et de ligne à gauche de l'écran, cadre du
##   niveau, et en bas à gauche la taille d'une case, de l'écran et du niveau ;
## - case sous la souris : surlignée, avec ses coordonnées (cases et pixels) ;
## - occupation : chaque case remplie à plus de la moitié par une tuile
##   (TileMapLayer, Godot 4.3+) ou une collision fixe (StaticBody2D), teintée
##   selon sa couche de collision ; les zones (Area2D) et les corps mobiles
##   ne comptent pas ;
## - cadres des sprites : element_frames (enfant).
## Taille d'une case, par priorité : réglage manuel (fenêtre Grid settings),
## DebugMenu.set_grid() du jeu (oublié au changement de scène), tuiles de la
## première TileMapLayer, sinon DEFAULT_CELL_SIZE.
## Dessin en coordonnées d'écran (texte lisible quel que soit le zoom), à
## partir de la transformée de la caméra. 2D seulement.

const T = preload("res://addons/debug_menu/i18n/t.gd")
const PhysicsQuery = preload("res://addons/debug_menu/objects/physics/physics_query.gd")
const PhysicsInfo = preload("res://addons/debug_menu/objects/physics/physics_info.gd")
const ElementFrames = preload("res://addons/debug_menu/display/grid/element_frames.gd")
const LAYER: int = 98 # sous le calque des dessins du monde (99)
const DEFAULT_CELL_SIZE: Vector2 = Vector2(16, 16)
const DEFAULT_MAJOR_EVERY: int = 5
const REFRESH_INTERVAL: float = 0.5
const MIN_CELL_PIXELS: float = 4.0 # en dessous, seules les lignes marquées sont tracées
const MAX_MARKED_CELLS: int = 4096 # par forme : au-delà, la forme est ignorée
const FONT_SIZE: int = 12
const LINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.25)
const MAJOR_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const BOUNDS_COLOR: Color = Color(1.0, 0.6, 0.2, 0.9)
const HOVER_COLOR: Color = Color(1.0, 0.9, 0.2)
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.8)
const TILE_COLOR: Color = Color(0.7, 0.7, 0.7, 0.35) # tuiles sans collision
## Une couleur par couche de collision (1, 2, 3...), en boucle.
const LAYER_COLORS: Array = [
	Color(0.3, 0.6, 1.0, 0.35),
	Color(1.0, 0.8, 0.2, 0.35),
	Color(1.0, 0.35, 0.6, 0.35),
	Color(0.4, 1.0, 0.5, 0.35),
	Color(0.7, 0.45, 1.0, 0.35),
	Color(0.3, 1.0, 1.0, 0.35),
]

var show_grid: bool = false:
	set(value):
		show_grid = value
		_update()
var show_hover: bool = false:
	set(value):
		show_hover = value
		_update()
var show_occupancy: bool = false:
	set(value):
		show_occupancy = value
		_occupied.clear()
		_refresh_time = REFRESH_INTERVAL
		_update()

## Taille d'une case en pixels du monde, et origine de la grille.
var cell_size: Vector2 = DEFAULT_CELL_SIZE
var origin: Vector2 = Vector2.ZERO
var major_every: int = DEFAULT_MAJOR_EVERY
## Cadre du niveau (Rect2() si inconnu).
var bounds: Rect2 = Rect2()
## D'où vient la taille d'une case (texte anglais, traduit à l'affichage).
var source: String = "default"
var element_frames: ElementFrames

var _manual: Dictionary = {} # {cell_size, major_every} : fenêtre Grid settings
var _game: Dictionary = {} # {cell_size, bounds, major_every, scene} : set_grid()
var _occupied: Dictionary = {} # Vector2i -> couche de collision (0 = tuile sans collision)
var _refresh_time: float = 0.0
var _canvas: Control


func _init() -> void:
	layer = LAYER
	visible = false
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_grid)
	add_child(_canvas)
	element_frames = ElementFrames.new()
	element_frames.grid = self
	element_frames.enabled_changed.connect(_update)
	add_child(element_frames)


## Grille donnée par le jeu (DebugMenu.set_grid), oubliée au changement de scène.
func set_game_grid(new_cell_size: Vector2, new_bounds: Rect2, new_major_every: int) -> void:
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	_game = {"cell_size": new_cell_size, "bounds": new_bounds, "major_every": new_major_every,
			"scene": scene.get_instance_id() if scene != null else 0}
	_resolve()


## Réglage manuel (fenêtre Grid settings), prioritaire sur tout le reste.
func set_manual(new_cell_size: Vector2, new_major_every: int) -> void:
	_manual = {"cell_size": new_cell_size, "major_every": new_major_every}
	_resolve()


func clear_manual() -> void:
	_manual.clear()
	_resolve()


func is_manual() -> bool:
	return not _manual.is_empty()


## Case qui contient le point [param world] (coordonnées du monde).
func cell_at(world: Vector2) -> Vector2i:
	return Vector2i(floori((world.x - origin.x) / cell_size.x), floori((world.y - origin.y) / cell_size.y))


## Rectangle d'une case dans le monde.
func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(cell) * cell_size, cell_size)


func _update() -> void:
	visible = show_grid or show_hover or show_occupancy or element_frames.enabled
	_resolve()
	_canvas.queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_time += delta
	if _refresh_time >= REFRESH_INTERVAL:
		_refresh_time = 0.0
		_resolve()
		if show_occupancy:
			_read_occupancy()
	_canvas.queue_redraw()


# --- Taille d'une case ---

func _resolve() -> void:
	if not _game.is_empty() and is_inside_tree():
		var scene: Node = get_tree().current_scene
		if scene == null or scene.get_instance_id() != _game["scene"]:
			_game.clear()
	bounds = Rect2()
	origin = Vector2.ZERO
	major_every = DEFAULT_MAJOR_EVERY
	if not _game.is_empty():
		cell_size = _game["cell_size"]
		bounds = _game["bounds"]
		origin = bounds.position
		major_every = _game["major_every"]
		source = "set by the game"
	else:
		var tile_layer: Node2D = _first_tile_layer()
		if tile_layer != null:
			var tile_set: TileSet = tile_layer.get("tile_set")
			cell_size = Vector2(tile_set.tile_size) * tile_layer.global_scale
			origin = tile_layer.global_position
			source = "TileMapLayer"
		else:
			cell_size = DEFAULT_CELL_SIZE
			source = "default"
	if not _manual.is_empty():
		cell_size = _manual["cell_size"]
		major_every = _manual["major_every"]
		source = "manual"
	cell_size = Vector2(maxf(cell_size.x, 1.0), maxf(cell_size.y, 1.0))
	major_every = maxi(major_every, 1)


# Appels dynamiques : la classe TileMapLayer n'existe qu'à partir de 4.3.
func _first_tile_layer() -> Node2D:
	if not ClassDB.class_exists("TileMapLayer") or not is_inside_tree():
		return null
	for tile_layer in _tile_layers():
		if tile_layer.get("tile_set") != null:
			return tile_layer
	return null


func _tile_layers() -> Array:
	var skip: Node = get_parent()
	return get_tree().root.find_children("*", "TileMapLayer", true, false).filter(
			func(node: Node) -> bool: return not skip.is_ancestor_of(node))


# --- Occupation ---

func _read_occupancy() -> void:
	_occupied.clear()
	if ClassDB.class_exists("TileMapLayer"):
		for tile_layer in _tile_layers():
			var tile_set: TileSet = tile_layer.get("tile_set")
			if tile_set == null or not tile_layer.is_visible_in_tree():
				continue
			var tile_bit: int = 0
			if tile_set.get_physics_layers_count() > 0:
				tile_bit = _first_bit(tile_set.get_physics_layer_collision_layer(0))
			var tile_size: Vector2 = Vector2(tile_set.tile_size)
			for cell in tile_layer.call("get_used_cells"):
				var center: Vector2 = tile_layer.call("map_to_local", cell)
				_mark(tile_layer.global_transform * Rect2(center - tile_size / 2.0, tile_size), tile_bit)
	for body in PhysicsQuery.all_bodies(get_tree()):
		if not body is StaticBody2D:
			continue
		var bit: int = _first_bit((body as CollisionObject2D).collision_layer)
		for shape_node in PhysicsInfo.shapes(body):
			if shape_node.get("disabled"):
				continue
			var rect: Rect2 = _shape_rect(shape_node)
			if rect.has_area():
				_mark((shape_node as Node2D).global_transform * rect, bit)


# Rectangle englobant d'une forme, dans ses coordonnées.
func _shape_rect(shape_node: Node) -> Rect2:
	if shape_node is CollisionShape2D and (shape_node as CollisionShape2D).shape != null:
		return (shape_node as CollisionShape2D).shape.get_rect()
	if shape_node is CollisionPolygon2D:
		var points: PackedVector2Array = (shape_node as CollisionPolygon2D).polygon
		if points.size() < 3:
			return Rect2()
		var rect: Rect2 = Rect2(points[0], Vector2.ZERO)
		for point in points:
			rect = rect.expand(point)
		return rect
	return Rect2()


# Marque les cases couvertes à plus de la moitié par [param rect].
func _mark(rect: Rect2, bit: int) -> void:
	var first: Vector2i = cell_at(rect.position)
	var last: Vector2i = cell_at(rect.end)
	if (last.x - first.x + 1) * (last.y - first.y + 1) > MAX_MARKED_CELLS:
		return
	var half: float = cell_size.x * cell_size.y * 0.5
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			var cell: Vector2i = Vector2i(x, y)
			if cell_rect(cell).intersection(rect).get_area() > half and not _occupied.has(cell):
				_occupied[cell] = bit


# Numéro de la première couche active (1 à 32), 0 si aucune.
static func _first_bit(bits: int) -> int:
	for index in 32:
		if bits & (1 << index):
			return index + 1
	return 0


static func _layer_color(bit: int) -> Color:
	return TILE_COLOR if bit == 0 else LAYER_COLORS[(bit - 1) % LAYER_COLORS.size()]


static func _layer_name(bit: int) -> String:
	if bit == 0:
		return T.t("Tiles")
	var custom: String = ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % bit, "")
	return T.t("Layer %d") % bit + ("" if custom == "" else " (%s)" % custom)


# --- Dessin ---

func _draw_grid() -> void:
	var to_screen: Transform2D = _canvas.get_viewport().get_canvas_transform()
	var screen: Rect2 = Rect2(Vector2.ZERO, _canvas.size)
	var world: Rect2 = to_screen.affine_inverse() * screen
	if show_occupancy:
		_draw_occupancy(to_screen, world)
	if show_grid:
		_draw_lines(to_screen, world)
		if bounds.has_area():
			_canvas.draw_rect(to_screen * bounds, BOUNDS_COLOR, false, 2.0)
		_draw_info(world)
	if show_hover:
		_draw_hover(to_screen)


func _draw_occupancy(to_screen: Transform2D, world: Rect2) -> void:
	var first: Vector2i = cell_at(world.position)
	var last: Vector2i = cell_at(world.end)
	for cell in _occupied:
		if cell.x >= first.x and cell.x <= last.x and cell.y >= first.y and cell.y <= last.y:
			_canvas.draw_rect(to_screen * cell_rect(cell), _layer_color(_occupied[cell]))


func _draw_lines(to_screen: Transform2D, world: Rect2) -> void:
	var font: Font = ThemeDB.fallback_font
	var first: Vector2i = cell_at(world.position)
	var last: Vector2i = cell_at(world.end) + Vector2i.ONE
	var cell_pixels: Vector2 = (to_screen.basis_xform(cell_size)).abs()
	var bottom: float = _canvas.size.y - 4.0
	for x in range(first.x, last.x + 1):
		var major: bool = x % major_every == 0
		if not major and cell_pixels.x < MIN_CELL_PIXELS:
			continue
		var world_x: float = origin.x + x * cell_size.x
		var top: Vector2 = to_screen * Vector2(world_x, world.position.y)
		_canvas.draw_line(top, to_screen * Vector2(world_x, world.end.y), MAJOR_COLOR if major else LINE_COLOR)
		if major:
			_draw_text(font, Vector2(top.x + 2.0, bottom), str(x), TEXT_COLOR)
	for y in range(first.y, last.y + 1):
		var major: bool = y % major_every == 0
		if not major and cell_pixels.y < MIN_CELL_PIXELS:
			continue
		var world_y: float = origin.y + y * cell_size.y
		var left: Vector2 = to_screen * Vector2(world.position.x, world_y)
		_canvas.draw_line(left, to_screen * Vector2(world.end.x, world_y), MAJOR_COLOR if major else LINE_COLOR)
		if major:
			_draw_text(font, Vector2(4.0, left.y - 2.0), str(y), TEXT_COLOR)


# En bas à gauche, au-dessus des numéros de colonne : case, écran, niveau,
# légende de l'occupation.
func _draw_info(world: Rect2) -> void:
	var lines: Array = [
		T.t("Cell: %s px (%s)") % [size_text(cell_size), T.t(source)],
		T.t("Screen: %s cells · %s px") % [size_text(world.size / cell_size), size_text(world.size)],
	]
	if bounds.has_area():
		lines.append(T.t("Level: %s cells · %s px") % [size_text(bounds.size / cell_size), size_text(bounds.size)])
	if show_occupancy:
		var bits: Dictionary = {}
		for cell in _occupied:
			bits[_occupied[cell]] = true
		var sorted_bits: Array = bits.keys()
		sorted_bits.sort()
		for bit in sorted_bits:
			lines.append(["■ " + _layer_name(bit), _layer_color(bit)])
	var font: Font = ThemeDB.fallback_font
	var y: float = _canvas.size.y - 4.0 - FONT_SIZE * (lines.size() + 1)
	for line in lines:
		y += FONT_SIZE
		if line is Array:
			_draw_text(font, Vector2(24.0, y), line[0], Color(line[1], 1.0))
		else:
			_draw_text(font, Vector2(24.0, y), line, TEXT_COLOR)


func _draw_hover(to_screen: Transform2D) -> void:
	var mouse: Vector2 = _canvas.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, _canvas.size).has_point(mouse):
		return
	var cell: Vector2i = cell_at(to_screen.affine_inverse() * mouse)
	var rect: Rect2 = cell_rect(cell)
	_canvas.draw_rect(to_screen * rect, HOVER_COLOR, false, 2.0)
	var text: String = "%d, %d · %s px" % [cell.x, cell.y, size_text(rect.position)]
	if show_occupancy and _occupied.has(cell):
		text += " · " + _layer_name(_occupied[cell])
	_draw_text(ThemeDB.fallback_font, mouse + Vector2(14.0, -6.0), text, HOVER_COLOR)


func _draw_text(font: Font, position: Vector2, text: String, color: Color) -> void:
	_canvas.draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, OUTLINE_COLOR)
	_canvas.draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


## « 30×17 » (entiers si possible, sinon une décimale).
static func size_text(value: Vector2) -> String:
	return "%s×%s" % [_number_text(value.x), _number_text(value.y)]


static func _number_text(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value

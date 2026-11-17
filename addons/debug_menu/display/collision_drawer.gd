extends Node2D

## Toutes les formes de collision 2D du jeu (menu Display), sur le calque qui
## suit la caméra. Couleur selon le type de corps ; formes désactivées en gris.
## Les collisions des TileMapLayer (Godot 4.3+) sont dessinées aussi, à partir
## des polygones de leurs tuiles (sans tenir compte des tuiles retournées).
## Seuls les objets proches de l'écran sont dessinés. La liste des objets
## est relue toutes les REFRESH_INTERVAL secondes.
## 3D : non géré (Godot a son propre Debug > Visible Collision Shapes).

const PhysicsQuery = preload("res://addons/debug_menu/objects/physics/physics_query.gd")
const PhysicsInfo = preload("res://addons/debug_menu/objects/physics/physics_info.gd")
const REFRESH_INTERVAL: float = 0.5
const TILE_REFRESH_INTERVAL: float = 2.0
const SCREEN_MARGIN: float = 256.0 # objets dessinés jusqu'à cette distance hors de l'écran
const STATIC_COLOR: Color = Color(0.45, 0.65, 1.0, 0.3)
const CHARACTER_COLOR: Color = Color(0.4, 1.0, 0.55, 0.35)
const RIGID_COLOR: Color = Color(1.0, 0.65, 0.3, 0.35)
const AREA_COLOR: Color = Color(0.75, 0.5, 1.0, 0.2)
const TILE_COLOR: Color = Color(0.45, 0.65, 1.0, 0.25)
const DISABLED_COLOR: Color = Color(0.6, 0.6, 0.6, 0.2)

var enabled: bool = false:
	set(value):
		enabled = value
		_bodies.clear()
		_tile_layers.clear()
		_refresh_time = REFRESH_INTERVAL
		_tile_refresh_time = TILE_REFRESH_INTERVAL

var _bodies: Array[Node] = []
var _tile_layers: Array = [] # [{layer: Node, polygons: Array[PackedVector2Array]}]
var _refresh_time: float = 0.0
var _tile_refresh_time: float = 0.0


func _process(delta: float) -> void:
	if not enabled:
		if not _bodies.is_empty():
			_bodies.clear()
			queue_redraw()
		return
	_refresh_time += delta
	_tile_refresh_time += delta
	if _refresh_time >= REFRESH_INTERVAL:
		_refresh_time = 0.0
		_bodies = PhysicsQuery.all_bodies(get_tree()).filter(func(node: Node) -> bool: return node is CollisionObject2D)
	if _tile_refresh_time >= TILE_REFRESH_INTERVAL:
		_tile_refresh_time = 0.0
		_read_tile_layers()
	queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	var visible_rect: Rect2 = _visible_world_rect().grow(SCREEN_MARGIN)
	for body in _bodies:
		if not is_instance_valid(body) or not body.is_inside_tree() or not visible_rect.has_point((body as Node2D).global_position):
			continue
		_draw_body(body)
	for entry in _tile_layers:
		var tile_layer: Node2D = entry["layer"]
		if not is_instance_valid(tile_layer) or not tile_layer.is_visible_in_tree():
			continue
		draw_set_transform_matrix(tile_layer.global_transform)
		for polygon in entry["polygons"]:
			draw_colored_polygon(polygon, TILE_COLOR)
		draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_body(body: Node) -> void:
	var color: Color = STATIC_COLOR
	if body is CharacterBody2D:
		color = CHARACTER_COLOR
	elif body is RigidBody2D:
		color = RIGID_COLOR
	elif body is Area2D:
		color = AREA_COLOR
	for shape_node in PhysicsInfo.shapes(body):
		var shape_color: Color = DISABLED_COLOR if shape_node.get("disabled") else color
		draw_set_transform_matrix((shape_node as Node2D).global_transform)
		if shape_node is CollisionShape2D and (shape_node as CollisionShape2D).shape != null:
			(shape_node as CollisionShape2D).shape.draw(get_canvas_item(), shape_color)
		elif shape_node is CollisionPolygon2D and (shape_node as CollisionPolygon2D).polygon.size() >= 3:
			draw_colored_polygon((shape_node as CollisionPolygon2D).polygon, shape_color)
	draw_set_transform_matrix(Transform2D.IDENTITY)


# Polygones de collision de chaque tuile, en coordonnées du TileMapLayer.
# Appels dynamiques : la classe TileMapLayer n'existe qu'à partir de 4.3.
func _read_tile_layers() -> void:
	_tile_layers.clear()
	if not ClassDB.class_exists("TileMapLayer"):
		return
	for tile_layer in get_tree().root.find_children("*", "TileMapLayer", true, false):
		var tile_set: TileSet = tile_layer.get("tile_set")
		if tile_set == null or tile_set.get_physics_layers_count() == 0:
			continue
		var polygons: Array[PackedVector2Array] = []
		for cell in tile_layer.call("get_used_cells"):
			var data: TileData = tile_layer.call("get_cell_tile_data", cell)
			if data == null:
				continue
			var offset: Vector2 = tile_layer.call("map_to_local", cell)
			for physics_layer in tile_set.get_physics_layers_count():
				for index in data.get_collision_polygons_count(physics_layer):
					var points: PackedVector2Array = data.get_collision_polygon_points(physics_layer, index)
					var moved: PackedVector2Array = PackedVector2Array()
					for point in points:
						moved.append(point + offset)
					if moved.size() >= 3:
						polygons.append(moved)
		_tile_layers.append({"layer": tile_layer, "polygons": polygons})


# Partie du monde visible à l'écran (la caméra 2D est dans la transformée).
func _visible_world_rect() -> Rect2:
	var viewport: Viewport = get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()

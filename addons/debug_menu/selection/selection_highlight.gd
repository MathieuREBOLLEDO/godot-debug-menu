extends CanvasLayer

## Contour de l'objet sélectionné dans le jeu (enfant de DebugMenu), avec son
## nom. Dessiné en coordonnées de l'écran : marche pour le monde (caméra) comme
## pour l'interface (CanvasLayer du jeu).
## - corps physique 2D : ses formes de collision ;
## - Sprite2D : le rectangle de sa texture ;
## - Control : son rectangle ;
## - autre nœud 2D : formes et sprites de ses enfants directs, sinon une croix ;
## - Node3D : une croix à sa position à l'écran.

const LAYER: int = 98 # sous les dessins de la Physique (99) et la barre (100)
const COLOR: Color = Color("ffd84f")
const LINE_WIDTH: float = 2.0
const FONT_SIZE: int = 11

var selection: Node # selection.gd
var enabled: bool = true

var _drawer: Node2D


func _init() -> void:
	layer = LAYER
	_drawer = Node2D.new()
	_drawer.draw.connect(_on_drawer_draw)
	add_child(_drawer)


func _process(_delta: float) -> void:
	_drawer.queue_redraw()


func _on_drawer_draw() -> void:
	if not enabled or selection == null:
		return
	var selected: Object = selection.call("get_selected")
	if not selected is Node or not (selected as Node).is_inside_tree():
		return
	var node: Node = selected
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	var label_position: Variant = null
	if node is Control:
		label_position = _outline_control(node)
	elif node is Node2D:
		label_position = _outline_2d(node)
	elif node is Node3D:
		label_position = _cross_3d(node)
	if label_position != null:
		_drawer.draw_string(ThemeDB.fallback_font, label_position + Vector2(0, -4), String(node.name), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR)


# Retourne le coin haut gauche du dessin (pour le nom), ou null.
func _outline_control(control: Control) -> Variant:
	var transform: Transform2D = control.get_global_transform_with_canvas()
	_outline_rect(transform, Rect2(Vector2.ZERO, control.size))
	return transform.origin


func _outline_2d(node: Node2D) -> Variant:
	var parts: Array[Node2D] = _outline_parts(node)
	if parts.is_empty():
		for child in node.get_children():
			if child is Node2D:
				parts.append_array(_outline_parts(child))
	if parts.is_empty():
		var origin: Vector2 = node.get_global_transform_with_canvas().origin
		_cross(origin)
		return origin
	var top_left: Vector2 = Vector2.INF
	for part in parts:
		var rect: Rect2 = _local_rect(part)
		var transform: Transform2D = part.get_global_transform_with_canvas()
		_outline_rect(transform, rect)
		var corner: Vector2 = transform * rect.position
		top_left = Vector2(minf(top_left.x, corner.x), minf(top_left.y, corner.y))
	return top_left


# Le nœud lui-même s'il se dessine (Sprite2D, forme) ; ses formes s'il est un
# corps physique.
func _outline_parts(node: Node2D) -> Array[Node2D]:
	var parts: Array[Node2D] = []
	if node is Sprite2D or _is_shape(node):
		parts.append(node)
	elif node is CollisionObject2D:
		for child in node.get_children():
			if _is_shape(child):
				parts.append(child)
	return parts


func _is_shape(node: Node) -> bool:
	return (node is CollisionShape2D and (node as CollisionShape2D).shape != null) or node is CollisionPolygon2D


func _local_rect(part: Node2D) -> Rect2:
	if part is Sprite2D:
		return (part as Sprite2D).get_rect()
	if part is CollisionShape2D:
		return (part as CollisionShape2D).shape.get_rect()
	var polygon: PackedVector2Array = (part as CollisionPolygon2D).polygon
	var rect: Rect2 = Rect2(polygon[0], Vector2.ZERO) if not polygon.is_empty() else Rect2()
	for point in polygon:
		rect = rect.expand(point)
	return rect


func _cross_3d(node: Node3D) -> Variant:
	var camera: Camera3D = node.get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(node.global_position):
		return null
	var point: Vector2 = camera.unproject_position(node.global_position)
	_cross(point)
	return point


func _outline_rect(transform: Transform2D, rect: Rect2) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		transform * rect.position,
		transform * Vector2(rect.end.x, rect.position.y),
		transform * rect.end,
		transform * Vector2(rect.position.x, rect.end.y),
		transform * rect.position,
	])
	_drawer.draw_polyline(points, COLOR, LINE_WIDTH, true)


func _cross(point: Vector2) -> void:
	_drawer.draw_line(point + Vector2(-8, 0), point + Vector2(8, 0), COLOR, LINE_WIDTH)
	_drawer.draw_line(point + Vector2(0, -8), point + Vector2(0, 8), COLOR, LINE_WIDTH)

extends Node2D

## Dessin dans le jeu (2D) de la physique du corps lié à la sélection :
## formes de collision, centre de masse, flèche de vitesse, trajectoire des
## TRAIL_DURATION dernières secondes, points de contact et normales (gardés
## CONTACT_HOLD secondes en s'effaçant, pour voir les contacts brefs), et
## surlignage (formes + nom) des objets des listes de la fenêtre Physique.
## Placé dans display/display_layer.gd, qui suit la caméra : on dessine
## directement en coordonnées du monde. Options cochées dans le menu
## Affichage.

const PhysicsInfo = preload("res://addons/debug_menu/objects/physics/physics_info.gd")
const PhysicsContacts = preload("res://addons/debug_menu/objects/physics/physics_contacts.gd")
const TRAIL_DURATION: float = 3.0
const VELOCITY_ARROW_TIME: float = 0.25 # la flèche montre le trajet sur ce temps
const SHAPE_COLOR: Color = Color(0.3, 0.75, 1.0, 0.35)
const DISABLED_SHAPE_COLOR: Color = Color(0.6, 0.6, 0.6, 0.25)
const CENTER_COLOR: Color = Color("ff6b6b")
const VELOCITY_COLOR: Color = Color("ffd84f")
const TRAIL_COLOR: Color = Color("6bd38a")
const HIGHLIGHT_FONT_SIZE: int = 10
const CONTACT_HOLD: float = 0.3
const CONTACT_COLOR: Color = Color("ff5c8a")
const NORMAL_COLOR: Color = Color("4fd1ff")
const NORMAL_LENGTH: float = 16.0

var body: Node = null # CollisionObject2D suivi
var show_shapes: bool = false
var show_center: bool = false
var show_velocity: bool = false
var show_trail: bool = false
var show_contacts: bool = false
## Objets à surligner : [{nodes: Array, color: Color}].
var highlights: Array[Dictionary] = []

var _trail: Array = [] # [temps, position]
var _contacts: Array[Dictionary] = [] # contacts récents, avec leur « time »
var _last_contact_count: int = 0


func set_body(value: Node) -> void:
	body = value if value is CollisionObject2D else null
	_trail.clear()
	_contacts.clear()


## Nombre de contacts de la dernière frame physique.
func current_contact_count() -> int:
	return _last_contact_count


func _physics_process(_delta: float) -> void:
	if not _has_body():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if show_trail:
		_trail.append([now, (body as Node2D).global_position])
	while not _trail.is_empty() and now - _trail[0][0] > TRAIL_DURATION:
		_trail.pop_front()
	if show_contacts:
		var current: Array[Dictionary] = PhysicsContacts.contacts(body)
		_last_contact_count = current.size()
		for contact in current:
			contact["time"] = now
			_contacts.append(contact)
	while not _contacts.is_empty() and now - float(_contacts[0]["time"]) > CONTACT_HOLD:
		_contacts.pop_front()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_draw_highlights()
	if not _has_body():
		return
	if show_shapes:
		_draw_shapes(body, SHAPE_COLOR)
	if show_trail and _trail.size() >= 2:
		var points: PackedVector2Array = PackedVector2Array()
		for entry in _trail:
			points.append(entry[1])
		draw_polyline(points, TRAIL_COLOR, 1.5, true)
	if show_center:
		var center: Vector2 = PhysicsInfo.center_of_mass(body)
		draw_circle(center, 3.0, CENTER_COLOR)
		draw_line(center + Vector2(-6, 0), center + Vector2(6, 0), CENTER_COLOR, 1.0)
		draw_line(center + Vector2(0, -6), center + Vector2(0, 6), CENTER_COLOR, 1.0)
	if show_velocity:
		var speed: Variant = PhysicsInfo.velocity(body)
		if speed is Vector2:
			_draw_arrow((body as Node2D).global_position, (body as Node2D).global_position + speed * VELOCITY_ARROW_TIME, VELOCITY_COLOR)
	if show_contacts:
		_draw_contacts()


# Les contacts les plus anciens sont plus transparents.
func _draw_contacts() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for contact in _contacts:
		var alpha: float = 1.0 - clampf((now - float(contact["time"])) / CONTACT_HOLD, 0.0, 1.0)
		var point: Vector2 = contact["position"]
		var normal: Vector2 = contact["normal"]
		draw_circle(point, 2.5, Color(CONTACT_COLOR, alpha))
		_draw_arrow(point, point + normal * NORMAL_LENGTH, Color(NORMAL_COLOR, alpha))


func _draw_highlights() -> void:
	var font: Font = ThemeDB.fallback_font
	for highlight in highlights:
		var color: Color = highlight["color"]
		for node in highlight["nodes"]:
			if not is_instance_valid(node) or not node is CollisionObject2D or not (node as Node).is_inside_tree():
				continue
			_draw_shapes(node, Color(color, 0.35))
			draw_string(font, (node as Node2D).global_position + Vector2(4, -4), String(node.name), HORIZONTAL_ALIGNMENT_LEFT, -1, HIGHLIGHT_FONT_SIZE, color)


func _draw_shapes(target: Node, shape_color: Color) -> void:
	for shape_node in PhysicsInfo.shapes(target):
		var color: Color = DISABLED_SHAPE_COLOR if shape_node.get("disabled") else shape_color
		draw_set_transform_matrix((shape_node as Node2D).global_transform)
		if shape_node is CollisionShape2D and (shape_node as CollisionShape2D).shape != null:
			(shape_node as CollisionShape2D).shape.draw(get_canvas_item(), color)
		elif shape_node is CollisionPolygon2D:
			var polygon: PackedVector2Array = (shape_node as CollisionPolygon2D).polygon
			if polygon.size() >= 3:
				draw_colored_polygon(polygon, color)
		draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	if from.distance_to(to) < 1.0:
		return
	draw_line(from, to, color, 2.0, true)
	var back: Vector2 = (from - to).normalized() * minf(8.0, from.distance_to(to) * 0.5)
	draw_line(to, to + back.rotated(0.5), color, 2.0, true)
	draw_line(to, to + back.rotated(-0.5), color, 2.0, true)


func _has_body() -> bool:
	return body != null and is_instance_valid(body) and body.is_inside_tree()

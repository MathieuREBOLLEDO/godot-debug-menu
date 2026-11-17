extends Node2D

## Navigation 2D (menu Display), sur le calque qui suit la caméra :
## - les polygones des NavigationRegion2D (zones où l'on peut se déplacer) ;
## - pour chaque NavigationAgent2D : son chemin actuel, sa cible, son rayon.
## La liste des nœuds est relue toutes les REFRESH_INTERVAL secondes.
## 3D : non géré.

const REFRESH_INTERVAL: float = 0.5
const DEBUG_MENU_PATH: NodePath = ^"/root/DebugMenu"
const REGION_COLOR: Color = Color(0.3, 0.85, 0.75, 0.18)
const REGION_EDGE_COLOR: Color = Color(0.3, 0.85, 0.75, 0.6)
const PATH_COLOR: Color = Color("ffd84f")
const TARGET_COLOR: Color = Color("ff6b6b")
const RADIUS_COLOR: Color = Color(1.0, 0.85, 0.3, 0.5)

var enabled: bool = false

var _regions: Array[Node] = []
var _agents: Array[Node] = []
var _refresh_time: float = REFRESH_INTERVAL


func _process(delta: float) -> void:
	if not enabled:
		if not _regions.is_empty() or not _agents.is_empty():
			_regions.clear()
			_agents.clear()
			queue_redraw()
		return
	_refresh_time += delta
	if _refresh_time >= REFRESH_INTERVAL:
		_refresh_time = 0.0
		_regions = _find("NavigationRegion2D")
		_agents = _find("NavigationAgent2D")
	queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	for region in _regions:
		if is_instance_valid(region) and region.is_inside_tree():
			_draw_region(region)
	for agent in _agents:
		if is_instance_valid(agent) and agent.is_inside_tree():
			_draw_agent(agent)


func _draw_region(region: NavigationRegion2D) -> void:
	var polygon: NavigationPolygon = region.navigation_polygon
	if polygon == null:
		return
	var vertices: PackedVector2Array = polygon.get_vertices()
	draw_set_transform_matrix(region.global_transform)
	for index in polygon.get_polygon_count():
		var points: PackedVector2Array = PackedVector2Array()
		for vertex_index in polygon.get_polygon(index):
			points.append(vertices[vertex_index])
		if points.size() >= 3:
			draw_colored_polygon(points, REGION_COLOR)
			points.append(points[0])
			draw_polyline(points, REGION_EDGE_COLOR, 1.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_agent(agent: NavigationAgent2D) -> void:
	var path: PackedVector2Array = agent.get_current_navigation_path()
	if path.size() >= 2:
		draw_polyline(path, PATH_COLOR, 2.0, true)
	var target: Vector2 = agent.target_position
	draw_line(target + Vector2(-6, -6), target + Vector2(6, 6), TARGET_COLOR, 2.0)
	draw_line(target + Vector2(-6, 6), target + Vector2(6, -6), TARGET_COLOR, 2.0)
	var owner_node: Node2D = agent.get_parent() as Node2D
	if owner_node != null:
		draw_arc(owner_node.global_position, agent.radius, 0.0, TAU, 32, RADIUS_COLOR, 1.0)


# Nœuds du jeu de ce type (pas ceux du debug menu).
func _find(type_name: String) -> Array[Node]:
	var skip: Node = get_tree().root.get_node_or_null(DEBUG_MENU_PATH)
	var found: Array[Node] = []
	for node in get_tree().root.find_children("*", type_name, true, false):
		if skip == null or not skip.is_ancestor_of(node):
			found.append(node)
	return found

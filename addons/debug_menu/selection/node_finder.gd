extends RefCounted

## Recherche de nœuds du jeu, par nom ou sous un point de l'écran (pipette).
## Les nœuds du debug menu et les fenêtres intégrées sont ignorés.
##
## Sous un point, par ordre de préférence :
## 1. un contrôle interactif (bouton, curseur, champ...) ;
## 2. un corps ou une zone physique 2D, puis 3D (il faut une collision) ;
## 3. un Sprite2D (rectangle de sa texture) ;
## 4. n'importe quel autre Control (souvent un conteneur de l'interface).

const DEBUG_MENU_PATH: NodePath = ^"/root/DebugMenu"
const MAX_RESULTS: int = 100
const RAY_LENGTH_3D: float = 1000.0
const MAX_POINT_HITS: int = 8


## Nœuds dont le nom contient [param text] (sans tenir compte de la casse).
static func search(tree: SceneTree, text: String) -> Array[Node]:
	var results: Array[Node] = []
	if text == "":
		return results
	_search_in(tree.root, text.to_lower(), results, tree.root.get_node_or_null(DEBUG_MENU_PATH))
	return results


static func _search_in(node: Node, needle: String, results: Array[Node], skip: Node) -> void:
	for child in node.get_children():
		if results.size() >= MAX_RESULTS:
			return
		if child == skip or child is Window:
			continue
		if String(child.name).to_lower().find(needle) != -1:
			results.append(child)
		_search_in(child, needle, results, skip)


## Nœud le plus pertinent sous [param screen_position] (coordonnées du
## viewport), ou null.
static func pick_at(viewport: Viewport, screen_position: Vector2) -> Node:
	var skip: Node = viewport.get_node_or_null(DEBUG_MENU_PATH)
	var control: Control = _control_at(viewport, screen_position, skip)
	if control != null and _is_interactive(control):
		return control
	var picked: Node = _physics_2d_at(viewport, screen_position)
	if picked == null:
		picked = _physics_3d_at(viewport, screen_position)
	if picked == null:
		picked = _sprite_at(viewport, screen_position, skip)
	if picked == null:
		picked = control
	return picked


# --- Interface ---

# Contrôle visible le plus haut (dessiné en dernier) sous le point.
static func _control_at(node: Node, point: Vector2, skip: Node) -> Control:
	var children: Array[Node] = node.get_children()
	for index in range(children.size() - 1, -1, -1):
		var child: Node = children[index]
		if child == skip or child is Window:
			continue
		var canvas_item: CanvasItem = child as CanvasItem
		if canvas_item != null and not canvas_item.visible:
			continue
		var layer: CanvasLayer = child as CanvasLayer
		if layer != null and not layer.visible:
			continue
		var found: Control = _control_at(child, point, skip)
		if found != null:
			return found
		var control: Control = child as Control
		if control != null and control.mouse_filter != Control.MOUSE_FILTER_IGNORE and control.get_global_rect().has_point(point):
			return control
	return null


static func _is_interactive(control: Control) -> bool:
	return control is BaseButton or control is Range or control is LineEdit or control is TextEdit or control is ItemList or control is Tree


# --- Monde ---

static func _physics_2d_at(viewport: Viewport, screen_position: Vector2) -> Node:
	var space: PhysicsDirectSpaceState2D = viewport.world_2d.direct_space_state
	if space == null:
		return null
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = viewport.get_canvas_transform().affine_inverse() * screen_position
	query.collide_with_areas = true
	# Plusieurs objets peuvent se toucher (un personnage posé sur le sol) : on
	# préfère tout ce qui n'est pas un décor statique.
	var hits: Array[Dictionary] = space.intersect_point(query, MAX_POINT_HITS)
	var fallback: Node = null
	for hit in hits:
		var collider: Node = hit["collider"] as Node
		if collider == null:
			continue
		if collider is StaticBody2D or collider.get_class().begins_with("TileMap"):
			if fallback == null:
				fallback = collider
		else:
			return collider
	return fallback


static func _physics_3d_at(viewport: Viewport, screen_position: Vector2) -> Node:
	var camera: Camera3D = viewport.get_camera_3d()
	if camera == null or viewport.world_3d == null:
		return null
	var space: PhysicsDirectSpaceState3D = viewport.world_3d.direct_space_state
	if space == null:
		return null
	var from: Vector3 = camera.project_ray_origin(screen_position)
	var to: Vector3 = from + camera.project_ray_normal(screen_position) * RAY_LENGTH_3D
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	var hit: Dictionary = space.intersect_ray(query)
	return hit.get("collider") as Node


# Dernier Sprite2D visible (le plus haut) dont la texture couvre le point.
static func _sprite_at(viewport: Viewport, screen_position: Vector2, skip: Node) -> Node:
	var found: Sprite2D = null
	for node in viewport.find_children("*", "Sprite2D", true, false):
		var sprite: Sprite2D = node as Sprite2D
		if not sprite.is_visible_in_tree() or (skip != null and skip.is_ancestor_of(sprite)):
			continue
		var local: Vector2 = sprite.get_global_transform_with_canvas().affine_inverse() * screen_position
		if sprite.get_rect().has_point(local):
			found = sprite
	return found

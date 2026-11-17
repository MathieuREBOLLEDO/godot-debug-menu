extends RefCounted

## Recherches dans les objets physiques du jeu (2D et 3D), pour les listes de
## la fenêtre Physique. Les nœuds du debug menu sont ignorés.

const DEBUG_MENU_PATH: NodePath = ^"/root/DebugMenu"


## Tous les objets physiques (corps et zones) présents dans l'arbre.
static func all_bodies(tree: SceneTree) -> Array[Node]:
	var skip: Node = tree.root.get_node_or_null(DEBUG_MENU_PATH)
	var result: Array[Node] = []
	for type_name in ["CollisionObject2D", "CollisionObject3D"]:
		for node in tree.root.find_children("*", type_name, true, false):
			if skip == null or not skip.is_ancestor_of(node):
				result.append(node)
	return result


## Objets dont la couche [param layer] (1 à 32) est active.
static func on_layer(tree: SceneTree, layer: int) -> Array[Node]:
	var bit: int = 1 << (layer - 1)
	var result: Array[Node] = []
	for node in all_bodies(tree):
		if int(node.get("collision_layer")) & bit:
			result.append(node)
	return result


## Objets que [param body] peut toucher : leurs couches croisent son masque.
static func in_mask_of(body: Node) -> Array[Node]:
	var mask: int = body.get("collision_mask")
	var result: Array[Node] = []
	for node in all_bodies(body.get_tree()):
		if node != body and int(node.get("collision_layer")) & mask:
			result.append(node)
	return result


## Objets en contact avec [param body] en ce moment :
## CharacterBody : collisions du dernier move_and_slide() ;
## RigidBody : get_colliding_bodies() (il faut contact_monitor) ;
## Area : corps et zones à l'intérieur ; StaticBody : rien (il ne le sait pas).
static func touching(body: Node) -> Array[Node]:
	var result: Array[Node] = []
	if body is CharacterBody2D or body is CharacterBody3D:
		for index in int(body.call("get_slide_collision_count")):
			var collider: Node = body.call("get_slide_collision", index).get_collider() as Node
			if collider != null and not result.has(collider):
				result.append(collider)
	elif body is RigidBody2D or body is RigidBody3D:
		result.assign(body.call("get_colliding_bodies"))
	elif body is Area2D or body is Area3D:
		for node in body.call("get_overlapping_bodies") + body.call("get_overlapping_areas"):
			result.append(node)
	return result


## « 1 Monde » ... « 32 » : un texte par couche, pour une liste de choix.
static func layer_names(in_3d: bool) -> Array[String]:
	var setting: String = "layer_names/3d_physics/layer_%d" if in_3d else "layer_names/2d_physics/layer_%d"
	var names: Array[String] = []
	for layer in range(1, 33):
		var layer_name: String = ProjectSettings.get_setting(setting % layer, "")
		names.append(str(layer) if layer_name == "" else "%d %s" % [layer, layer_name])
	return names

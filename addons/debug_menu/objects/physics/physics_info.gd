extends RefCounted

## Textes et calculs pour la fenêtre Physique, valables en 2D et en 3D :
## couches de collision avec leurs noms, formes, centre de masse, vitesse.

const SHAPE_DETAILS: Array[String] = ["size", "radius", "height", "a", "b", "normal", "distance", "length"]
const T = preload("res://addons/debug_menu/i18n/t.gd")


static func is_3d(body: Node) -> bool:
	return body is CollisionObject3D


## « 1 Monde, 3 Ennemis » : numéros des couches actives et leurs noms
## (Paramètres du projet > Layer Names).
static func layers_text(bits: int, in_3d: bool) -> String:
	var setting: String = "layer_names/3d_physics/layer_%d" if in_3d else "layer_names/2d_physics/layer_%d"
	var parts: PackedStringArray = PackedStringArray()
	for layer in range(1, 33):
		if bits & (1 << (layer - 1)):
			var layer_name: String = ProjectSettings.get_setting(setting % layer, "")
			parts.append(str(layer) if layer_name == "" else "%d %s" % [layer, layer_name])
	return T.t("none") if parts.is_empty() else ", ".join(parts)


## Formes de collision directement sous [param body].
static func shapes(body: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in body.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D or child is CollisionShape3D or child is CollisionPolygon3D:
			result.append(child)
	return result


## « Shape : RectangleShape2D size (16, 32) » ; « désactivée » si besoin.
static func shape_text(shape_node: Node) -> String:
	var text: String = "%s : " % shape_node.name
	var shape: Resource = shape_node.get("shape")
	if shape != null:
		text += shape.get_class()
		for detail in SHAPE_DETAILS:
			if detail in shape:
				text += " %s %s" % [detail, str(shape.get(detail))]
	elif shape_node.get("polygon") != null:
		text += T.t("polygon of %d points") % shape_node.get("polygon").size()
	else:
		text += T.t("no shape")
	if shape_node.get("disabled"):
		text += " " + T.t("(disabled)")
	return text


## Vitesse actuelle du corps (Vector2 ou Vector3), ou null s'il n'en a pas.
static func velocity(body: Node) -> Variant:
	for property in ["velocity", "linear_velocity", "constant_linear_velocity"]:
		if property in body:
			return body.get(property)
	return null


## Centre de masse en coordonnées du monde : celui calculé par le moteur pour
## un RigidBody, sinon l'origine du corps.
static func center_of_mass(body: Node) -> Variant:
	if body is RigidBody2D:
		var state_2d: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state((body as RigidBody2D).get_rid())
		if state_2d != null:
			return (body as RigidBody2D).global_position + state_2d.center_of_mass
		return (body as RigidBody2D).global_transform * (body as RigidBody2D).center_of_mass
	if body is RigidBody3D:
		var state_3d: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state((body as RigidBody3D).get_rid())
		if state_3d != null:
			return (body as RigidBody3D).global_position + state_3d.center_of_mass
		return (body as RigidBody3D).global_transform * (body as RigidBody3D).center_of_mass
	return body.get("global_position")


## Noms d'une liste de nœuds, ou « aucun ».
static func names_text(nodes: Array) -> String:
	var names: PackedStringArray = PackedStringArray()
	for node in nodes:
		names.append(String(node.name))
	return T.t("none") if names.is_empty() else ", ".join(names)

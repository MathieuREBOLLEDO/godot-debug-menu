extends RefCounted

## Points de contact d'un corps 2D, avec leur normale :
## {position: Vector2 (monde), normal: Vector2, collider: Object}.
## - CharacterBody2D : collisions du dernier move_and_slide() ; la normale est
##   celle de la surface touchée, tournée vers le personnage ;
## - RigidBody2D avec contact_monitor (et max_contacts_reported > 0) :
##   contacts calculés par le moteur ;
## - sinon (StaticBody, Area, RigidBody sans contact_monitor) : estimation par
##   requête de forme, en élargissant les formes de QUERY_MARGIN pour
##   attraper ce qui est posé dessus (les autres décors statiques sont
##   ignorés). La normale sort alors de ce corps vers l'objet touché ; elle
##   est approchée et peut manquer (longueur nulle).

const PhysicsInfo = preload("res://addons/debug_menu/objects/physics/physics_info.gd")
const T = preload("res://addons/debug_menu/i18n/t.gd")
const QUERY_MARGIN: float = 1.0
const MAX_RESULTS: int = 16


static func contacts(body: Node) -> Array[Dictionary]:
	if body is CharacterBody2D:
		return _character_contacts(body)
	if body is RigidBody2D and (body as RigidBody2D).contact_monitor:
		return _rigid_contacts(body)
	if body is CollisionObject2D:
		return _queried_contacts(body)
	return []


## Texte de la méthode utilisée, pour la fenêtre.
static func method_text(body: Node) -> String:
	if body is CharacterBody2D:
		return T.t("last move_and_slide()")
	if body is RigidBody2D and (body as RigidBody2D).contact_monitor:
		return T.t("engine contacts")
	return T.t("estimated with a shape query")


static func _character_contacts(body: CharacterBody2D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in body.get_slide_collision_count():
		var collision: KinematicCollision2D = body.get_slide_collision(index)
		result.append({"position": collision.get_position(), "normal": collision.get_normal(), "collider": collision.get_collider()})
	return result


static func _rigid_contacts(body: RigidBody2D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var state: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(body.get_rid())
	if state == null:
		return result
	for index in state.get_contact_count():
		result.append({
			"position": state.get_contact_local_position(index),
			"normal": state.get_contact_local_normal(index),
			"collider": state.get_contact_collider_object(index),
		})
	return result


# Pour chaque forme : objets qui la touchent (les autres décors statiques sont
# écartés : deux dalles de sol voisines ne sont pas intéressantes), puis
# points de contact par paires (point de la forme élargie, point de l'autre
# objet) : leur écart donne la normale, sortant de ce corps.
static func _queried_contacts(body: CollisionObject2D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var space: PhysicsDirectSpaceState2D = body.get_world_2d().direct_space_state
	if space == null:
		return result
	for shape_node in PhysicsInfo.shapes(body):
		var collision_shape: CollisionShape2D = shape_node as CollisionShape2D
		if collision_shape == null or collision_shape.shape == null or collision_shape.disabled:
			continue
		var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		query.shape = collision_shape.shape
		query.transform = collision_shape.global_transform
		query.margin = QUERY_MARGIN
		query.collision_mask = body.collision_mask | body.collision_layer
		query.collide_with_areas = true
		var excluded: Array[RID] = [body.get_rid()]
		for hit in space.intersect_shape(query, MAX_RESULTS):
			if body is StaticBody2D and hit["collider"] is StaticBody2D:
				excluded.append(hit["rid"])
		query.exclude = excluded
		var points: Array[Vector2] = space.collide_shape(query, MAX_RESULTS)
		for index in range(0, points.size() - 1, 2):
			var normal: Vector2 = (points[index] - points[index + 1]).normalized()
			result.append({"position": points[index + 1], "normal": normal, "collider": null})
	return result

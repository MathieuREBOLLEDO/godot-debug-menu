extends RefCounted

## Sections de la fenêtre Physique pour le corps sélectionné : collision,
## mouvement (selon le type de corps) et formes. Ajoutées dans le panneau
## donné (ui/debug_window.gd) avec ses add_...().

const DebugWindow = preload("res://addons/debug_menu/ui/debug_window.gd")
const PhysicsInfo = preload("res://addons/debug_menu/objects/physics/physics_info.gd")
const T = preload("res://addons/debug_menu/i18n/t.gd")


static func build(panel: DebugWindow, body: Node) -> void:
	_build_collision(panel, body)
	_build_motion(panel, body)
	_build_shapes(panel, body)


static func _build_collision(panel: DebugWindow, body: Node) -> void:
	var in_3d: bool = PhysicsInfo.is_3d(body)
	panel.add_section(T.t("Collision"))
	panel.add_live_label(func() -> String: return T.t("Layers (layer): ") + PhysicsInfo.layers_text(body.get("collision_layer"), in_3d))
	panel.add_live_label(func() -> String: return T.t("Detects (mask): ") + PhysicsInfo.layers_text(body.get("collision_mask"), in_3d))


static func _build_motion(panel: DebugWindow, body: Node) -> void:
	panel.add_section(T.t("Motion"))
	if body is CharacterBody2D or body is CharacterBody3D:
		panel.add_value(body, &"velocity", T.t("Velocity"))
		panel.add_live_label(func() -> String: return _character_contacts_text(body))
		panel.add_live_label(func() -> String: return T.t("Floor normal: %s") % str(body.call("get_floor_normal")))
		panel.add_value(body, &"motion_mode", T.t("Mode"))
	elif body is RigidBody2D or body is RigidBody3D:
		panel.add_value(body, &"linear_velocity", T.t("Velocity"))
		panel.add_value(body, &"angular_velocity", T.t("Angular velocity"))
		panel.add_value(body, &"mass", T.t("Mass"))
		panel.add_value(body, &"gravity_scale", T.t("Gravity (scale)"))
		panel.add_live_label(func() -> String: return T.t("Center of mass (world): %s") % str(PhysicsInfo.center_of_mass(body)))
		panel.add_value(body, &"sleeping", T.t("Sleeping"))
		panel.add_value(body, &"freeze", T.t("Frozen"))
		if not body.get("contact_monitor"):
			panel.add_note(T.t("Enable contact_monitor on this body to see its contacts."))
	elif body is Area2D or body is Area3D:
		panel.add_value(body, &"monitoring", T.t("Monitoring"))
	else:
		panel.add_value(body, &"constant_linear_velocity", T.t("Constant velocity"))


static func _build_shapes(panel: DebugWindow, body: Node) -> void:
	var shape_nodes: Array[Node] = PhysicsInfo.shapes(body)
	panel.add_section(T.t("Shapes (%d)") % shape_nodes.size())
	for shape_node in shape_nodes:
		panel.add_live_label(func() -> String: return PhysicsInfo.shape_text(shape_node) if is_instance_valid(shape_node) else T.t("(shape freed)"))


static func _character_contacts_text(body: Node) -> String:
	return T.t("Floor %s · Wall %s · Ceiling %s") % [_yes_no(body.call("is_on_floor")), _yes_no(body.call("is_on_wall")), _yes_no(body.call("is_on_ceiling"))]


static func _yes_no(value: bool) -> String:
	return T.t("yes") if value else T.t("no")

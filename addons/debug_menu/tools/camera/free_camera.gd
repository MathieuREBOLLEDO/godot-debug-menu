extends Node

## Caméra libre (service FreeCamera, Core > Free camera, Ctrl+F) : remplace
## la caméra du jeu le temps de regarder ailleurs, puis la rend telle quelle.
## - 3D (une Camera3D est active) : comme dans un FPS. Touches physiques
##   W A S D pour avancer et se décaler (Z Q S D en AZERTY : même position),
##   E / Q pour monter / descendre, Maj pour aller plus vite ; clic droit
##   maintenu pour regarder (souris capturée) ; molette : vitesse, ou taille
##   de la vue pour une caméra orthographique (vue isométrique). FOV réglable.
## - 2D : W A S D déplacent la vue, molette zoome vers la souris, clic droit
##   ou du milieu glissé : déplacer la vue.
## Le jeu est mis en pause pendant le vol (pause_game, par défaut) : les
## touches ne font pas bouger le personnage. La caméra marche jeu en pause, en
## temps réel (pas de time_scale).
## Clic gauche pendant le vol : téléporte le joueur (player, déclaré par le
## jeu avec DebugMenu.set_player()) à l'endroit cliqué ; en 3D, là où le clic
## touche le décor (sinon à TELEPORT_DISTANCE devant la caméra). Sa vitesse
## (velocity) est remise à zéro. Si le joueur a une méthode
## debug_teleport(position), elle est appelée à la place : le jeu place
## lui-même son personnage (case d'une grille, groupe qui suit...).

signal changed
## Émis après une téléportation du joueur (position d'arrivée, Vector2 ou Vector3).
signal player_teleported(at: Variant)

const LAYER: int = 101 # bandeau au-dessus de la barre (100)
const T = preload("res://addons/debug_menu/i18n/t.gd")
const Shortcuts = preload("res://addons/debug_menu/settings/shortcuts.gd")
const FAST_FACTOR: float = 4.0
const WHEEL_STEP: float = 1.15
const PITCH_LIMIT: float = 1.55 # rad, juste avant la verticale
const TELEPORT_RAY_LENGTH: float = 1000.0 # m, recherche du décor sous le clic (3D)
const TELEPORT_DISTANCE: float = 10.0 # m devant la caméra si le clic ne touche rien (3D)

var active: bool = false
## Joueur à téléporter (Node2D ou Node3D), ou null : DebugMenu.set_player().
var player: Node = null
## Vrai en 3D, faux en 2D (fixé au départ du vol).
var is_3d: bool = false
## Vitesse en 3D (m/s) et en 2D (pixels écran par seconde).
var speed_3d: float = 8.0
var speed_2d: float = 800.0
## Degrés par pixel de souris.
var sensitivity: float = 0.2
var pause_game: bool = true
## Champ de vision de la caméra libre 3D (°).
var fov: float = 70.0:
	set(value):
		fov = clampf(value, 1.0, 179.0)
		if _camera_3d != null:
			_camera_3d.fov = fov

var _camera_3d: Camera3D = null
var _camera_2d: Camera2D = null
var _previous_3d: Camera3D = null
var _previous_2d: Camera2D = null
var _previous_canvas: Transform2D
var _previous_mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _paused_by_us: bool = false
var _looking: bool = false
var _panning: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
var _last_ticks: int = 0
var _banner: CanvasLayer
var _banner_label: Label


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_banner = CanvasLayer.new()
	_banner.layer = LAYER
	_banner.visible = false
	add_child(_banner)
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.position.y -= 12.0
	_banner.add_child(panel)
	_banner_label = Label.new()
	panel.add_child(_banner_label)


## Thème du debug menu pour le bandeau.
func set_theme(theme: Theme) -> void:
	(_banner.get_child(0) as Control).theme = theme


func toggle() -> void:
	if active:
		stop()
	else:
		start()


func start() -> void:
	if active:
		return
	var viewport: Viewport = get_viewport()
	_previous_3d = viewport.get_camera_3d()
	_previous_2d = viewport.get_camera_2d()
	_previous_canvas = viewport.canvas_transform
	is_3d = _previous_3d != null
	if is_3d:
		_start_3d()
	else:
		_start_2d(viewport)
	var debug_menu: Node = get_parent()
	var playback: Object = debug_menu.get("playback") if debug_menu != null else null
	_paused_by_us = false
	if pause_game and playback != null and not playback.call("is_paused"):
		playback.call("toggle_pause")
		_paused_by_us = true
	_previous_mouse_mode = Input.mouse_mode
	_last_ticks = Time.get_ticks_usec()
	active = true
	_banner.visible = true
	_update_banner()
	changed.emit()


func stop() -> void:
	if not active:
		return
	active = false
	_looking = false
	_panning = false
	Input.mouse_mode = _previous_mouse_mode
	if _camera_3d != null:
		_camera_3d.queue_free()
		_camera_3d = null
		if is_instance_valid(_previous_3d):
			_previous_3d.current = true
	if _camera_2d != null:
		_camera_2d.queue_free()
		_camera_2d = null
		if is_instance_valid(_previous_2d):
			_previous_2d.make_current()
		else:
			get_viewport().canvas_transform = _previous_canvas
	var debug_menu: Node = get_parent()
	var playback: Object = debug_menu.get("playback") if debug_menu != null else null
	if _paused_by_us and playback != null and playback.call("is_paused"):
		playback.call("toggle_pause")
	_paused_by_us = false
	_banner.visible = false
	changed.emit()


## Position de la caméra libre (texte), pour la fenêtre.
func describe() -> String:
	if not active:
		return T.t("Off")
	if is_3d:
		var at: Vector3 = _camera_3d.global_position
		return T.t("3D · %.1f, %.1f, %.1f · FOV %d°") % [at.x, at.y, at.z, roundi(fov)]
	return T.t("2D · %.0f, %.0f · zoom x%.2f") % [_camera_2d.global_position.x, _camera_2d.global_position.y, _camera_2d.zoom.x]


## Touches de déplacement sur le clavier de l'utilisateur (« ZQSD » en AZERTY).
func move_keys_text() -> String:
	var keys: String = ""
	for key in [KEY_W, KEY_A, KEY_S, KEY_D]:
		keys += Shortcuts.physical_label(key)
	return keys


func _start_3d() -> void:
	_camera_3d = Camera3D.new()
	_camera_3d.name = "DebugFreeCamera3D"
	_camera_3d.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_camera_3d)
	_camera_3d.global_transform = _previous_3d.global_transform
	_camera_3d.projection = _previous_3d.projection
	_camera_3d.size = _previous_3d.size
	_camera_3d.near = _previous_3d.near
	_camera_3d.far = _previous_3d.far
	_camera_3d.cull_mask = _previous_3d.cull_mask
	fov = _previous_3d.fov
	var angles: Vector3 = _camera_3d.global_transform.basis.get_euler()
	_pitch = angles.x
	_yaw = angles.y
	_camera_3d.current = true


func _start_2d(viewport: Viewport) -> void:
	_camera_2d = Camera2D.new()
	_camera_2d.name = "DebugFreeCamera2D"
	_camera_2d.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_camera_2d)
	# Même vue que le jeu : centre de l'écran et zoom de la transformation du canvas.
	_camera_2d.zoom = _previous_canvas.get_scale()
	_camera_2d.global_position = _previous_canvas.affine_inverse() * (viewport.get_visible_rect().size * 0.5)
	_camera_2d.make_current()


func _process(_delta: float) -> void:
	if not active:
		return
	# Temps réel : la caméra bouge jeu en pause ou ralenti.
	var now: int = Time.get_ticks_usec()
	var delta: float = minf((now - _last_ticks) / 1000000.0, 0.1)
	_last_ticks = now
	var fast: float = FAST_FACTOR if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
	var side: float = _key(KEY_D) - _key(KEY_A)
	var forward: float = _key(KEY_S) - _key(KEY_W)
	if Input.is_key_pressed(KEY_CTRL):
		side = 0.0 # Ctrl+touche : raccourci, pas un déplacement
		forward = 0.0
	if is_3d and _camera_3d != null:
		var move: Vector3 = Vector3(side, _key(KEY_E) - _key(KEY_Q), forward)
		if move != Vector3.ZERO:
			_camera_3d.global_position += _camera_3d.global_transform.basis * move.normalized() * speed_3d * fast * delta
	elif _camera_2d != null:
		var move_2d: Vector2 = Vector2(side, forward)
		if move_2d != Vector2.ZERO:
			_camera_2d.global_position += move_2d.normalized() * speed_2d * fast * delta / _camera_2d.zoom.x
	_update_banner()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		_on_mouse_button(button)
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null:
		return
	if _looking and _camera_3d != null:
		_yaw -= deg_to_rad(motion.relative.x * sensitivity)
		_pitch = clampf(_pitch - deg_to_rad(motion.relative.y * sensitivity), -PITCH_LIMIT, PITCH_LIMIT)
		_camera_3d.global_transform.basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
		get_viewport().set_input_as_handled()
	elif _panning and _camera_2d != null:
		_camera_2d.global_position -= motion.relative / _camera_2d.zoom.x
		get_viewport().set_input_as_handled()


func _on_mouse_button(button: InputEventMouseButton) -> void:
	match button.button_index:
		MOUSE_BUTTON_LEFT:
			if not button.pressed or not has_player():
				return
			_teleport_player(button.position)
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if is_3d and button.button_index == MOUSE_BUTTON_RIGHT:
				_looking = button.pressed
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else _previous_mouse_mode
			elif not is_3d:
				_panning = button.pressed
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if not button.pressed:
				return
			var factor: float = WHEEL_STEP if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / WHEEL_STEP
			if is_3d and _camera_3d.projection == Camera3D.PROJECTION_ORTHOGONAL:
				_camera_3d.size = clampf(_camera_3d.size / factor, 0.1, 10000.0)
			elif is_3d:
				speed_3d = clampf(speed_3d * factor, 0.1, 500.0)
			else:
				_zoom_at(button.position, factor)
		_:
			return
	get_viewport().set_input_as_handled()
	changed.emit()


## Vrai si un joueur téléportable est déclaré (et toujours là).
func has_player() -> bool:
	return is_instance_valid(player) and (player is Node2D or player is Node3D or player.has_method("debug_teleport"))


# Pose le joueur sous le point de l'écran [param at].
func _teleport_player(at: Vector2) -> void:
	var target: Variant
	if is_3d and _camera_3d != null:
		var from: Vector3 = _camera_3d.project_ray_origin(at)
		var direction: Vector3 = _camera_3d.project_ray_normal(at)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + direction * TELEPORT_RAY_LENGTH)
		if player is CollisionObject3D:
			query.exclude = [(player as CollisionObject3D).get_rid()]
		var hit: Dictionary = _camera_3d.get_world_3d().direct_space_state.intersect_ray(query)
		target = hit["position"] if not hit.is_empty() else from + direction * TELEPORT_DISTANCE
	elif _camera_2d != null:
		# Point du clic (pas la position actuelle de la souris), dans le monde.
		target = get_viewport().canvas_transform.affine_inverse() * at
	else:
		return
	if player.has_method("debug_teleport"):
		player.call("debug_teleport", target)
	elif player is Node3D:
		if not target is Vector3:
			return
		(player as Node3D).global_position = target
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
	else:
		if not target is Vector2:
			return
		(player as Node2D).global_position = target
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO
	player_teleported.emit(target)
	changed.emit()


# Zoom 2D vers le point de l'écran [param at] : ce point reste sous la souris.
func _zoom_at(at: Vector2, factor: float) -> void:
	var half: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var world: Vector2 = _camera_2d.global_position + (at - half) / _camera_2d.zoom.x
	var zoom: float = clampf(_camera_2d.zoom.x * factor, 0.02, 50.0)
	_camera_2d.zoom = Vector2(zoom, zoom)
	_camera_2d.global_position = world - (at - half) / zoom


func _key(physical: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(physical) else 0.0


func _update_banner() -> void:
	var help: String
	if is_3d:
		help = T.t("%s, %s / %s: move · Shift: fast · right click: look · wheel: speed") % [move_keys_text(), Shortcuts.physical_label(KEY_E), Shortcuts.physical_label(KEY_Q)]
	else:
		help = T.t("%s: move · wheel: zoom · right / middle drag: pan") % move_keys_text()
	if has_player():
		help += " · " + T.t("left click: teleport the player")
	_banner_label.text = T.t("FREE CAMERA") + "  ·  " + help + "  ·  " + T.t("%s: leave") % Shortcuts.key_text(Shortcuts.FREE_CAMERA)

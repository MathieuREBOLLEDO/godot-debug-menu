extends Node

## Cheats (service Cheats, DebugMenu.cheats ; fenêtre Cheats > Cheat codes,
## Alt+C) : no clip, invincibilité, vitesse et gel du jeu, et les cheats
## déclarés par le jeu (DebugMenu.add_cheat).
## Le joueur est celui de DebugMenu.set_player().
## - No clip : si le joueur a une méthode debug_set_noclip(on: bool), le jeu
##   s'en charge. Sinon le cheat coupe ses collisions (couches et masque) et
##   son _physics_process, et le fait voler : flèches, W A S D (touches
##   physiques), stick ou croix ; en 3D, E / Q pour monter / descendre et le
##   déplacement suit la caméra ; Maj plus vite. Tout est rendu à l'arrêt.
##   Seulement sur un corps physique (PhysicsBody2D / 3D) : voir can_noclip().
## - Invincible : l'addon ne connaît pas les points de vie du jeu. Il appelle
##   debug_set_invincible(on: bool) sur le joueur si elle existe ; le jeu peut
##   aussi lire DebugMenu.cheats.invincible.
## Suit le temps du jeu (pause, vitesse, image par image).

signal changed

const Playback = preload("res://addons/debug_menu/time/playback.gd")
## Vitesses de Alt+1 à Alt+5 (settings/shortcuts.gd, SPEED_ACTIONS).
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0]
const FAST_FACTOR: float = 3.0

## Joueur (Node2D ou Node3D), ou null : DebugMenu.set_player().
var player: Node = null:
	set(value):
		if value == player:
			return
		var was_noclip: bool = noclip
		if was_noclip:
			noclip = false
		player = value
		if was_noclip:
			noclip = true
		if invincible and is_instance_valid(player) and player.has_method("debug_set_invincible"):
			player.call("debug_set_invincible", true)
		changed.emit()
var playback: Playback
var noclip: bool = false:
	set(value):
		if value == noclip or (value and not can_noclip()):
			return
		noclip = value
		_apply_noclip(value)
		changed.emit()
var invincible: bool = false:
	set(value):
		if value == invincible:
			return
		invincible = value
		if has_player() and player.has_method("debug_set_invincible"):
			player.call("debug_set_invincible", value)
		changed.emit()
## Vitesse du vol en no clip : pixels du monde par seconde (2D), m/s (3D).
var noclip_speed_2d: float = 600.0
var noclip_speed_3d: float = 10.0

# Cheats du jeu, dans l'ordre : {category, name, action}.
var _cheats: Array[Dictionary] = []
# Collisions et _physics_process du joueur avant le no clip.
var _saved: Dictionary = {}


func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Vrai si un joueur est déclaré (et toujours là).
func has_player() -> bool:
	return is_instance_valid(player) and (player is Node2D or player is Node3D or player.has_method("debug_set_noclip"))


## Vrai si le no clip marche sur ce joueur : un corps physique (2D ou 3D),
## ou un joueur qui a debug_set_noclip(on). Pas un nœud quelconque : ce
## serait déplacer toute la scène (un groupe, un niveau).
func can_noclip() -> bool:
	return is_instance_valid(player) and (player.has_method("debug_set_noclip") or player is PhysicsBody2D or player is PhysicsBody3D)


## Vrai si le joueur gère lui-même l'invincibilité (debug_set_invincible).
func supports_invincible() -> bool:
	return is_instance_valid(player) and player.has_method("debug_set_invincible")


func toggle_noclip() -> void:
	noclip = not noclip


func toggle_invincible() -> void:
	invincible = not invincible


## Vitesse du jeu [param speed] ; un jeu gelé repart.
func set_speed(speed: float) -> void:
	playback.speed = speed
	if playback.is_paused():
		playback.set_paused(false)


## Gel du jeu (la pause du debug menu, comme F7) ou dégel.
func toggle_freeze() -> void:
	playback.toggle_pause()


# --- Cheats du jeu ---

## Ajoute le cheat [param cheat_name] à l'onglet [param category] de la
## fenêtre ; [param action] () est appelé au clic. Un même nom remplace
## l'ancien.
func add(category: String, cheat_name: String, action: Callable) -> void:
	for cheat in _cheats:
		if cheat["category"] == category and cheat["name"] == cheat_name:
			cheat["action"] = action
			return
	_cheats.append({"category": category, "name": cheat_name, "action": action})
	changed.emit()


## Onglets du jeu, dans l'ordre d'ajout.
func categories() -> Array[String]:
	var result: Array[String] = []
	for cheat in _cheats:
		if not result.has(cheat["category"]):
			result.append(cheat["category"])
	return result


func cheats_in(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cheat in _cheats:
		if cheat["category"] == category:
			result.append(cheat)
	return result


func run(cheat: Dictionary) -> void:
	var action: Callable = cheat["action"]
	if action.is_valid():
		action.call()


# --- No clip ---

func _apply_noclip(on: bool) -> void:
	if not is_instance_valid(player):
		_saved.clear()
		return
	if player.has_method("debug_set_noclip"):
		player.call("debug_set_noclip", on)
		return
	if on:
		_saved = {"physics": player.is_physics_processing()}
		if player is CollisionObject2D or player is CollisionObject3D:
			_saved["layer"] = player.get("collision_layer")
			_saved["mask"] = player.get("collision_mask")
			player.set("collision_layer", 0)
			player.set("collision_mask", 0)
		player.set_physics_process(false)
		_reset_velocity()
	else:
		if _saved.has("layer"):
			player.set("collision_layer", _saved["layer"])
			player.set("collision_mask", _saved["mask"])
		player.set_physics_process(_saved.get("physics", true))
		_reset_velocity()
		_saved.clear()


func _reset_velocity() -> void:
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	elif player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO


func _process(delta: float) -> void:
	if not noclip:
		return
	if not is_instance_valid(player):
		noclip = false # joueur libéré : rien à rendre
		return
	if player.has_method("debug_set_noclip"):
		return
	var fast: float = FAST_FACTOR if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
	var move: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_ALT):
		move += Vector2(_key(KEY_D) - _key(KEY_A), _key(KEY_S) - _key(KEY_W))
	if move.length() > 1.0:
		move = move.normalized()
	if player is Node3D:
		var body: Node3D = player as Node3D
		var camera: Camera3D = get_viewport().get_camera_3d()
		var basis: Basis = camera.global_transform.basis if camera != null else body.global_transform.basis
		var step: Vector3 = basis * Vector3(move.x, 0.0, move.y) + Vector3.UP * (_key(KEY_E) - _key(KEY_Q))
		if step.length() > 1.0:
			step = step.normalized()
		body.global_position += step * noclip_speed_3d * fast * delta
	elif player is Node2D:
		(player as Node2D).global_position += move * noclip_speed_2d * fast * delta


func _key(physical: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(physical) else 0.0

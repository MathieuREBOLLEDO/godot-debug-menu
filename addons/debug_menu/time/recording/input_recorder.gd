extends Node

## Enregistre puis rejoue les actions du joueur (enfant de DebugMenu, placé
## après TimeController pour voir l'image par image).
## Prise : la scène est rechargée (point de départ connu), puis l'état de
## chaque action de l'InputMap est relevé à chaque image physique ; seuls les
## changements sont gardés. La pause du jeu (ou sa fermeture) termine la prise.
## Replay : même scène rechargée, même graine aléatoire, même time_scale, et
## à chaque image l'état enregistré est imposé par de vrais événements
## d'action : le jeu recalcule tout (IA, physique) comme pendant la prise.
## Les événements d'une image sont envoyés juste AVANT elle, pendant le
## _process précédent, comme un vrai clavier : Godot date un appui avec
## l'image physique à venir (is_action_just_pressed), et un appui envoyé
## pendant l'image elle-même ne compterait qu'à la suivante.
## Les touches pressées pendant le replay sont annulées.
## Le replay suit la pause : il n'avance que quand le jeu tourne.
## Pour mesurer une dérive, la position des corps (CharacterBody, RigidBody)
## est notée toutes les TRACK_INTERVAL images et comparée au replay.
## Limites : la souris n'est pas enregistrée ; l'état des autoloads n'est pas
## remis à zéro ; un RandomNumberGenerator propre au jeu n'est pas re-semé.

signal state_changed
## Une prise vient d'être enregistrée dans [param path].
signal recording_saved(path: String)

enum State { IDLE, STARTING, RECORDING, REPLAYING }

const RecordingFile = preload("res://addons/debug_menu/time/recording/recording_file.gd")
const T = preload("res://addons/debug_menu/i18n/t.gd")
const IGNORED_PREFIX: String = "debug_menu_"
const TRACK_INTERVAL: int = 5
const EPSILON: float = 0.01

var state: int = State.IDLE
var frame: int = 0 # image en cours depuis le début de la prise / du replay
var data: Dictionary = {}
var last_saved_path: String = ""
var max_drift: float = 0.0 # plus grand écart de position mesuré pendant le replay
var max_drift_path: String = ""

var _target_state: int = State.IDLE
var _old_scene_id: int = 0
var _pressed: Dictionary = {} # action -> force (état enregistré ou imposé)
var _next_input: int = 0
var _applied_frame: int = -1 # dernière image dont les entrées ont été envoyées
var _track_index: Dictionary = {} # chemin -> prochaine entrée à comparer
## Donné par DebugMenu : sait si la prochaine image va être jouée en pause.
var time_controller: Node


## Recharge la scène en cours et commence une prise.
func start_recording() -> void:
	var scene: Node = get_tree().current_scene
	if state != State.IDLE or scene == null or scene.scene_file_path == "":
		push_warning(T.t("DebugMenu: no scene loaded from a file, nothing to record."))
		return
	data = {
		"version": RecordingFile.VERSION,
		"scene": scene.scene_file_path,
		"seed": randi(),
		"time_scale": Engine.time_scale,
		"date": Time.get_datetime_string_from_system(),
		"frames": 0,
		"inputs": [],
		"tracks": {},
	}
	_begin(State.RECORDING)


## Recharge la scène de la prise [param path] et la rejoue.
func start_replay(path: String) -> bool:
	if state != State.IDLE:
		stop()
	var loaded: Variant = RecordingFile.load_file(path)
	if loaded == null:
		push_warning(T.t("DebugMenu: unreadable recording: %s") % path)
		return false
	data = loaded
	max_drift = 0.0
	max_drift_path = ""
	_track_index.clear()
	Engine.time_scale = float(data.get("time_scale", 1.0))
	_begin(State.REPLAYING)
	return true


func stop() -> void:
	var was_recording: bool = state == State.RECORDING
	if was_recording:
		data["frames"] = frame
		last_saved_path = RecordingFile.save(data)
	elif state == State.REPLAYING:
		_release_all()
	state = State.IDLE
	_pressed.clear()
	state_changed.emit()
	if was_recording and last_saved_path != "":
		recording_saved.emit(last_saved_path)


func get_progress() -> float:
	var total: int = int(data.get("frames", 0))
	return 0.0 if total == 0 else clampf(float(frame) / total, 0.0, 1.0)


func _notification(what: int) -> void:
	# Fermeture du jeu : la prise est enregistrée avant de quitter.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and state == State.RECORDING:
		stop()


func _begin(target_state: int) -> void:
	_release_all()
	_pressed.clear()
	_next_input = 0
	_applied_frame = -1
	_target_state = target_state
	_old_scene_id = get_tree().current_scene.get_instance_id() if get_tree().current_scene != null else 0
	state = State.STARTING
	state_changed.emit()
	get_tree().paused = false
	seed(int(data["seed"]))
	get_tree().change_scene_to_file(data["scene"])


# Exécuté avant les nœuds du jeu à chaque pas de physique (ordre de l'arbre),
# et même en pause (DebugMenu tourne toujours).
func _physics_process(_delta: float) -> void:
	if state == State.STARTING:
		var scene: Node = get_tree().current_scene
		if scene == null or scene.get_instance_id() == _old_scene_id:
			return
		# Première image de la nouvelle scène : image 0.
		frame = 0
		state = _target_state
		state_changed.emit()
	if state == State.RECORDING:
		if get_tree().paused:
			stop() # la pause termine la prise
			return
		_record_inputs()
		_record_tracks()
		frame += 1
	elif state == State.REPLAYING:
		if get_tree().paused:
			return # le replay attend
		if _applied_frame != frame:
			_apply_inputs() # pas envoyées avant (première image, rattrapage) : au mieux
		_compare_tracks()
		frame += 1
		if frame >= int(data["frames"]):
			stop()
			get_tree().paused = true # fin du replay : on reste sur la dernière image


# Avant l'image suivante : on y envoie ses entrées si elle va être jouée.
func _process(_delta: float) -> void:
	if state != State.REPLAYING or _applied_frame == frame:
		return
	var will_run: bool = not get_tree().paused
	if time_controller != null:
		will_run = time_controller.call("will_run_next_frame")
	if will_run:
		_apply_inputs()


# --- Prise ---

func _record_inputs() -> void:
	for action in _game_actions():
		var strength: float = Input.get_action_strength(action)
		if absf(strength - float(_pressed.get(action, 0.0))) > EPSILON:
			_pressed[action] = strength
			data["inputs"].append([frame, String(action), snappedf(strength, 0.001)])


func _record_tracks() -> void:
	if frame % TRACK_INTERVAL != 0:
		return
	var tracks: Dictionary = data["tracks"]
	for body in _tracked_bodies():
		var path: String = String(get_tree().current_scene.get_path_to(body))
		if not tracks.has(path):
			tracks[path] = []
		tracks[path].append(_position_entry(body))


# --- Replay ---

func _apply_inputs() -> void:
	var inputs: Array = data["inputs"]
	while _next_input < inputs.size() and int(inputs[_next_input][0]) <= frame:
		var entry: Array = inputs[_next_input]
		_pressed[StringName(entry[1])] = float(entry[2])
		_next_input += 1
	# L'état enregistré est imposé à chaque image : une touche pressée pour de
	# vrai pendant le replay est aussitôt annulée.
	for action in _game_actions():
		var target: float = float(_pressed.get(action, 0.0))
		if absf(Input.get_action_strength(action) - target) > EPSILON:
			_send(action, target)
	_applied_frame = frame


func _compare_tracks() -> void:
	if frame % TRACK_INTERVAL != 0:
		return
	var scene: Node = get_tree().current_scene
	var tracks: Dictionary = data["tracks"]
	for path in tracks:
		var entries: Array = tracks[path]
		var index: int = _track_index.get(path, 0)
		while index < entries.size() and int(entries[index][0]) < frame:
			index += 1
		_track_index[path] = index
		if index >= entries.size() or int(entries[index][0]) != frame:
			continue
		var body: Node = scene.get_node_or_null(NodePath(path))
		if body == null:
			continue
		var recorded: Array = entries[index]
		var now: Array = _position_entry(body)
		var drift: float = 0.0
		for axis in range(1, recorded.size()):
			drift = maxf(drift, absf(float(recorded[axis]) - float(now[axis])))
		if drift > max_drift:
			max_drift = drift
			max_drift_path = path


# --- Outils ---

func _game_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	for action in InputMap.get_actions():
		if not String(action).begins_with(IGNORED_PREFIX):
			actions.append(action)
	return actions


func _tracked_bodies() -> Array[Node]:
	var bodies: Array[Node] = []
	for type_name in ["CharacterBody2D", "RigidBody2D", "CharacterBody3D", "RigidBody3D"]:
		bodies.append_array(get_tree().current_scene.find_children("*", type_name, true, false))
	return bodies


func _position_entry(body: Node) -> Array:
	var position: Variant = body.get("global_position")
	if position is Vector3:
		return [frame, snappedf(position.x, 0.01), snappedf(position.y, 0.01), snappedf(position.z, 0.01)]
	return [frame, snappedf(position.x, 0.01), snappedf(position.y, 0.01)]


func _send(action: StringName, strength: float) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = strength > 0.0
	event.strength = strength
	Input.parse_input_event(event)
	# Godot regroupe les entrées et les traite à l'image suivante par défaut :
	# on force le traitement tout de suite, pour cette image.
	Input.flush_buffered_events()


func _release_all() -> void:
	for action in _pressed:
		if Input.is_action_pressed(action):
			_send(action, 0.0)

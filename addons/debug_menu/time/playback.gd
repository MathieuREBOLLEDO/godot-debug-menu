extends RefCounted

## Commandes de temps partagées (DebugMenu.playback) : pause, image +1,
## vitesse, et lecture d'une prise. Utilisées par la barre du haut
## (time/time_controls.gd, dans l'overlay) et les fenêtres Temps et Enregistrements, pour
## qu'elles fassent toujours la même chose.
## La vitesse dépend de ce qui tourne :
## - jeu normal : Engine.time_scale (x0.1 à x4) ;
## - replay d'une prise : le pas de calcul de la prise est gardé (sinon le
##   replay diverge) et c'est l'attente entre deux images qui s'allonge
##   (lecture image par image de time_controller.gd) ; x1 au plus.

signal changed

const InputRecorder = preload("res://addons/debug_menu/time/recording/input_recorder.gd")
const TimeController = preload("res://addons/debug_menu/time/time_controller.gd")
const SPEEDS: Array[float] = [0.1, 0.25, 0.5, 1.0, 2.0, 4.0]
const MAX_REPLAY_SPEED: float = 1.0

var recorder: InputRecorder
var time: TimeController

## Vitesse choisie (x1 = normale).
var speed: float = 1.0:
	set(value):
		speed = value
		if not is_paused():
			_apply_speed()
		changed.emit()


func _init(input_recorder: InputRecorder, time_controller: TimeController) -> void:
	recorder = input_recorder
	time = time_controller
	recorder.state_changed.connect(_on_recorder_state_changed)


func is_replaying() -> bool:
	return recorder.state == InputRecorder.State.REPLAYING or recorder.state == InputRecorder.State.STARTING


## En pause, et pas en train d'avancer image par image tout seul.
func is_paused() -> bool:
	return time.paused and not time.auto_step


## Vitesse réellement appliquée (bornée à x1 pendant un replay).
func effective_speed() -> float:
	return minf(speed, MAX_REPLAY_SPEED) if is_replaying() else speed


func set_paused(paused: bool) -> void:
	if paused:
		time.auto_step = false
		time.paused = true
	else:
		_apply_speed()
	changed.emit()


func toggle_pause() -> void:
	set_paused(not is_paused())


## Jeu en marche : le met en pause. En pause : une image de plus.
func step() -> void:
	if not is_paused():
		set_paused(true)
		return
	time.step()


# --- Prises ---

## Lance la prise [param path] depuis le début (scène rechargée).
func play_recording(path: String) -> void:
	if path != "" and recorder.start_replay(path):
		_apply_speed()
		changed.emit()


func stop_recording_playback() -> void:
	if is_replaying():
		recorder.stop()


func _apply_speed() -> void:
	if is_replaying():
		var replay_speed: float = effective_speed()
		if is_equal_approx(replay_speed, 1.0):
			time.auto_step = false
			time.paused = false
		else:
			time.auto_step_delay = 1.0 / (Engine.physics_ticks_per_second * replay_speed)
			time.auto_step = true
	else:
		time.auto_step = false
		Engine.time_scale = speed
		time.paused = false


func _on_recorder_state_changed() -> void:
	# Fin du replay : on revient au temps normal (le jeu reste en pause sur la
	# dernière image).
	if recorder.state == InputRecorder.State.IDLE:
		time.auto_step = false
		Engine.time_scale = speed
	changed.emit()

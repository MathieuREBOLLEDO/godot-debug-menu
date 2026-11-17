extends Node

## Contrôle du temps du jeu (enfant de DebugMenu) : pause, image par image et
## lecture image par image. Les commandes (barre, raccourcis, fenêtres)
## passent par time/playback.gd.
## « Une image » = un pas de physique + un _process. La pause de Godot
## (get_tree().paused) est levée au début d'un pas de physique et remise au
## prochain passage : comme DebugMenu est traité avant les nœuds du jeu
## (ordre de l'arbre) et tourne même en pause, les nœuds du jeu voient
## exactement un _physics_process et un _process.

signal stepped

## Lecture image par image : une image toutes les auto_step_delay secondes
## (temps réel), jeu en pause entre deux.
var auto_step: bool = false:
	set(value):
		auto_step = value
		if value:
			paused = true
var auto_step_delay: float = 0.5

var paused: bool:
	get:
		return get_tree().paused
	set(value):
		get_tree().paused = value

enum Step { NONE, WAITING_PHYSICS, PHYSICS_DONE, PROCESS_DONE }

var _step: int = Step.NONE
var _last_auto_step: float = 0.0


func _physics_process(_delta: float) -> void:
	if _step == Step.WAITING_PHYSICS:
		paused = false # le jeu fait ce pas de physique
		_step = Step.PHYSICS_DONE
	elif _step == Step.PHYSICS_DONE or _step == Step.PROCESS_DONE:
		# Pas de physique suivant (parfois deux pas avant un seul _process,
		# quand le jeu rattrape du retard) : on s'arrête avant lui.
		_end_step()


func _process(_delta: float) -> void:
	if _step == Step.PHYSICS_DONE:
		_step = Step.PROCESS_DONE # le jeu fait ce _process
		return
	if _step == Step.PROCESS_DONE:
		_end_step() # avant le _process suivant (affichage plus rapide que la physique)
		return
	if not auto_step or _step != Step.NONE:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_auto_step >= auto_step_delay:
		_last_auto_step = now
		step()


## true si la prochaine image physique va être jouée par le jeu : jeu en
## marche hors image par image, ou image suivante demandée.
func will_run_next_frame() -> bool:
	if _step == Step.WAITING_PHYSICS:
		return true
	return _step == Step.NONE and not paused


## Jeu en marche : le met en pause. En pause : joue une seule image.
func step() -> void:
	if not paused:
		paused = true
		return
	if _step == Step.NONE:
		_step = Step.WAITING_PHYSICS


func _end_step() -> void:
	paused = true
	_step = Step.NONE
	stepped.emit()

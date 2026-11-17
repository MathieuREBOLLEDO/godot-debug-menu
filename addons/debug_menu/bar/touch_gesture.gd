extends RefCounted

## Tap à 3 doigts (mobile) : affiche ou cache la barre, comme la touche ².
## Les 3 doigts doivent se poser en moins de MAX_DELAY s, tout lever en moins
## de MAX_DURATION s et ne pas glisser : un geste du jeu à 3 doigts qui dure
## (glisser, pincer) ne déclenche rien. Un 4e doigt annule.
## handle() peut recevoir deux fois le même événement (DebugMenu et une
## fenêtre de debug) : les doigts sont rangés par index, sans double compte.

signal tapped

const FINGERS: int = 3
const MAX_DELAY: float = 0.25
const MAX_DURATION: float = 0.5
const MAX_MOVE: float = 40.0 # pixels

var _touches: Dictionary = {} # index du doigt -> distance parcourue (relative : même valeur dans une fenêtre et dans le jeu)
var _most_fingers: int = 0
var _started: float = 0.0
var _candidate: bool = false


func handle(event: InputEvent) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			if _touches.is_empty():
				_started = now
				_most_fingers = 0
				_candidate = true
			if not _touches.has(touch.index):
				_touches[touch.index] = 0.0
			_most_fingers = maxi(_most_fingers, _touches.size())
			if _touches.size() > FINGERS or now - _started > MAX_DELAY:
				_candidate = false
		elif _touches.has(touch.index):
			_touches.erase(touch.index)
			if _touches.is_empty() and _candidate and _most_fingers == FINGERS and now - _started <= MAX_DURATION:
				_candidate = false
				tapped.emit()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if _touches.has(drag.index):
			_touches[drag.index] += drag.relative.length()
			if _touches[drag.index] > MAX_MOVE:
				_candidate = false

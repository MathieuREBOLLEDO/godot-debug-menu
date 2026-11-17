extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Événements des nœuds » : présent au démarrage, ajouté, retiré,
## libéré, dans l'ordre (node_events_view.gd). L'enregistrement tourne dès le
## lancement du jeu (node_recorder.gd, enfant de DebugMenu).

const NodeEventsView = preload("res://addons/debug_menu/scene/node_events_view.gd")
const NodeRecorder = preload("res://addons/debug_menu/scene/node_recorder.gd")
const REFRESH_INTERVAL: float = 0.5

var _view: NodeEventsView
var _recorder: NodeRecorder
var _refresh_time: float = REFRESH_INTERVAL # premier affichage tout de suite


func _ready() -> void:
	_view = NodeEventsView.new()
	if get_debug_menu() != null:
		_recorder = get_debug_menu().get("node_recorder")
		_view.recorder = _recorder
	super()


func _process(delta: float) -> void:
	_refresh_time += delta
	if visible and _refresh_time >= REFRESH_INTERVAL:
		_refresh_time = 0.0
		_view.refresh()
	super(delta)


func _build() -> void:
	add_status(_status_text)
	add_custom(_view, true)


func _status_text() -> String:
	if _recorder == null:
		return ""
	return T.t("%d event(s) kept (the last %d at most)") % [_recorder.events.size(), NodeRecorder.MAX_EVENTS]

extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Ressources » : fichiers du projet (scènes, ressources, scripts,
## images, sons, polices), en mémoire ou pas encore chargés
## (resources_view.gd).

const ResourcesView = preload("res://addons/debug_menu/scene/resources_view.gd")
const EngineCounters = preload("res://addons/debug_menu/scene/engine_counters.gd")
const REFRESH_INTERVAL: float = 1.0

var _view: ResourcesView
var _only_loaded: bool = false
var _refresh_time: float = 0.0


func _ready() -> void:
	_view = ResourcesView.new()
	super()
	_view.rescan()


func _process(delta: float) -> void:
	_refresh_time += delta
	if visible and _refresh_time >= REFRESH_INTERVAL:
		_refresh_time = 0.0
		_view.refresh()
	super(delta)


func _build() -> void:
	add_status(func() -> String: return EngineCounters.text())
	add_check(T.t("Only those in memory"), func() -> bool: return _only_loaded, func(on: bool) -> void:
		_only_loaded = on
		_view.set_only_loaded(on)
	)
	add_buttons("", [T.t("Rescan the project files")], func(_index: int) -> void: _view.rescan())
	add_custom(_view, true)

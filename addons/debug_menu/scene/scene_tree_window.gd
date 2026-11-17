extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Arbre des nœuds » : les nœuds chargés dans leur hiérarchie,
## avec leur ordre d'arrivée, et ceux retirés de l'arbre mais encore en
## mémoire (scene_tree_view.gd). La ligne de l'objet sélectionné est
## surlignée. Compteurs de Godot en bas.

const SceneTreeView = preload("res://addons/debug_menu/scene/scene_tree_view.gd")
const EngineCounters = preload("res://addons/debug_menu/scene/engine_counters.gd")
const REFRESH_INTERVAL: float = 0.5

var _view: SceneTreeView
var _refresh_time: float = REFRESH_INTERVAL # premier affichage tout de suite


func _ready() -> void:
	var debug_menu: Node = get_debug_menu()
	_view = SceneTreeView.new()
	if debug_menu != null:
		_view.recorder = debug_menu.get("node_recorder")
		var selection: Node = debug_menu.get("selection")
		_view.selected_object = selection.get_selected()
		selection.selection_changed.connect(func(object: Object) -> void:
			_view.selected_object = object
			# Différé : la sélection peut venir d'un clic dans l'arbre, qui ne
			# peut pas se reconstruire pendant son propre événement.
			_view.refresh.call_deferred(true)
		)
	super()


func _process(delta: float) -> void:
	_refresh_time += delta
	if visible and _refresh_time >= REFRESH_INTERVAL:
		_refresh_time = 0.0
		_view.refresh()
	super(delta)


func _build() -> void:
	add_status(func() -> String: return EngineCounters.text())
	add_hint(T.t("Orphans (bottom line): nodes outside the tree but still in memory, including those created in code and never added, which the tree cannot list."))
	add_custom(_view, true)

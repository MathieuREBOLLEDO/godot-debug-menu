extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Inspecteur » : l'objet sélectionné (barre de sélection en haut)
## avec ses variables (type, valeur initiale, valeur actuelle) et l'historique
## de chacune sur la dernière minute (depuis sa sélection).
## Un clic sur le bouton d'une valeur objet sélectionne cet objet.
## La colonne « Actuelle » se modifie ; l'œil ajoute la variable à la
## fenêtre Watch.
## Morceaux : variables_view.gd (tableau), variable_history.gd +
## history_view.gd (historique).

const VariablesView = preload("res://addons/debug_menu/objects/inspector/variables_view.gd")
const VariableHistory = preload("res://addons/debug_menu/objects/inspector/variable_history.gd")
const HistoryView = preload("res://addons/debug_menu/objects/inspector/history_view.gd")
const PhysicsTarget = preload("res://addons/debug_menu/objects/physics/physics_target.gd")
const REFRESH_INTERVAL: float = 0.1 # affichage ; l'enregistrement, lui, se fait à chaque frame

var _selection: Node # selection.gd
var _target: Object = null
var _had_target: bool = false # un objet était affiché (même s'il vient d'être libéré)
var _target_freed: bool = false
var _show_engine: bool = false
var _variables: Array[String] = []
var _history: VariableHistory = VariableHistory.new()
var _selected_variable: String = ""
var _refresh_time: float = 0.0
var _variables_view: VariablesView
var _history_view: HistoryView


func _ready() -> void:
	if get_debug_menu() != null:
		_selection = get_debug_menu().get("selection")
		_selection.selection_changed.connect(_on_selection_changed)
	super()


func _process(delta: float) -> void:
	if _target != null:
		var now: float = _now()
		for variable in _variables:
			_history.record(now, variable, _target.get(variable))
		_refresh_time += delta
		if _refresh_time >= REFRESH_INTERVAL:
			_refresh_time = 0.0
			_variables_view.refresh()
			_refresh_history()
	super(delta)


func _build() -> void:
	if _selection == null:
		add_note(T.t("DebugMenu not found: the Inspector needs the addon to be active."))
		return
	add_selection_bar()
	add_status(_status_text)
	_target = _selection.get_selected()
	_had_target = _target != null
	_history.clear()
	_selected_variable = ""
	_variables.clear()
	if _target == null:
		add_note(T.t("The selected object was freed (it left the scene).") if _target_freed else T.t("Choose an object: search, picker, or click in a list."))
		return

	if _target is Node and PhysicsTarget.resolve(_target as Node) != null:
		add_buttons(T.t("Open in"), [T.t("Physics")], func(_index: int) -> void: get_debug_menu().call("show_physics", _target))
	add_check(T.t("Also show Godot properties"), func() -> bool: return _show_engine, func(on: bool) -> void:
		_show_engine = on
		rebuild()
	)
	var split: VSplitContainer = VSplitContainer.new()
	_variables_view = VariablesView.new()
	_variables_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_variables_view.custom_minimum_size = Vector2(0, 120)
	_variables_view.variable_selected.connect(_on_variable_selected)
	_variables_view.object_clicked.connect(func(object: Object) -> void: _selection.select(object))
	_variables_view.watch_requested.connect(func(variable: String) -> void: get_debug_menu().call("watch_variable", _target, variable))
	_variables_view.show_target(_target, _show_engine)
	split.add_child(_variables_view)
	_history_view = HistoryView.new()
	split.add_child(_history_view)
	add_custom(split, true)
	for property in VariablesView.list_variables(_target, _show_engine):
		_variables.append(property["name"])


func _on_selection_changed(object: Object) -> void:
	# Un objet libéré vaut aussi null : _had_target dit s'il y en avait un.
	_target_freed = object == null and _had_target
	rebuild()


# Chemin et script de l'objet, en bas de la fenêtre.
func _status_text() -> String:
	if _target == null:
		return ""
	var script: Script = _target.get_script() as Script
	var script_text: String = T.t("script %s") % (script.resource_path.get_file() if script != null else T.t("none"))
	if _target is Node and (_target as Node).is_inside_tree():
		return "%s · %s" % [(_target as Node).get_path(), script_text]
	if _target is Resource and (_target as Resource).resource_path != "":
		return "%s · %s" % [(_target as Resource).resource_path, script_text]
	return script_text


# --- Historique ---

func _on_variable_selected(variable: String) -> void:
	_selected_variable = variable
	_refresh_history()


func _refresh_history() -> void:
	if _selected_variable != "":
		_history_view.show_history(_selected_variable, _history.get_entries(_selected_variable), _now(), VariableHistory.DURATION)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

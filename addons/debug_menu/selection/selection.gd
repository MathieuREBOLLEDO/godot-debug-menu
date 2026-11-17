extends Node

## L'objet sélectionné, unique et partagé par tout le debug menu (enfant de
## DebugMenu, DebugMenu.selection). Les fenêtres « objet » (Inspecteur,
## Physique...) le suivent ; la pipette, la recherche et les listes le
## changent avec select(). back() revient au précédent.
## Si l'objet sélectionné est libéré, selection_changed(null) est émis.

signal selection_changed(object: Object)
## La pipette démarre (true) ou s'arrête (false).
signal pipette_toggled(active: bool)

const Pipette = preload("res://addons/debug_menu/selection/pipette.gd")
const MAX_BACK: int = 30

var _selected: Object = null
var _watching: bool = false # un objet est sélectionné (même s'il vient d'être libéré)
var _back: Array = [] # sélections précédentes, la plus récente à la fin
var _pipette: Pipette = null


func _process(_delta: float) -> void:
	# Un objet libéré vaut aussi null : on teste d'abord s'il y en avait un.
	if _watching and not is_instance_valid(_selected):
		_watching = false
		_selected = null
		selection_changed.emit(null)


## L'objet sélectionné, ou null (rien, ou objet libéré).
func get_selected() -> Object:
	return _selected if is_instance_valid(_selected) else null


func select(object: Object) -> void:
	if object == get_selected():
		return
	if get_selected() != null:
		_back.append(_selected)
		if _back.size() > MAX_BACK:
			_back.pop_front()
	_apply(object)


## Revient à la sélection précédente encore valide.
func back() -> void:
	while not _back.is_empty():
		var previous: Variant = _back.pop_back()
		if is_instance_valid(previous):
			_apply(previous)
			return


func can_go_back() -> bool:
	for previous in _back:
		if is_instance_valid(previous):
			return true
	return false


# --- Pipette ---

## Lance la pipette : le prochain clic dans le jeu sélectionne l'objet visé.
## La relancer pendant qu'elle est active l'arrête.
func toggle_pipette() -> void:
	if is_pipette_active():
		_stop_pipette()
		return
	_pipette = Pipette.new()
	_pipette.node_picked.connect(func(node: Node) -> void:
		_pipette = null
		pipette_toggled.emit(false)
		select(node)
	)
	_pipette.cancelled.connect(func() -> void:
		_pipette = null
		pipette_toggled.emit(false)
	)
	# Sous DebugMenu : ignorée par la recherche et l'enregistreur de nœuds.
	get_parent().add_child(_pipette)
	pipette_toggled.emit(true)


func is_pipette_active() -> bool:
	return _pipette != null and is_instance_valid(_pipette)


func _stop_pipette() -> void:
	if is_pipette_active():
		_pipette.queue_free()
	_pipette = null
	pipette_toggled.emit(false)


func _apply(object: Object) -> void:
	_selected = object
	_watching = object != null
	selection_changed.emit(object)

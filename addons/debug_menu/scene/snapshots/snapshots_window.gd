extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Snapshots and seed » : recharger la scène, graine du hasard
## (affichée, fixable), photos de la scène à reprendre plus tard.
## Le travail est fait par DebugMenu.random_seed (scene/random_seed.gd) et
## DebugMenu.snapshots (scene/snapshots/snapshots.gd).

const RandomSeed = preload("res://addons/debug_menu/scene/random_seed.gd")
const Snapshots = preload("res://addons/debug_menu/scene/snapshots/snapshots.gd")

var _seed: RandomSeed
var _snapshots: Snapshots
var _list: ItemList
var _name_field: LineEdit


func _ready() -> void:
	if get_debug_menu() != null:
		_seed = get_debug_menu().get("random_seed")
		_snapshots = get_debug_menu().get("snapshots")
		_snapshots.changed.connect(_fill_list)
		_seed.changed.connect(rebuild)
	super()


func _build() -> void:
	if _snapshots == null:
		add_note(T.t("DebugMenu not found: Snapshots needs the addon to be active."))
		return
	add_section(T.t("Reload"))
	add_button(T.t("Reload scene"), func() -> void: get_debug_menu().call("reload_scene"))

	add_section(T.t("Random seed"))
	add_label(T.t("Current seed: %d") % _seed.current)
	# Fixer sans valeur choisie : la graine en cours (refaire la partie qu'on vient de voir).
	add_check(T.t("Fixed seed (at launch and on each reload)"), _seed.is_fixed, func(on: bool) -> void:
		_seed.set_fixed(on, _seed.current if not _seed.is_fixed() else _seed.get_fixed_value())
	)
	add_text_field(T.t("Fixed value"), str(_seed.get_fixed_value()), "", func(text: String) -> void:
		if text.strip_edges().is_valid_int():
			_seed.set_fixed(true, text.strip_edges().to_int())
	)
	add_hint(T.t("Only Godot's global random functions (randi, randf...). RandomNumberGenerator objects keep their own seed."))

	add_section(T.t("Snapshots"))
	_name_field = add_text_field(T.t("Name"), "", T.t("Optional"), func(_text: String) -> void: _take())
	add_buttons("", [T.t("Take snapshot"), T.t("Restore"), T.t("Delete")], func(index: int) -> void:
		match index:
			0: _take()
			1: _snapshots.restore(_selected_index())
			2: _snapshots.remove(_selected_index())
	)
	_list = ItemList.new()
	_list.focus_mode = Control.FOCUS_NONE
	_list.custom_minimum_size.y = 100.0
	_list.item_activated.connect(_snapshots.restore)
	add_custom(_list, true)
	add_hint(T.t("Kept in memory until the game closes. Not restored: autoloads, timers, tweens, animation positions, physics internals, random state."))
	_fill_list()


func _take() -> void:
	_snapshots.take(_name_field.text.strip_edges())
	_name_field.text = ""


func _selected_index() -> int:
	var selected: PackedInt32Array = _list.get_selected_items()
	return selected[0] if not selected.is_empty() else _list.item_count - 1


func _fill_list() -> void:
	if _list == null or not is_instance_valid(_list):
		return
	_list.clear()
	for snapshot in _snapshots.get_list():
		_list.add_item("%s   %s   %s   %s" % [snapshot.snapshot_name, snapshot.date_text,
				snapshot.scene_path.get_file(), T.t("%d node(s)") % snapshot.node_count])

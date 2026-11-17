extends VBoxContainer

## Historique d'une variable (dernière minute) : courbe pour un nombre, liste
## des changements sinon (le plus récent en haut).

const HistoryGraph = preload("res://addons/debug_menu/objects/inspector/history_graph.gd")
const ValueFormat = preload("res://addons/debug_menu/ui/value_format.gd")
const T = preload("res://addons/debug_menu/i18n/t.gd")
const MAX_LINES: int = 50

var _title: Label
var _graph: HistoryGraph
var _changes: ItemList


func _init() -> void:
	_title = Label.new()
	_title.text = T.t("Select a variable to see its history.")
	_title.theme_type_variation = "DebugPanelNote"
	add_child(_title)
	_graph = HistoryGraph.new()
	add_child(_graph)
	_changes = ItemList.new()
	_changes.custom_minimum_size = Vector2(0, 80)
	_changes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_changes.focus_mode = Control.FOCUS_NONE
	add_child(_changes)


## [param entries] : [temps, valeur] du plus ancien au plus récent.
func show_history(variable: String, entries: Array, now: float, duration: float) -> void:
	_title.text = T.t("%s: %d change(s) over %d s") % [variable, maxi(entries.size() - 1, 0), int(duration)]
	var numeric: bool = not entries.is_empty() and typeof(entries.back()[1]) in [TYPE_INT, TYPE_FLOAT]
	_graph.visible = numeric
	if numeric:
		_graph.show_entries(entries, now, duration)
	_changes.clear()
	for index in range(entries.size() - 1, maxi(entries.size() - 1 - MAX_LINES, -1), -1):
		var entry: Array = entries[index]
		_changes.add_item("-%.1f s   %s" % [now - float(entry[0]), ValueFormat.text(entry[1])])


func clear_history() -> void:
	_title.text = T.t("Select a variable to see its history.")
	_graph.visible = false
	_changes.clear()

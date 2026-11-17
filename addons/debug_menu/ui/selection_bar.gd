extends VBoxContainer

## Barre de sélection, la même en haut de chaque fenêtre « objet »
## (debug_window.gd, add_selection_bar) :
##     [←] [chercher un nœud...] [pipette]
##     Gringo · CharacterBody2D
## Tout passe par la sélection partagée (selection/selection.gd) : chercher,
## pipette ou « ← » la changent, et la barre affiche toujours l'objet
## sélectionné. Les résultats de recherche s'affichent sous le champ ; un clic
## sélectionne et vide la recherche.

const NodeFinder = preload("res://addons/debug_menu/selection/node_finder.gd")
const PIPETTE_ICON: Texture2D = preload("res://addons/debug_menu/icons/pipette.svg")
const T = preload("res://addons/debug_menu/i18n/t.gd")
const RESULTS_HEIGHT: float = 110.0

var _selection: Node # selection.gd
var _back_button: Button
var _search_edit: LineEdit
var _pipette_button: Button
var _results: ItemList
var _current: Label


func _init() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	_back_button = _make_button("←", T.t("Go back to the previously selected object"))
	_back_button.pressed.connect(func() -> void: _selection.back())
	row.add_child(_back_button)
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = T.t("Search a node by name")
	_search_edit.clear_button_enabled = true
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(_on_search_text_changed)
	row.add_child(_search_edit)
	_pipette_button = _make_button("", T.t("Picker: click an object in the game (right click or Esc to cancel)"))
	_pipette_button.icon = PIPETTE_ICON
	_pipette_button.toggle_mode = true
	_pipette_button.toggled.connect(func(_on: bool) -> void: _selection.toggle_pipette())
	row.add_child(_pipette_button)

	_results = ItemList.new()
	_results.custom_minimum_size.y = RESULTS_HEIGHT
	_results.focus_mode = Control.FOCUS_NONE
	_results.visible = false
	_results.item_selected.connect(_on_result_selected)
	add_child(_results)

	_current = Label.new()
	_current.clip_text = true
	add_child(_current)


func _ready() -> void:
	var debug_menu: Node = get_tree().root.get_node_or_null(NodeFinder.DEBUG_MENU_PATH)
	_selection = debug_menu.get("selection") if debug_menu != null else null
	if _selection == null:
		_current.text = T.t("DebugMenu not found.")
		return
	_selection.selection_changed.connect(func(_object: Object) -> void: _update_current())
	_selection.pipette_toggled.connect(_pipette_button.set_pressed_no_signal)
	_update_current()


func _update_current() -> void:
	var object: Object = _selection.get_selected()
	_back_button.disabled = not _selection.can_go_back()
	if object == null:
		_current.text = T.t("Nothing selected")
		_current.tooltip_text = ""
	elif object is Node:
		_current.text = "%s · %s" % [(object as Node).name, object.get_class()]
		_current.tooltip_text = String((object as Node).get_path()) if (object as Node).is_inside_tree() else ""
	else:
		var path: String = (object as Resource).resource_path if object is Resource else ""
		_current.text = "%s · %s" % [path.get_file() if path != "" else T.t("(no file)"), object.get_class()]
		_current.tooltip_text = path


func _on_search_text_changed(text: String) -> void:
	_results.clear()
	for node in NodeFinder.search(get_tree(), text):
		_results.add_item("%s   (%s)" % [node.name, node.get_path()])
		_results.set_item_metadata(_results.item_count - 1, node)
	_results.visible = _results.item_count > 0


func _on_result_selected(index: int) -> void:
	# Le nœud a pu être libéré depuis la recherche.
	var node: Variant = _results.get_item_metadata(index)
	if is_instance_valid(node):
		_selection.select(node)
	_search_edit.clear()
	_results.clear()
	_results.visible = false


func _make_button(text: String, tooltip: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	return button

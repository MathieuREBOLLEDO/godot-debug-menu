extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Variable finder » : chercher une variable par son nom (ou sa
## valeur) dans les objets chargés, filtrés par la liste « Objets » : actifs,
## inactifs, tous, ou l'objet sélectionné et ses enfants.
## Résultats : Objet | Variable | Valeur ; l'œil ajoute la variable à Watch,
## un double-clic ouvre l'objet dans l'Inspecteur.
## La recherche (variable_search.gd) se relance après une courte pause dans
## la frappe ou au changement d'un filtre, pas à chaque image.

const VariableSearch = preload("res://addons/debug_menu/objects/finder/variable_search.gd")
const WATCH_ICON: Texture2D = preload("res://addons/debug_menu/icons/eye.svg")
const SEARCH_DELAY: float = 0.3
const REFRESH_INTERVAL: float = 0.5 # valeurs des résultats affichés

var _selection: Node # selection.gd
var _text: String = ""
var _scope: int = VariableSearch.Scope.ACTIVE
var _in_values: bool = false
var _include_engine: bool = false
var _results: Array[Dictionary] = []
var _search_delay: float = -1.0 # < 0 : pas de recherche en attente
var _refresh_time: float = 0.0
var _tree: Tree


func _ready() -> void:
	if get_debug_menu() != null:
		_selection = get_debug_menu().get("selection")
		_selection.selection_changed.connect(func(_object: Object) -> void:
			if _scope == VariableSearch.Scope.SELECTION:
				_search_soon()
		)
	super()


func _process(delta: float) -> void:
	if _search_delay >= 0.0:
		_search_delay -= delta
		if _search_delay < 0.0:
			_search()
	_refresh_time += delta
	if _tree != null and _refresh_time >= REFRESH_INTERVAL:
		_refresh_time = 0.0
		_refresh_values()
	super(delta)


func _build() -> void:
	if _selection == null:
		add_note(T.t("DebugMenu not found: Variable finder needs the addon to be active."))
		return
	add_selection_bar()
	add_status(_status_text)
	var field: LineEdit = add_text_field(T.t("Search"), _text, T.t("Variable name"), func(_value: String) -> void: _search())
	field.text_changed.connect(func(value: String) -> void:
		_text = value
		_search_soon()
	)
	var scopes: Array = VariableSearch.SCOPE_NAMES.map(func(scope_name: String) -> String: return T.t(scope_name))
	add_option(T.t("Objects"), scopes, _scope, func(index: int) -> void:
		_scope = index
		_search()
	)
	add_check(T.t("Search in values too"), func() -> bool: return _in_values, func(on: bool) -> void:
		_in_values = on
		_search()
	)
	add_check(T.t("Also Godot properties"), func() -> bool: return _include_engine, func(on: bool) -> void:
		_include_engine = on
		_search()
	)
	_tree = _make_tree()
	add_custom(_tree, true)
	_search()


func _make_tree() -> Tree:
	var tree: Tree = Tree.new()
	tree.columns = 3
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	tree.focus_mode = Control.FOCUS_NONE
	tree.custom_minimum_size.y = 120.0
	tree.set_column_title(0, T.t("Object"))
	tree.set_column_title(1, T.t("Variable"))
	tree.set_column_title(2, T.t("Value"))
	tree.button_clicked.connect(func(item: TreeItem, _column: int, _id: int, _mouse_button: int) -> void:
		var result: Dictionary = _results[item.get_metadata(0)]
		if is_instance_valid(result["node"]):
			get_debug_menu().call("watch_variable", result["node"], result["property"])
	)
	tree.item_activated.connect(func() -> void:
		var result: Dictionary = _results[tree.get_selected().get_metadata(0)]
		if is_instance_valid(result["node"]):
			get_debug_menu().call("inspect", result["node"])
	)
	return tree


func _search_soon() -> void:
	_search_delay = SEARCH_DELAY


func _search() -> void:
	_search_delay = -1.0
	if _tree == null:
		return
	var selected: Object = _selection.get_selected()
	_results = VariableSearch.search(get_tree(), _text, _scope, _in_values, _include_engine, selected as Node if selected is Node else null)
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	for index in _results.size():
		var result: Dictionary = _results[index]
		var node: Node = result["node"]
		var item: TreeItem = _tree.create_item(root)
		item.set_metadata(0, index)
		item.set_text(0, String(node.name))
		item.set_tooltip_text(0, String(node.get_path()))
		item.set_text(1, result["property"])
		item.add_button(2, WATCH_ICON, 0, false, T.t("Watch this variable"))
	_refresh_values()


func _refresh_values() -> void:
	var root: TreeItem = _tree.get_root()
	if root == null:
		return
	for item in root.get_children():
		var result: Dictionary = _results[item.get_metadata(0)]
		item.set_text(2, ValueFormat.text(result["node"].get(result["property"])) if is_instance_valid(result["node"]) else T.t("(freed)"))


func _status_text() -> String:
	if _tree == null:
		return ""
	var text: String = T.t("%d result(s)") % _results.size()
	if _results.size() >= VariableSearch.MAX_RESULTS:
		text += " · " + T.t("limit reached, refine the search")
	return text

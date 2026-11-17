extends Tree

## Tableau de la fenêtre Watch : une ligne par objet chargé, et en dessous
## ses variables suivies (Variable | Valeur). Les valeurs se modifient comme
## dans l'Inspecteur (value_cells.gd) ; × retire une variable de la liste.
## Double-clic sur une ligne : l'objet s'ouvre dans l'Inspecteur.

signal inspect_requested(node: Node)
signal remove_requested(path: String, property: String)

const ValueCells = preload("res://addons/debug_menu/objects/inspector/value_cells.gd")
const REMOVE_ICON: Texture2D = preload("res://addons/debug_menu/icons/close.svg")
const T = preload("res://addons/debug_menu/i18n/t.gd")
const COLUMN_NAME: int = 0
const COLUMN_VALUE: int = 1

var _rows: Array[Dictionary] = [] # {item, node, property}


func _init() -> void:
	columns = 2
	column_titles_visible = true
	hide_root = true
	select_mode = Tree.SELECT_ROW
	focus_mode = Control.FOCUS_NONE
	set_column_title(COLUMN_NAME, T.t("Variable"))
	set_column_title(COLUMN_VALUE, T.t("Value"))
	set_column_expand_ratio(COLUMN_NAME, 2)
	set_column_expand_ratio(COLUMN_VALUE, 3)
	item_edited.connect(_on_item_edited)
	button_clicked.connect(_on_button_clicked)
	item_activated.connect(_on_item_activated)


## [param entries] : [{path, property}] ; [param nodes] : le nœud de chaque
## entrée, ou null s'il n'est pas chargé (l'entrée n'est pas affichée).
func show_entries(entries: Array, nodes: Array) -> void:
	clear()
	_rows.clear()
	var root: TreeItem = create_item()
	var groups: Dictionary = {} # chemin -> TreeItem de l'objet
	for index in entries.size():
		var node: Node = nodes[index]
		if node == null:
			continue
		var entry: Dictionary = entries[index]
		var property: Dictionary = _find_property(node, entry["property"])
		if property.is_empty():
			continue
		if not groups.has(entry["path"]):
			var group: TreeItem = create_item(root)
			group.set_text(COLUMN_NAME, "%s (%s)" % [node.name, node.get_class()])
			group.set_tooltip_text(COLUMN_NAME, entry["path"])
			group.set_metadata(COLUMN_NAME, node)
			groups[entry["path"]] = group
		var item: TreeItem = create_item(groups[entry["path"]])
		item.set_text(COLUMN_NAME, entry["property"])
		item.set_metadata(COLUMN_NAME, node)
		ValueCells.setup(item, COLUMN_VALUE, property)
		item.add_button(COLUMN_VALUE, REMOVE_ICON, 0, false, T.t("Stop watching"))
		_rows.append({"item": item, "node": node, "property": entry["property"]})
	refresh()


## Met à jour les valeurs affichées.
func refresh() -> void:
	for row in _rows:
		# Objet libéré depuis le dernier affichage : la fenêtre refait le tableau.
		if is_instance_valid(row["node"]):
			ValueCells.show_value(row["item"], COLUMN_VALUE, (row["node"] as Node).get(row["property"]))


func get_shown_count() -> int:
	return _rows.size()


func _find_property(node: Node, property_name: String) -> Dictionary:
	for property in node.get_property_list():
		if property["name"] == property_name:
			return property
	return {}


func _row_of(item: TreeItem) -> Dictionary:
	for row in _rows:
		if row["item"] == item:
			return row
	return {}


# Valeur saisie : écrite dans l'objet ; un texte illisible remet l'ancienne.
func _on_item_edited() -> void:
	var row: Dictionary = _row_of(get_edited())
	if row.is_empty() or not is_instance_valid(row["node"]):
		return
	var node: Node = row["node"]
	var value: Variant = ValueCells.read_value(row["item"], COLUMN_VALUE, node.get(row["property"]))
	if value != null:
		node.set(row["property"], value)
	ValueCells.show_value(row["item"], COLUMN_VALUE, node.get(row["property"]))


func _on_button_clicked(item: TreeItem, _column: int, _id: int, _mouse_button: int) -> void:
	var row: Dictionary = _row_of(item)
	if not row.is_empty() and is_instance_valid(row["node"]):
		remove_requested.emit(String((row["node"] as Node).get_path()), row["property"])


func _on_item_activated() -> void:
	var node: Variant = get_selected().get_metadata(COLUMN_NAME) if get_selected() != null else null
	if is_instance_valid(node) and node is Node:
		inspect_requested.emit(node)

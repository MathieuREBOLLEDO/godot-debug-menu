extends Tree

## Tableau des variables de l'objet inspecté : Variable | Type | Init | Actuelle.
## « Init » : valeur par défaut déclarée dans le script pour une variable
## exportée. Godot ne donne pas celle des autres variables : on affiche alors
## la valeur au moment de la sélection, suivie de « * ».
## « Actuelle » se modifie (voir value_cells.gd) ; une couleur a en plus un
## bouton qui ouvre un sélecteur ; l'œil (objets de la scène) ajoute la
## variable à la fenêtre Watch.

signal variable_selected(variable: String)
## Clic sur le bouton d'une valeur qui est un objet (nœud, ressource...).
signal object_clicked(object: Object)
## Clic sur l'œil d'une variable (fenêtre Watch).
signal watch_requested(variable: String)

const ValueFormat = preload("res://addons/debug_menu/ui/value_format.gd")
const ValueCells = preload("res://addons/debug_menu/objects/inspector/value_cells.gd")
const OPEN_ICON: Texture2D = preload("res://addons/debug_menu/icons/open.svg")
const WATCH_ICON: Texture2D = preload("res://addons/debug_menu/icons/eye.svg")
const COLOR_ICON: Texture2D = preload("res://addons/debug_menu/icons/pipette.svg")
const T = preload("res://addons/debug_menu/i18n/t.gd")
const COLUMN_NAME: int = 0
const COLUMN_TYPE: int = 1
const COLUMN_INIT: int = 2
const COLUMN_VALUE: int = 3
const BUTTON_OPEN: int = 0
const BUTTON_COLOR: int = 1
const BUTTON_WATCH: int = 2

var _target: Object = null
var _items: Dictionary = {} # nom -> TreeItem
var _color_popup: PopupPanel = null
var _color_variable: String = ""


func _init() -> void:
	columns = 4
	column_titles_visible = true
	hide_root = true
	select_mode = Tree.SELECT_ROW
	focus_mode = Control.FOCUS_NONE
	set_column_title(COLUMN_NAME, T.t("Variable"))
	set_column_title(COLUMN_TYPE, T.t("Type"))
	set_column_title(COLUMN_INIT, T.t("Initial"))
	set_column_title(COLUMN_VALUE, T.t("Current"))
	set_column_expand_ratio(COLUMN_NAME, 3)
	set_column_expand_ratio(COLUMN_TYPE, 2)
	set_column_expand_ratio(COLUMN_INIT, 2)
	set_column_expand_ratio(COLUMN_VALUE, 3)
	item_selected.connect(_on_item_selected)
	button_clicked.connect(_on_button_clicked)
	item_edited.connect(_on_item_edited)


## Liste les variables de [param target] : celles de son script, et aussi
## celles de Godot si [param include_engine].
func show_target(target: Object, include_engine: bool) -> void:
	clear()
	_items.clear()
	_target = target
	if target == null:
		return
	var root: TreeItem = create_item()
	var script: Script = target.get_script() as Script
	for property in list_variables(target, include_engine):
		var variable: String = property["name"]
		var item: TreeItem = create_item(root)
		item.set_text(COLUMN_NAME, variable)
		item.set_text(COLUMN_TYPE, _type_text(property))
		var usage: int = property["usage"]
		var exported_script_variable: bool = (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (usage & PROPERTY_USAGE_EDITOR) != 0
		if exported_script_variable and script != null:
			item.set_text(COLUMN_INIT, ValueFormat.text(script.get_property_default_value(variable)))
		else:
			item.set_text(COLUMN_INIT, ValueFormat.text(target.get(variable)) + " *")
			item.set_tooltip_text(COLUMN_INIT, T.t("Value when it was selected (Godot does not give the default value of this variable)."))
		ValueCells.setup(item, COLUMN_VALUE, property)
		if property["type"] == TYPE_COLOR and item.is_editable(COLUMN_VALUE):
			item.add_button(COLUMN_VALUE, COLOR_ICON, BUTTON_COLOR, false, T.t("Pick a color"))
		if target is Node:
			item.add_button(COLUMN_VALUE, WATCH_ICON, BUTTON_WATCH, false, T.t("Watch this variable"))
		_items[variable] = item
	refresh()


## Met à jour la colonne « Actuelle ». Une valeur qui est un objet reçoit un
## bouton pour l'ouvrir dans l'Inspecteur.
func refresh() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	for variable in _items:
		var item: TreeItem = _items[variable]
		var value: Variant = _target.get(variable)
		ValueCells.show_value(item, COLUMN_VALUE, value)
		var openable: bool = typeof(value) == TYPE_OBJECT and is_instance_valid(value)
		var button_index: int = item.get_button_by_id(COLUMN_VALUE, BUTTON_OPEN)
		if openable and button_index < 0:
			item.add_button(COLUMN_VALUE, OPEN_ICON, BUTTON_OPEN, false, T.t("Inspect this object"))
		elif not openable and button_index >= 0:
			item.erase_button(COLUMN_VALUE, button_index)


## Propriétés à afficher : variables du script, et propriétés de Godot
## visibles dans l'inspecteur de l'éditeur si [param include_engine].
static func list_variables(target: Object, include_engine: bool) -> Array[Dictionary]:
	var variables: Array[Dictionary] = []
	for property in target.get_property_list():
		var usage: int = property["usage"]
		if usage & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP | PROPERTY_USAGE_CATEGORY):
			continue
		var is_script: bool = (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0
		var is_engine: bool = include_engine and (usage & PROPERTY_USAGE_EDITOR) != 0
		if is_script or is_engine:
			variables.append(property)
	return variables


func _type_text(property: Dictionary) -> String:
	var class_text: String = property["class_name"]
	if class_text != "":
		return class_text
	return type_string(property["type"])


func _on_button_clicked(item: TreeItem, _column: int, id: int, _mouse_button: int) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var variable: String = item.get_text(COLUMN_NAME)
	var value: Variant = _target.get(variable)
	match id:
		BUTTON_OPEN:
			if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
				object_clicked.emit(value)
		BUTTON_COLOR:
			_open_color_picker(variable, value)
		BUTTON_WATCH:
			watch_requested.emit(variable)


# Valeur saisie dans « Actuelle » : écrite dans l'objet. Un texte illisible
# remet l'ancienne valeur.
func _on_item_edited() -> void:
	var item: TreeItem = get_edited()
	if item == null or _target == null or not is_instance_valid(_target):
		return
	var variable: String = item.get_text(COLUMN_NAME)
	var current: Variant = _target.get(variable)
	var value: Variant = ValueCells.read_value(item, COLUMN_VALUE, current)
	if value != null:
		_target.set(variable, value)
	ValueCells.show_value(item, COLUMN_VALUE, _target.get(variable))


# --- Sélecteur de couleur ---

func _open_color_picker(variable: String, value: Color) -> void:
	if _color_popup == null:
		_color_popup = PopupPanel.new()
		var picker: ColorPicker = ColorPicker.new()
		picker.color_changed.connect(func(color: Color) -> void:
			if _target != null and is_instance_valid(_target):
				_target.set(_color_variable, color)
		)
		_color_popup.add_child(picker)
		add_child(_color_popup)
	_color_variable = variable
	(_color_popup.get_child(0) as ColorPicker).color = value
	_color_popup.popup_on_parent(Rect2i(Vector2i(get_global_mouse_position()), Vector2i.ZERO))


func _on_item_selected() -> void:
	var item: TreeItem = get_selected()
	if item != null:
		variable_selected.emit(item.get_text(COLUMN_NAME))

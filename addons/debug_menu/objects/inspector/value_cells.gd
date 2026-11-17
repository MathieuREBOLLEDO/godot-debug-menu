extends RefCounted

## Colonne « Actuelle » de l'Inspecteur, modifiable : comment montrer une
## valeur selon son type, et relire ce que l'utilisateur a saisi.
## - bool : case à cocher ;
## - int / float : champ numérique (bornes et pas de @export_range, sinon
##   sans bornes) ; enum sans valeurs explicites : liste ;
## - String, StringName, NodePath, vecteurs, Color : texte, relu au même
##   type (« 1, 2 », « (1, 2) » ou « Vector2(1, 2) » pour un Vector2) ;
## - le reste (objets, tableaux, Rect2...) : lecture seule.

const ValueFormat = preload("res://addons/debug_menu/ui/value_format.gd")
const UNBOUNDED: float = 1e9
const TEXT_TYPES: Array[int] = [TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH,
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_COLOR]


## Mode de la cellule selon la propriété (une fois, à l'affichage de l'objet).
static func setup(item: TreeItem, column: int, property: Dictionary) -> void:
	var type: int = property["type"]
	var writable: bool = (property["usage"] & PROPERTY_USAGE_READ_ONLY) == 0
	var editable: bool = writable
	if type == TYPE_BOOL:
		item.set_cell_mode(column, TreeItem.CELL_MODE_CHECK)
	elif is_enum(property):
		item.set_cell_mode(column, TreeItem.CELL_MODE_RANGE)
		item.set_text(column, property["hint_string"])
	elif type == TYPE_INT or type == TYPE_FLOAT:
		item.set_cell_mode(column, TreeItem.CELL_MODE_RANGE)
		var bounds: Array = range_of(property)
		item.set_range_config(column, bounds[0], bounds[1], bounds[2])
	else:
		item.set_cell_mode(column, TreeItem.CELL_MODE_STRING)
		editable = writable and TEXT_TYPES.has(type)
	item.set_editable(column, editable)


## Montre [param value] dans la cellule (mode choisi par setup()).
static func show_value(item: TreeItem, column: int, value: Variant) -> void:
	match item.get_cell_mode(column):
		TreeItem.CELL_MODE_CHECK:
			item.set_checked(column, bool(value))
		TreeItem.CELL_MODE_RANGE:
			item.set_range(column, float(value))
		_:
			item.set_text(column, _text(value))


## Valeur saisie, au type de [param current] ; null si le texte ne se lit pas.
static func read_value(item: TreeItem, column: int, current: Variant) -> Variant:
	match item.get_cell_mode(column):
		TreeItem.CELL_MODE_CHECK:
			return item.is_checked(column)
		TreeItem.CELL_MODE_RANGE:
			var number: float = item.get_range(column)
			return int(number) if typeof(current) == TYPE_INT else number
	var text: String = item.get_text(column)
	match typeof(current):
		TYPE_STRING:
			return text
		TYPE_STRING_NAME:
			return StringName(text)
		TYPE_NODE_PATH:
			return NodePath(text)
	return parse(text, typeof(current))


## Lit un vecteur ou une couleur : « 1, 2 », « (1, 2) » ou « Vector2(1, 2) ».
static func parse(text: String, type: int) -> Variant:
	text = text.strip_edges()
	var type_name: String = type_string(type)
	if not text.begins_with(type_name):
		text = "%s(%s)" % [type_name, text.trim_prefix("(").trim_suffix(")")]
	var value: Variant = str_to_var(text)
	return value if typeof(value) == type else null


## Bornes et pas d'un nombre : [min, max, pas]. Ceux de @export_range s'il y
## en a (« or_greater » / « or_less » ouvrent la borne), sinon sans bornes.
static func range_of(property: Dictionary) -> Array:
	var is_int: bool = property["type"] == TYPE_INT
	var bounds: Array = [-UNBOUNDED, UNBOUNDED, 1.0 if is_int else 0.001]
	if property["hint"] != PROPERTY_HINT_RANGE:
		return bounds
	var parts: PackedStringArray = String(property["hint_string"]).split(",")
	if parts.size() >= 2:
		bounds[0] = parts[0].to_float()
		bounds[1] = parts[1].to_float()
	if parts.size() > 2 and parts[2].is_valid_float():
		bounds[2] = parts[2].to_float()
	if parts.has("or_greater"):
		bounds[1] = UNBOUNDED
	if parts.has("or_less"):
		bounds[0] = -UNBOUNDED
	return bounds


## Enum dont les valeurs suivent l'ordre (0, 1, 2...) : affichable en liste.
static func is_enum(property: Dictionary) -> bool:
	return property["type"] == TYPE_INT and property["hint"] == PROPERTY_HINT_ENUM \
			and not String(property["hint_string"]).contains(":")


static func _text(value: Variant) -> String:
	var type: int = typeof(value)
	if type == TYPE_STRING or type == TYPE_STRING_NAME or type == TYPE_NODE_PATH:
		return str(value)
	return ValueFormat.text(value)

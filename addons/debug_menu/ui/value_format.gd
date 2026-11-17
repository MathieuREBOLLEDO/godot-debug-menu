extends RefCounted
const T = preload("res://addons/debug_menu/i18n/t.gd")

## Texte court et lisible pour une valeur quelconque (les tableaux et objets
## bruts sont illisibles). Utilisé par debug_window.gd et l'inspecteur.


static func text(value: Variant) -> String:
	var type: int = typeof(value)
	if type == TYPE_NIL:
		return "null"
	if type == TYPE_FLOAT:
		return "%.3f" % value
	if type == TYPE_VECTOR2:
		return "(%.2f, %.2f)" % [value.x, value.y]
	if type == TYPE_VECTOR3:
		return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]
	if type == TYPE_DICTIONARY:
		return T.t("%d key(s)") % (value as Dictionary).size()
	if type >= TYPE_ARRAY and type < TYPE_MAX: # Array et tableaux Packed*
		return T.t("%d item(s)") % value.size()
	if type == TYPE_OBJECT:
		return _object_text(value)
	return str(value)


static func _object_text(value: Variant) -> String:
	if not is_instance_valid(value):
		return T.t("(freed)")
	var object: Object = value
	if object is Node:
		return "%s (%s)" % [(object as Node).name, object.get_class()]
	if object is Resource and (object as Resource).resource_path != "":
		return (object as Resource).resource_path.get_file()
	return object.get_class()

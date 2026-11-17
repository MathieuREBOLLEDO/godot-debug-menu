extends RefCounted

## Génération automatique de champs (debug_window.gd, add_properties) : un
## champ par variable exportée (@export) du script de l'objet :
## - nombre avec @export_range -> curseur (bornes, pas et unité repris) ;
## - bool -> case à cocher ;
## - autre -> valeur en lecture seule.
## Les @export_group deviennent des sections.


## [param window] : une fenêtre debug_window.gd (pas typée ici pour éviter
## que les deux scripts se chargent l'un l'autre).
static func build(window: Window, target: Object, only_group: String) -> void:
	var group: String = ""
	var section_pending: bool = false # la section n'apparaît qu'avec son premier champ
	for property in target.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_GROUP:
			group = property["name"]
			section_pending = only_group == ""
			continue
		var exported: bool = (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (usage & PROPERTY_USAGE_EDITOR) != 0
		if not exported or (only_group != "" and group != only_group):
			continue
		if section_pending:
			window.call("add_section", group)
			section_pending = false
		_add_field(window, target, property)


static func _add_field(window: Window, target: Object, property: Dictionary) -> void:
	var property_name: StringName = property["name"]
	var text: String = String(property_name).capitalize()
	var type: int = property["type"]
	if type == TYPE_BOOL:
		window.call("add_property_check", target, property_name, text)
	elif (type == TYPE_FLOAT or type == TYPE_INT) and property["hint"] == PROPERTY_HINT_RANGE:
		# hint_string : "min,max[,pas][,suffix:unité][,autres options]"
		var parts: PackedStringArray = String(property["hint_string"]).split(",")
		var step: float = 1.0 if type == TYPE_INT else 0.01
		if parts.size() > 2 and parts[2].is_valid_float():
			step = parts[2].to_float()
		var unit: String = ""
		for part in parts:
			if part.begins_with("suffix:"):
				unit = " " + part.trim_prefix("suffix:")
		window.call("add_slider", target, property_name, text, parts[0].to_float(), parts[1].to_float(), step, unit)
	else:
		window.call("add_value", target, property_name, text)

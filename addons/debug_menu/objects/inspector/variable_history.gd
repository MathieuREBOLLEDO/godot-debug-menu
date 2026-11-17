extends RefCounted

## Historique des valeurs des variables de l'objet inspecté, sur les
## DURATION dernières secondes. Seuls les changements sont gardés, ce qui
## reste léger même en enregistrant à chaque frame.

const DURATION: float = 60.0

var _entries: Dictionary = {} # nom -> Array de [temps, valeur], du plus ancien au plus récent


func clear() -> void:
	_entries.clear()


func record(time: float, variable: String, value: Variant) -> void:
	if not _entries.has(variable):
		_entries[variable] = []
	var entries: Array = _entries[variable]
	if entries.is_empty() or not _same(entries.back()[1], value):
		entries.append([time, _snapshot(value)])
	# On garde une entrée plus ancienne que la fenêtre : la valeur au début.
	while entries.size() > 1 and entries[1][0] < time - DURATION:
		entries.pop_front()


## [temps, valeur] du plus ancien au plus récent.
func get_entries(variable: String) -> Array:
	return _entries.get(variable, [])


# Comparer deux types différents avec == peut échouer : on vérifie le type avant.
static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b


# Copie des tableaux et dictionnaires : sinon l'historique suivrait leurs
# modifications.
static func _snapshot(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value

extends RefCounted

## Graine du hasard global de Godot (randi, randf, randi_range...)
## (DebugMenu.random_seed). Godot ne dit pas quelle graine il utilise : le
## debug menu en tire une au lancement et l'applique, pour pouvoir l'afficher.
## Graine fixe (gardée d'une partie à l'autre) : appliquée au lancement et à
## chaque rechargement de scène, pour retrouver le même hasard.
## Limites : les RandomNumberGenerator du jeu ont leur propre graine, et les
## autoloads placés avant DebugMenu ont déjà tiré au lancement. Les prises
## (REC) gardent leur propre graine.

signal changed

## Graine appliquée en dernier.
var current: int = 0

var _store: RefCounted # settings_store.gd


func _init(store: RefCounted) -> void:
	_store = store


func is_fixed() -> bool:
	return _store.get("seed_fixed")


func get_fixed_value() -> int:
	return _store.get("seed_value")


## Graine fixe [param value] (appliquée tout de suite), ou plus de graine fixe.
func set_fixed(fixed: bool, value: int) -> void:
	_store.set("seed_fixed", fixed)
	_store.set("seed_value", value)
	_store.call("save")
	if fixed:
		apply(value)
	changed.emit()


## Au lancement et avant un rechargement : la graine fixe, sinon une nouvelle.
func apply_next() -> void:
	if is_fixed():
		apply(get_fixed_value())
	else:
		randomize()
		apply(randi())


func apply(value: int) -> void:
	current = value
	seed(value)
	changed.emit()

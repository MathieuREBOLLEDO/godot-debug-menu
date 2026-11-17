extends RefCounted

## Écoute tous les signaux d'un objet et note chaque émission : instant,
## image, nom du signal et arguments. Utilisé par signals_window.gd.
## Godot 4.0 n'a pas de fonction à nombre d'arguments variable : un signal à
## n arguments est relié à _on_signal_n (jusqu'à MAX_ARGUMENTS), le nom du
## signal étant ajouté à la fin par bind().

const ValueFormat = preload("res://addons/debug_menu/ui/value_format.gd")
const MAX_ENTRIES: int = 500
const MAX_ARGUMENTS: int = 6

## Augmente à chaque nouvelle entrée (la fenêtre redessine la liste si besoin).
var version: int = 0
## [{time: float, frame: int, text: String, is_script: bool}], du plus ancien au plus récent.
var entries: Array[Dictionary] = []

var _target: Object = null
var _connections: Array[Dictionary] = [] # {signal, callable}
var _script_signals: Dictionary = {} # nom -> true : signaux déclarés dans le script
var _skipped: PackedStringArray = PackedStringArray() # trop d'arguments


## Écoute [param target] (null : n'écoute plus rien). Le journal est vidé.
func watch(target: Object) -> void:
	stop()
	clear()
	_target = target
	if target == null:
		return
	var script: Script = target.get_script() as Script
	if script != null:
		for info in script.get_script_signal_list():
			_script_signals[info["name"]] = true
	for info in target.get_signal_list():
		var signal_name: String = info["name"]
		var argument_count: int = (info["args"] as Array).size()
		if argument_count > MAX_ARGUMENTS:
			_skipped.append(signal_name)
			continue
		var callable: Callable = Callable(self, "_on_signal_%d" % argument_count).bind(signal_name)
		target.connect(signal_name, callable)
		_connections.append({"signal": signal_name, "callable": callable})


func stop() -> void:
	if _target != null and is_instance_valid(_target):
		for connection in _connections:
			if _target.is_connected(connection["signal"], connection["callable"]):
				_target.disconnect(connection["signal"], connection["callable"])
	_connections.clear()
	_script_signals.clear()
	_skipped.clear()
	_target = null


func clear() -> void:
	entries.clear()
	version += 1


func get_watched_count() -> int:
	return _connections.size()


## Signaux non écoutés (plus de MAX_ARGUMENTS arguments).
func get_skipped() -> PackedStringArray:
	return _skipped


func _record(signal_name: String, arguments: Array) -> void:
	var texts: PackedStringArray = PackedStringArray()
	for argument in arguments:
		texts.append(ValueFormat.text(argument))
	entries.append({
		"time": Time.get_ticks_msec() / 1000.0,
		"frame": Engine.get_process_frames(),
		"text": "%s(%s)" % [signal_name, ", ".join(texts)],
		"is_script": _script_signals.has(signal_name),
	})
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()
	version += 1


func _on_signal_0(signal_name: String) -> void:
	_record(signal_name, [])


func _on_signal_1(a: Variant, signal_name: String) -> void:
	_record(signal_name, [a])


func _on_signal_2(a: Variant, b: Variant, signal_name: String) -> void:
	_record(signal_name, [a, b])


func _on_signal_3(a: Variant, b: Variant, c: Variant, signal_name: String) -> void:
	_record(signal_name, [a, b, c])


func _on_signal_4(a: Variant, b: Variant, c: Variant, d: Variant, signal_name: String) -> void:
	_record(signal_name, [a, b, c, d])


func _on_signal_5(a: Variant, b: Variant, c: Variant, d: Variant, e: Variant, signal_name: String) -> void:
	_record(signal_name, [a, b, c, d, e])


func _on_signal_6(a: Variant, b: Variant, c: Variant, d: Variant, e: Variant, f: Variant, signal_name: String) -> void:
	_record(signal_name, [a, b, c, d, e, f])

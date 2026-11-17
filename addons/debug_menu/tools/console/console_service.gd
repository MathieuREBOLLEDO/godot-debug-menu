extends Node

## Console du debug menu (enfant de DebugMenu, DebugMenu.console), active même
## fenêtre fermée :
## - registre des commandes : add_command(nom, fonction, description, usage) ;
##   la fonction reçoit les arguments (PackedStringArray) et peut renvoyer un
##   texte à afficher ;
## - journal : lignes de commande, réponses, et logs du jeu (print,
##   avertissements, erreurs) capturés par log_capture.gd (Godot 4.5+).
## La fenêtre Console (console_window.gd) affiche le journal et envoie les
## commandes à execute().

signal line_added(line: Dictionary)
signal cleared

enum Kind { LOG, WARNING, ERROR, COMMAND, RESULT }

const T = preload("res://addons/debug_menu/i18n/t.gd")
const MAX_LINES: int = 1000
const LOG_CAPTURE_PATH: String = "res://addons/debug_menu/tools/console/log_capture.gd"

## Du plus ancien au plus récent : {time, kind, text}.
var lines: Array[Dictionary] = []
var _commands: Dictionary = {} # nom -> {callable, description, usage}
var _log_capture: RefCounted = null


func _ready() -> void:
	_start_log_capture()


func _exit_tree() -> void:
	if _log_capture != null and OS.has_method("remove_logger"):
		OS.call("remove_logger", _log_capture)


func _process(_delta: float) -> void:
	if _log_capture != null:
		for entry in _log_capture.call("take_pending"):
			add_line(entry["kind"], entry["text"])


# --- Commandes ---

## Déclare la commande [param command_name]. [param callable]
## (args: PackedStringArray) -> Variant : une valeur renvoyée (texte...) est
## affichée dans la console.
func add_command(command_name: String, callable: Callable, description: String = "", usage: String = "") -> void:
	_commands[command_name.to_lower()] = {"callable": callable, "description": description, "usage": usage}


func get_command_names() -> Array:
	var names: Array = _commands.keys()
	names.sort()
	return names


## Description et usage, pour help.
func describe(command_name: String) -> String:
	var command: Dictionary = _commands.get(command_name.to_lower(), {})
	if command.is_empty():
		return ""
	var usage: String = command["usage"]
	return "%s%s — %s" % [command_name, " " + usage if usage != "" else "", T.t(command["description"])]


## Exécute une ligne : « nom arg1 "arg avec espaces" ».
func execute(line: String) -> void:
	var words: PackedStringArray = split_words(line)
	if words.is_empty():
		return
	add_line(Kind.COMMAND, "> " + line)
	var command: Dictionary = _commands.get(words[0].to_lower(), {})
	if command.is_empty():
		add_line(Kind.ERROR, T.t("Unknown command: %s (type help)") % words[0])
		return
	var result: Variant = (command["callable"] as Callable).call(words.slice(1))
	if result != null and str(result) != "":
		add_line(Kind.RESULT, str(result))


## Noms de commandes qui commencent par [param prefix].
func complete(prefix: String) -> Array:
	return get_command_names().filter(func(command_name: String) -> bool: return command_name.begins_with(prefix.to_lower()))


# --- Journal ---

func add_line(kind: int, text: String) -> void:
	var line: Dictionary = {"time": Time.get_ticks_msec() / 1000.0, "kind": kind, "text": text}
	lines.append(line)
	if lines.size() > MAX_LINES:
		lines.pop_front()
	line_added.emit(line)


func clear() -> void:
	lines.clear()
	cleared.emit()


## true si les logs du jeu sont capturés (Godot 4.5+ : classe Logger).
func is_capturing_logs() -> bool:
	return _log_capture != null


# Le script de capture hérite de Logger, qui n'existe qu'à partir de Godot
# 4.5 : il n'est chargé (load, pas preload) que si la classe existe.
func _start_log_capture() -> void:
	if not ClassDB.class_exists("Logger") or not OS.has_method("add_logger"):
		return
	_log_capture = (load(LOG_CAPTURE_PATH) as GDScript).new()
	OS.call("add_logger", _log_capture)


## Découpe en mots ; les guillemets regroupent : say "bonjour toi" -> 2 mots.
static func split_words(line: String) -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	var current: String = ""
	var quoted: bool = false
	for character in line.strip_edges():
		if character == "\"":
			quoted = not quoted
		elif character == " " and not quoted:
			if current != "":
				words.append(current)
			current = ""
		else:
			current += character
	if current != "":
		words.append(current)
	return words

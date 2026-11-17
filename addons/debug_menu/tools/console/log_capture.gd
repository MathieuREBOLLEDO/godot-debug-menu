extends Logger

## Capture des logs du jeu pour la console (Godot 4.5+, OS.add_logger) :
## print(), avertissements et erreurs. Les messages peuvent arriver depuis
## d'autres threads : ils sont mis de côté sous verrou, puis la console les
## récupère à chaque frame (take_pending).
## Ce script n'est chargé que si la classe Logger existe (console_service.gd).

# Mêmes valeurs que console_service.gd (Kind).
const KIND_LOG: int = 0
const KIND_WARNING: int = 1
const KIND_ERROR: int = 2

var _mutex: Mutex = Mutex.new()
var _pending: Array = []


func _log_message(message: String, error: bool) -> void:
	_push(KIND_ERROR if error else KIND_LOG, message.strip_edges(false, true))


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var text: String = rationale if rationale != "" else code
	var kind: int = KIND_WARNING if error_type == 1 else KIND_ERROR # 1 = ERROR_TYPE_WARNING
	# Un push_warning / push_error d'un script est signalé depuis le moteur
	# (fichier .cpp) : la ligne du script est plus utile, quand elle est connue.
	# Si l'appel passe par un addon (fonction de log comme Log.warn), on montre
	# le premier appelant hors des addons.
	for backtrace in script_backtraces:
		if backtrace.get_frame_count() > 0:
			var frame: int = _caller_frame(backtrace)
			file = backtrace.get_frame_file(frame)
			line = backtrace.get_frame_line(frame)
			function = backtrace.get_frame_function(frame)
			break
	_push(kind, "%s  (%s:%d, %s)" % [text, file.get_file(), line, function])


# Premier appel hors de res://addons/ ; à défaut, le plus récent.
static func _caller_frame(backtrace: ScriptBacktrace) -> int:
	for frame in backtrace.get_frame_count():
		if not backtrace.get_frame_file(frame).begins_with("res://addons/"):
			return frame
	return 0


func take_pending() -> Array:
	_mutex.lock()
	var taken: Array = _pending
	_pending = []
	_mutex.unlock()
	return taken


func _push(kind: int, text: String) -> void:
	_mutex.lock()
	_pending.append({"kind": kind, "text": text})
	_mutex.unlock()

extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Console » : le journal (logs du jeu, commandes, réponses) avec un
## filtre par type, et une ligne de commande : Entrée exécute, ↑ / ↓ parcourent
## l'historique, Tab complète le nom de la commande. Tant que la ligne de
## commande a le focus, les raccourcis du debug menu sont coupés (on peut
## taper ² ou F7).
## Le journal et les commandes vivent dans console_service.gd.

const ConsoleService = preload("res://addons/debug_menu/tools/console/console_service.gd")
const AnsiColors = preload("res://addons/debug_menu/tools/console/ansi_colors.gd")
const KIND_NAMES: Array[String] = ["Logs", "Warnings", "Errors", "Commands"]
const KIND_COLORS: Array[String] = ["e8e9ec", "ffd84f", "ff6b6b", "4fa3ff", "b8f0c8"]
const MAX_HISTORY: int = 50

var _console: ConsoleService
var _shown_kinds: Array[bool] = [true, true, true, true]
var _history: PackedStringArray = PackedStringArray()
var _history_index: int = -1
var _output: RichTextLabel
var _input: LineEdit


func _ready() -> void:
	if get_debug_menu() != null:
		_console = get_debug_menu().get("console")
		_console.line_added.connect(_on_line_added)
		_console.cleared.connect(func() -> void: _output.clear())
	super()


func _build() -> void:
	if _console == null:
		add_note(T.t("DebugMenu not found: this window needs the addon to be active."))
		return
	add_status(_status_text)
	var filters: HBoxContainer = HBoxContainer.new()
	for index in KIND_NAMES.size():
		var check: CheckBox = CheckBox.new()
		check.text = T.t(KIND_NAMES[index])
		check.button_pressed = _shown_kinds[index]
		check.focus_mode = Control.FOCUS_NONE
		check.toggled.connect(func(on: bool) -> void:
			_shown_kinds[index] = on
			_render_all()
		)
		filters.add_child(check)
	add_custom(filters)

	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.focus_mode = Control.FOCUS_NONE
	_output.custom_minimum_size.y = 160.0
	add_custom(_output, true)

	var input_row: HBoxContainer = HBoxContainer.new()
	_input = LineEdit.new()
	_input.placeholder_text = T.t("Command (help for the list)")
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(_run)
	_input.gui_input.connect(_on_input_gui_input)
	_input.focus_entered.connect(_set_shortcut_capture.bind(true))
	_input.focus_exited.connect(_set_shortcut_capture.bind(false))
	input_row.add_child(_input)
	var run_button: Button = Button.new()
	run_button.text = T.t("Run")
	run_button.focus_mode = Control.FOCUS_NONE
	run_button.pressed.connect(func() -> void: _run(_input.text))
	input_row.add_child(run_button)
	add_custom(input_row)
	_render_all()


func _exit_tree() -> void:
	_set_shortcut_capture(false)


# Pendant la saisie, les raccourcis du debug menu sont coupés.
func _set_shortcut_capture(capturing: bool) -> void:
	if is_inside_tree() and get_debug_menu() != null:
		get_debug_menu().call("set_shortcut_capture", capturing)


func _run(line: String) -> void:
	if line.strip_edges() == "":
		return
	_history.append(line)
	if _history.size() > MAX_HISTORY:
		_history.remove_at(0)
	_history_index = -1
	_input.clear()
	_console.execute(line)


# ↑ / ↓ : historique ; Tab : complétion du nom de commande.
func _on_input_gui_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_UP or key.keycode == KEY_DOWN:
		if _history.is_empty():
			return
		if _history_index == -1:
			_history_index = _history.size()
		_history_index = clampi(_history_index + (-1 if key.keycode == KEY_UP else 1), 0, _history.size())
		_input.text = _history[_history_index] if _history_index < _history.size() else ""
		_input.caret_column = _input.text.length()
		_input.accept_event()
	elif key.keycode == KEY_TAB:
		_complete()
		_input.accept_event()


func _complete() -> void:
	var words: PackedStringArray = ConsoleService.split_words(_input.text)
	if words.size() > 1:
		return
	var matches: Array = _console.complete(words[0] if not words.is_empty() else "")
	if matches.size() == 1:
		_input.text = matches[0] + " "
		_input.caret_column = _input.text.length()
	elif not matches.is_empty():
		_console.add_line(ConsoleService.Kind.RESULT, "  ".join(PackedStringArray(matches)))


# --- Affichage du journal ---

func _on_line_added(line: Dictionary) -> void:
	if _output != null and _is_shown(line["kind"]):
		_append(line)


func _render_all() -> void:
	_output.clear()
	for line in _console.lines:
		if _is_shown(line["kind"]):
			_append(line)


# Les réponses (RESULT) suivent le filtre des commandes.
func _is_shown(kind: int) -> bool:
	return _shown_kinds[mini(kind, ConsoleService.Kind.COMMAND)]


func _append(line: Dictionary) -> void:
	# Couleurs ANSI d'un print_rich (log.gd...) : converties en BBCode.
	var text: String = AnsiColors.to_bbcode(String(line["text"]))
	_output.append_text("[color=#%s]%s[/color]\n" % [KIND_COLORS[line["kind"]], text])


func _status_text() -> String:
	var capture: String = T.t("game logs captured") if _console.is_capturing_logs() else T.t("game logs not captured (Godot 4.5+ needed)")
	return T.t("%d line(s) · %s") % [_console.lines.size(), capture]

extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Paramètres » (bouton ⚙ de la barre) :
## - général : langue, mode souris (Debug / Game / Both) ;
## - apparence : couleur d'accent, fond, taille du texte, police (par défaut,
##   celles des jetons de design : design_tokens.gd) ;
## - raccourcis : cliquer sur la touche d'une action, puis appuyer sur la
##   nouvelle (Échap : annuler). Les touches sont enregistrées
##   (settings_store.gd) et appliquées à l'InputMap (shortcuts.gd).
## Les changements passent par l'API de DebugMenu (set_setting...).

const Shortcuts = preload("res://addons/debug_menu/settings/shortcuts.gd")
const Tokens = preload("res://addons/debug_menu/settings/design_tokens.gd")
const MouseModes = preload("res://addons/debug_menu/windows/mouse_modes.gd")
const MONTSERRAT_PATH: String = "res://addons/debug_menu/fonts/Montserrat-wght.ttf"
const FONT_CHOICES: Array[String] = ["Design tokens", "Montserrat", "Godot (default)", "Project file…"]
const MODIFIER_KEYS: Array[Key] = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]

var _font_from_file: bool = false # « Fichier du projet… » choisi, chemin pas encore validé
var _capturing_action: String = "" # action dont on attend la nouvelle touche
var _key_buttons: Dictionary = {} # action -> Button


func _ready() -> void:
	window_input.connect(_on_window_input)
	super()


func _build() -> void:
	var debug_menu: Node = get_debug_menu()
	if debug_menu == null:
		add_note(T.t("DebugMenu not found: this window needs the addon to be active."))
		return
	_build_general(debug_menu)
	_build_appearance(debug_menu)
	_build_shortcuts(debug_menu)


# --- Général ---

func _build_general(debug_menu: Node) -> void:
	add_section(T.t("General"))
	add_option(T.t("Language"), T.LANGUAGE_NAMES, T.LANGUAGES.find(T.get_language()), func(index: int) -> void:
		# DebugMenu refait la barre et les fenêtres, celle-ci comprise.
		debug_menu.call("set_language", T.LANGUAGES[index])
	)
	# Cette fenêtre reste cliquable en mode Game (debug_menu.gd).
	var mode: int = debug_menu.call("get_mouse_mode")
	var names: Array = MouseModes.NAMES.map(func(mode_name: String) -> String: return T.t(mode_name))
	var mouse_option: OptionButton = add_option(T.t("Mouse"), names, mode, func(index: int) -> void:
		debug_menu.call("set_mouse_mode", index)
		rebuild() # bulle du mode choisi
	)
	mouse_option.tooltip_text = T.t(MouseModes.TOOLTIPS[mode])
	for index in MouseModes.TOOLTIPS.size():
		mouse_option.get_popup().set_item_tooltip(index, T.t(MouseModes.TOOLTIPS[index]))


# --- Apparence ---

func _build_appearance(debug_menu: Node) -> void:
	add_section(T.t("Appearance"))
	add_color(T.t("Accent color"), debug_menu.call("get_setting", "accent_color"), false, func(color: Color) -> void: debug_menu.call("set_setting", "accent_color", color))
	add_color(T.t("Background"), debug_menu.call("get_setting", "background_color"), true, func(color: Color) -> void: debug_menu.call("set_setting", "background_color", color))
	add_spin(T.t("Text size"), debug_menu.call("get_setting", "font_size"), 10, 32, 1, func(value: float) -> void: debug_menu.call("set_setting", "font_size", int(value)))

	var font_path: String = debug_menu.call("get_setting", "font_path")
	var presets: Array[String] = [Tokens.FONT_FROM_TOKENS, MONTSERRAT_PATH, ""]
	var from_file: bool = _font_from_file or not presets.has(font_path)
	var choice: int = 3 if from_file else presets.find(font_path)
	add_option(T.t("Font"), FONT_CHOICES.map(func(choice_text: String) -> String: return T.t(choice_text)), choice, func(index: int) -> void:
		_font_from_file = index == 3
		if index < 3:
			debug_menu.call("set_setting", "font_path", presets[index])
		rebuild() # active ou non le champ du fichier
	)
	add_hint(T.t("Design tokens: the project's font (res://design_tokens.cfg, see DESIGN.md)."))
	var file_field: LineEdit = add_text_field(T.t("File"), font_path if from_file else "", T.t("res://…/font.ttf then Enter"), func(text: String) -> void: debug_menu.call("set_setting", "font_path", text))
	file_field.editable = from_file
	add_buttons("", [T.t("Reset the appearance")], func(_index: int) -> void:
		debug_menu.call("reset_settings")
		rebuild()
	)


# --- Raccourcis ---

func _build_shortcuts(debug_menu: Node) -> void:
	add_section(T.t("Shortcuts"))
	add_hint(T.t("Click the key of an action, then press the new one (Esc: cancel)."))
	_key_buttons.clear()
	for entry in Shortcuts.LIST:
		var action: String = entry[0]
		var row: HBoxContainer = add_buttons(T.t(entry[1]), [Shortcuts.key_text(action), T.t("Default")], func(index: int) -> void:
			if index == 0:
				_start_capture(action)
			else:
				debug_menu.call("reset_shortcut", action)
				rebuild()
		)
		_key_buttons[action] = row.get_child(1)


func _start_capture(action: String) -> void:
	_capturing_action = action
	(_key_buttons[action] as Button).text = T.t("Press a key…")
	get_debug_menu().call("set_shortcut_capture", true)


# La fenêtre reçoit le clavier quand elle a le focus (après le clic).
func _on_window_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if _capturing_action == "" or key == null or not key.pressed or key.echo:
		return
	var keycode: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if MODIFIER_KEYS.has(keycode):
		return # on attend la touche qui va avec Ctrl, Maj ou Alt
	set_input_as_handled()
	var debug_menu: Node = get_debug_menu()
	if keycode != KEY_ESCAPE:
		debug_menu.call("set_shortcut", _capturing_action, key)
	_capturing_action = ""
	debug_menu.call("set_shortcut_capture", false)
	rebuild()

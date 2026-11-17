extends RefCounted

## Raccourcis clavier du debug menu : des actions de l'InputMap.
## Au lancement, apply() crée celles qui manquent (touche par défaut) et
## applique les touches choisies dans les Paramètres (enregistrées dans
## settings_store.gd, section « shortcuts »). Le projet n'est pas modifié :
## seul l'InputMap du jeu en cours change.
## Une touche se décrit par {physical_keycode, ctrl, shift, alt} : la
## position de la touche, quelle que soit la disposition du clavier.

const TOGGLE: String = "debug_menu_toggle"
const PAUSE: String = "debug_menu_pause"
const PIPETTE: String = "debug_menu_pipette"
const REC: String = "debug_menu_rec"
const STEP: String = "debug_menu_step_frame"
const SCREENSHOT: String = "debug_menu_screenshot"
const FREE_CAMERA: String = "debug_menu_free_camera"
const CHEATS: String = "debug_menu_cheats"
const NOCLIP: String = "debug_menu_noclip"
const INVINCIBLE: String = "debug_menu_invincible"
const FREEZE: String = "debug_menu_freeze"
## Vitesses des cheats (Alt+1 à Alt+5), même ordre que cheats/cheats.gd SPEEDS.
const SPEED_ACTIONS: Array[String] = ["debug_menu_speed_1", "debug_menu_speed_2", "debug_menu_speed_3", "debug_menu_speed_4", "debug_menu_speed_5"]
const T = preload("res://addons/debug_menu/i18n/t.gd")

## Dans l'ordre des Paramètres : [action, libellé (anglais, traduit à
## l'affichage), touche par défaut, modificateur « ctrl » ou « alt »
## (facultatif)].
const LIST: Array = [
	[TOGGLE, "Show / hide the bar", KEY_QUOTELEFT],
	[PAUSE, "Pause / resume", KEY_F7],
	[STEP, "Next frame", KEY_F10],
	[PIPETTE, "Picker", KEY_F8],
	[REC, "REC: record / stop", KEY_F9],
	[SCREENSHOT, "Screenshot", KEY_F12],
	[FREE_CAMERA, "Free camera on / off", KEY_F, "ctrl"],
	[CHEATS, "Cheat codes", KEY_C, "alt"],
	[NOCLIP, "No clip on / off", KEY_G, "ctrl"],
	[INVINCIBLE, "Invincible on / off", KEY_V, "alt"],
	["debug_menu_speed_1", "Game speed x0.25", KEY_1, "alt"],
	["debug_menu_speed_2", "Game speed x0.5", KEY_2, "alt"],
	["debug_menu_speed_3", "Game speed x1", KEY_3, "alt"],
	["debug_menu_speed_4", "Game speed x2", KEY_4, "alt"],
	["debug_menu_speed_5", "Game speed x4", KEY_5, "alt"],
	[FREEZE, "Freeze / unfreeze the game", KEY_D, "ctrl"],
]


## [param saved] : action -> touche (voir to_dict()).
static func apply(saved: Dictionary) -> void:
	for entry in LIST:
		var action: String = entry[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			InputMap.action_add_event(action, default_event(action))
		if saved.has(action) and saved[action] is Dictionary:
			set_key(action, make_event(saved[action]))


static func set_key(action: String, event: InputEventKey) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)


## Touche par défaut de [param action].
static func default_event(action: String) -> InputEventKey:
	for entry in LIST:
		if entry[0] == action:
			var modifier: String = entry[3] if entry.size() > 3 else ""
			return make_event({"physical_keycode": entry[2], "ctrl": modifier == "ctrl", "alt": modifier == "alt"})
	return null


## Nom de la touche physique [param physical] sur le clavier de l'utilisateur
## (« Z » en AZERTY pour la touche W d'un QWERTY).
static func physical_label(physical: Key) -> String:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical
	return _key_name(event)


## « F10 », « Ctrl+F9 »... pour [param action].
static func key_text(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		var key: InputEventKey = event as InputEventKey
		if key != null:
			var modifiers: String = ("Ctrl+" if key.ctrl_pressed else "") + (T.t("Shift+") if key.shift_pressed else "") + ("Alt+" if key.alt_pressed else "")
			return modifiers + _key_name(key)
	return "?"


# Nom de la touche sur le clavier de l'utilisateur (² en AZERTY pour la
# touche physique « QuoteLeft »), quand Godot sait le donner (4.2+).
static func _key_name(key: InputEventKey) -> String:
	if key.physical_keycode == KEY_NONE:
		return OS.get_keycode_string(key.keycode)
	if DisplayServer.has_method("keyboard_get_label_from_physical") and DisplayServer.get_name() != "headless":
		var label: int = DisplayServer.call("keyboard_get_label_from_physical", key.physical_keycode)
		if label != KEY_NONE:
			return OS.get_keycode_string(label)
	return OS.get_keycode_string(key.physical_keycode)


static func make_event(data: Dictionary) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = int(data.get("physical_keycode", KEY_NONE))
	event.ctrl_pressed = bool(data.get("ctrl", false))
	event.shift_pressed = bool(data.get("shift", false))
	event.alt_pressed = bool(data.get("alt", false))
	return event


## Touche appuyée [param event] -> données à enregistrer.
static func to_dict(event: InputEventKey) -> Dictionary:
	var keycode: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	return {"physical_keycode": keycode, "ctrl": event.ctrl_pressed, "shift": event.shift_pressed, "alt": event.alt_pressed}

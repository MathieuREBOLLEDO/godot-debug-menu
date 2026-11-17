extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Cheat codes » (menu Cheats, Alt+C) : onglet Base (no clip,
## invincible, vitesse et gel du jeu), puis un onglet par catégorie de
## cheats déclarée par le jeu (DebugMenu.add_cheat). Tout passe par
## cheats/cheats.gd.

const Cheats = preload("res://addons/debug_menu/cheats/cheats.gd")
const Shortcuts = preload("res://addons/debug_menu/settings/shortcuts.gd")

var _cheats: Cheats = null
var _tab: int = 0


func _ready() -> void:
	if get_debug_menu() != null:
		_cheats = get_debug_menu().get("cheats")
	super()
	if _cheats != null:
		_cheats.changed.connect(rebuild)


func _build() -> void:
	if _cheats == null:
		add_note(T.t("DebugMenu not found: this window needs the addon to be active."))
		return
	add_status(_status_text)
	var categories: Array[String] = _cheats.categories()
	var titles: Array = [T.t("Base")]
	for category in categories:
		titles.append(T.t(category))
	_tab = mini(_tab, titles.size() - 1)
	add_tabs(titles, _tab, func(index: int) -> void:
		_tab = index
		rebuild()
	)
	if _tab == 0:
		_build_base(categories.is_empty())
	else:
		_build_category(categories[_tab - 1])


func _build_base(no_game_cheats: bool) -> void:
	add_section(T.t("Player"))
	if not _cheats.has_player():
		add_note(T.t("No player: the game declares it with DebugMenu.set_player(node)."))
	var noclip: CheckBox = add_check(T.t("No clip") + "  (%s)" % Shortcuts.key_text(Shortcuts.NOCLIP),
			func() -> bool: return _cheats.noclip, func(on: bool) -> void: _cheats.noclip = on)
	noclip.disabled = not _cheats.can_noclip()
	add_hint(T.t("The player flies through collisions: arrows or %s, %s / %s up / down in 3D, Shift: faster. A player with a debug_set_noclip(on) method handles it itself.") % [
		_move_keys(), Shortcuts.physical_label(KEY_E), Shortcuts.physical_label(KEY_Q)])
	if _cheats.has_player() and not _cheats.can_noclip():
		add_note(T.t("No clip needs a physics body (CharacterBody...) or a debug_set_noclip(on) method on the player."))
	add_check(T.t("Invincible") + "  (%s)" % Shortcuts.key_text(Shortcuts.INVINCIBLE),
			func() -> bool: return _cheats.invincible, func(on: bool) -> void: _cheats.invincible = on)
	add_hint(T.t("The game handles it: debug_set_invincible(on) is called on the player, or the game reads DebugMenu.cheats.invincible."))
	if _cheats.has_player() and not _cheats.supports_invincible():
		add_note(T.t("This player has no debug_set_invincible(on) method."))
	add_slider(_cheats, &"noclip_speed_2d", T.t("No clip speed 2D"), 50.0, 5000.0, 10.0, " px/s")
	add_slider(_cheats, &"noclip_speed_3d", T.t("No clip speed 3D"), 1.0, 100.0, 0.5, " m/s")

	add_section(T.t("Game speed"))
	var labels: Array = []
	for speed in Cheats.SPEEDS:
		labels.append("x%s" % _speed_text(speed))
	add_buttons(T.t("Speed"), labels, func(index: int) -> void: _cheats.set_speed(Cheats.SPEEDS[index]))
	add_hint(T.t("Shortcuts %s to %s. Choosing a speed unfreezes the game.") % [
		Shortcuts.key_text(Shortcuts.SPEED_ACTIONS[0]), Shortcuts.key_text(Shortcuts.SPEED_ACTIONS[Shortcuts.SPEED_ACTIONS.size() - 1])])
	add_button(T.t("Freeze / unfreeze") + "  (%s)" % Shortcuts.key_text(Shortcuts.FREEZE), _cheats.toggle_freeze)
	add_hint(T.t("Same as the pause of the debug menu (%s): the game stops, the debug menu keeps running.") % Shortcuts.key_text(Shortcuts.PAUSE))
	if no_game_cheats:
		add_section(T.t("Game cheats"))
		add_note(T.t("None yet: the game adds its own with DebugMenu.add_cheat(\"Category\", \"Name\", callable); each category gets a tab."))


func _build_category(category: String) -> void:
	add_section(T.t(category))
	for cheat in _cheats.cheats_in(category):
		add_button(T.t(cheat["name"]), _cheats.run.bind(cheat))


func _status_text() -> String:
	var playback: Object = _cheats.playback
	var speed: String = T.t("frozen") if playback.call("is_paused") else "x" + _speed_text(playback.call("effective_speed"))
	return T.t("No clip %s · Invincible %s · %s") % [
		T.t("on") if _cheats.noclip else T.t("off"), T.t("on") if _cheats.invincible else T.t("off"), speed]


func _speed_text(speed: float) -> String:
	return str(snappedf(speed, 0.01)).trim_suffix(".0")


func _move_keys() -> String:
	var keys: String = ""
	for key in [KEY_W, KEY_A, KEY_S, KEY_D]:
		keys += Shortcuts.physical_label(key)
	return keys

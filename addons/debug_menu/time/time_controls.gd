extends HBoxContainer

## Commandes de temps de l'overlay (time_overlay.gd) : [pause/lecture]
## [image +1] [vitesse ▾].
## Elles passent par time/playback.gd : pendant le replay d'une prise, la
## même vitesse devient un ralenti fidèle (x1 au plus).

const Playback = preload("res://addons/debug_menu/time/playback.gd")
const ThemeBuilder = preload("res://addons/debug_menu/settings/debug_menu_theme.gd")
const PAUSE_ICON: Texture2D = preload("res://addons/debug_menu/icons/pause.svg")
const PLAY_ICON: Texture2D = preload("res://addons/debug_menu/icons/play.svg")
const STEP_ICON: Texture2D = preload("res://addons/debug_menu/icons/step.svg")
const T = preload("res://addons/debug_menu/i18n/t.gd")
const Shortcuts = preload("res://addons/debug_menu/settings/shortcuts.gd")

var playback: Playback
var _pause_button: Button
var _step_button: Button
var _speed_option: OptionButton


func _init() -> void:
	_pause_button = _make_button(PAUSE_ICON, "")
	_pause_button.pressed.connect(func() -> void: playback.toggle_pause())
	_step_button = _make_button(STEP_ICON, "")
	_step_button.pressed.connect(func() -> void: playback.step())
	_speed_option = OptionButton.new()
	_speed_option.focus_mode = Control.FOCUS_NONE
	_speed_option.flat = true
	for value in Playback.SPEEDS:
		_speed_option.add_item("x%s" % str(value))
	_speed_option.item_selected.connect(func(index: int) -> void: playback.speed = Playback.SPEEDS[index])
	add_child(_speed_option)


# Mis à jour à chaque frame : la pause peut venir d'ailleurs (menu du jeu, F10).
func _process(_delta: float) -> void:
	if playback == null:
		return
	var paused: bool = playback.is_paused()
	_pause_button.icon = PLAY_ICON if paused else PAUSE_ICON
	_pause_button.tooltip_text = (T.t("Resume") if paused else T.t("Pause")) + " (%s)" % Shortcuts.key_text(Shortcuts.PAUSE)
	_step_button.tooltip_text = T.t("Next frame (%s): pauses, then advances one frame") % Shortcuts.key_text(Shortcuts.STEP)
	var index: int = Playback.SPEEDS.find(playback.speed)
	if index != -1 and _speed_option.selected != index:
		_speed_option.select(index)
	_speed_option.tooltip_text = T.t("Game speed") if not playback.is_replaying() else T.t("Replay speed (x1 at most, to stay faithful)")


func _make_button(icon: Texture2D, tooltip: String) -> Button:
	var button: Button = Button.new()
	button.icon = icon
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.theme_type_variation = ThemeBuilder.BAR_BUTTON
	add_child(button)
	return button

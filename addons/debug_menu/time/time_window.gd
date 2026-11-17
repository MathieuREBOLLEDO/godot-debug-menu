extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Temps » : les réglages fins du temps. Pause, image +1 et
## préréglages de vitesse sont dans l'overlay (Core > Time > Time controls) ;
## tout passe par time/playback.gd.
## - vitesse au curseur (valeurs entre les préréglages) ;
## - lecture image par image : une image toutes les N secondes ;
## - compteur d'images physiques.

const Playback = preload("res://addons/debug_menu/time/playback.gd")
const TimeController = preload("res://addons/debug_menu/time/time_controller.gd")
const Shortcuts = preload("res://addons/debug_menu/settings/shortcuts.gd")

var _playback: Playback
var _time: TimeController
var _speed_slider: HSlider
var _auto_step_check: CheckBox


func _ready() -> void:
	if get_debug_menu() != null:
		_playback = get_debug_menu().get("playback")
		_time = get_debug_menu().get("time_controller")
	super()


func _process(delta: float) -> void:
	# La vitesse et la lecture peuvent changer depuis la barre.
	if _speed_slider != null:
		_speed_slider.set_value_no_signal(_playback.speed)
		_auto_step_check.set_pressed_no_signal(_time.auto_step)
	super(delta)


func _build() -> void:
	if _playback == null:
		add_note(T.t("DebugMenu not found: this window needs the addon to be active."))
		return
	add_status(_status_text)
	add_section(T.t("Speed"))
	_speed_slider = add_slider(_playback, &"speed", T.t("Speed"), 0.05, 4.0, 0.05, "", func(value: float) -> String: return "x%.2f" % value)
	add_hint(T.t("Presets, pause and next frame: top bar. While a recording is replayed, the speed is capped at x1."))

	add_section(T.t("Frame by frame playback"))
	_auto_step_check = add_check(T.t("Advance one frame every…"), func() -> bool: return _time.auto_step, func(on: bool) -> void: _time.auto_step = on)
	add_slider(_time, &"auto_step_delay", T.t("Delay"), 0.05, 2.0, 0.05, " s")
	add_hint(T.t("Key %s: pauses, then advances one frame on each press. Key %s: pause / resume.") % [Shortcuts.key_text(Shortcuts.STEP), Shortcuts.key_text(Shortcuts.PAUSE)])


func _status_text() -> String:
	var state: String = T.t("paused") if _playback.is_paused() else (T.t("frame by frame") if _time.auto_step else T.t("running"))
	return T.t("Physics frame %d · %s · x%.2f") % [Engine.get_physics_frames(), state, _playback.effective_speed()]

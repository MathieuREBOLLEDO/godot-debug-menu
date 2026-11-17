extends Button

## Bouton ● REC de la barre : démarre une prise d'actions (la scène est
## rechargée), l'arrête au second clic. Pendant un replay, il l'arrête.
## Affiche l'état : « REC 12 s » en rouge, « Replay 45 % ».

const InputRecorder = preload("res://addons/debug_menu/time/recording/input_recorder.gd")
const REC_ICON: Texture2D = preload("res://addons/debug_menu/icons/rec.svg")
const Tokens = preload("res://addons/debug_menu/settings/design_tokens.gd")
static var REC_COLOR: Color = Tokens.color("bad")
const T = preload("res://addons/debug_menu/i18n/t.gd")

var recorder: InputRecorder


func _init() -> void:
	icon = REC_ICON
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_on_pressed)


func _process(_delta: float) -> void:
	if recorder == null:
		return
	var recording: bool = recorder.state == InputRecorder.State.RECORDING or recorder.state == InputRecorder.State.STARTING
	match recorder.state:
		InputRecorder.State.RECORDING:
			text = T.t("REC %d s") % int(recorder.frame / float(Engine.physics_ticks_per_second))
		InputRecorder.State.REPLAYING:
			text = T.t("Replay %d %%") % int(recorder.get_progress() * 100.0)
		InputRecorder.State.STARTING:
			text = "…"
		_:
			text = "REC"
	tooltip_text = T.t("Stop") if recorder.state != InputRecorder.State.IDLE else T.t("Record the actions (reloads the scene; pausing stops the recording)")
	if recording:
		add_theme_color_override("icon_normal_color", REC_COLOR)
		add_theme_color_override("font_color", REC_COLOR)
	else:
		remove_theme_color_override("icon_normal_color")
		remove_theme_color_override("font_color")


func _on_pressed() -> void:
	if recorder.state == InputRecorder.State.IDLE:
		recorder.start_recording()
	else:
		recorder.stop()

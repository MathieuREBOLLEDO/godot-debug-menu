extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Enregistrements » : les prises (bouton REC de la barre) et leur
## lecture : Lire, Stop, Recommencer, progression et dérive. Pause, image +1
## et vitesse sont dans la barre du haut (time/playback.gd) : pendant un
## replay, la vitesse y devient un ralenti fidèle (x1 au plus).
## Le jeu recalcule tout pendant le replay : Physique, Inspecteur... restent
## utilisables.
## Morceaux : input_recorder.gd (prise et replay), recording_file.gd
## (fichiers), time/playback.gd (commandes).

const InputRecorder = preload("res://addons/debug_menu/time/recording/input_recorder.gd")
const RecordingFile = preload("res://addons/debug_menu/time/recording/recording_file.gd")
const Playback = preload("res://addons/debug_menu/time/playback.gd")

var _recorder: InputRecorder
var _playback: Playback
var _selected_path: String = ""
var _list: ItemList
var _progress: ProgressBar


func _ready() -> void:
	if get_debug_menu() != null:
		_recorder = get_debug_menu().get("input_recorder")
		_playback = get_debug_menu().get("playback")
		_recorder.recording_saved.connect(select)
	super()


func _process(delta: float) -> void:
	if _progress != null:
		_progress.value = _recorder.get_progress() if _recorder.state == InputRecorder.State.REPLAYING else 0.0
	super(delta)


## Rafraîchit la liste et sélectionne la prise [param path].
func select(path: String) -> void:
	_selected_path = path
	rebuild()


func _build() -> void:
	if _recorder == null:
		add_note(T.t("DebugMenu not found: this window needs the addon to be active."))
		return
	add_status(_status_text)
	_build_list()
	_build_player()


# --- Prises ---

func _build_list() -> void:
	add_section(T.t("Recordings"))
	add_hint(T.t("REC button of the bar: reloads the scene and records; a second click, pausing or closing the game stops the recording."))
	_list = ItemList.new()
	_list.custom_minimum_size.y = 130.0
	_list.focus_mode = Control.FOCUS_NONE
	_list.item_selected.connect(func(index: int) -> void: _selected_path = _list.get_item_metadata(index))
	_list.item_activated.connect(func(_index: int) -> void: _playback.play_recording(_selected_path))
	add_custom(_list, true)
	for path in RecordingFile.list():
		_list.add_item(_describe(path))
		_list.set_item_metadata(_list.item_count - 1, path)
		if path == _selected_path:
			_list.select(_list.item_count - 1)
	if _selected_path == "" and _list.item_count > 0:
		_list.select(0)
		_selected_path = _list.get_item_metadata(0)
	add_buttons("", [T.t("Refresh"), T.t("Delete")], func(index: int) -> void:
		if index == 1 and _selected_path != "":
			RecordingFile.delete(_selected_path)
			_selected_path = ""
		rebuild()
	)


func _describe(path: String) -> String:
	var data: Variant = RecordingFile.load_file(path)
	if data == null:
		return path.get_file() + " " + T.t("(unreadable)")
	var seconds: float = float(data["frames"]) / Engine.physics_ticks_per_second
	return "%s · %.1f s · %s" % [String(data["date"]).replace("T", " "), seconds, String(data["scene"]).get_file()]


# --- Lecture ---

func _build_player() -> void:
	add_section(T.t("Playback"))
	add_buttons("", [T.t("Play"), T.t("Stop"), T.t("Restart")], func(index: int) -> void:
		if index >= 1:
			_playback.stop_recording_playback()
		if index != 1:
			_playback.play_recording(_selected_path)
	)
	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	_progress.step = 0.001
	_progress.show_percentage = false
	add_custom(_progress)
	add_hint(T.t("Double-click a recording to play it. Pause, next frame and speed: top bar."))


func _status_text() -> String:
	var total: int = int(_recorder.data.get("frames", 0))
	match _recorder.state:
		InputRecorder.State.RECORDING:
			return T.t("Recording: frame %d") % _recorder.frame
		InputRecorder.State.STARTING:
			return T.t("Loading the scene…")
		InputRecorder.State.REPLAYING:
			var state_text: String = T.t("paused") if _playback.is_paused() else T.t("playing x%s") % str(_playback.effective_speed())
			return T.t("Frame %d / %d · %s · max drift %s") % [_recorder.frame, total, state_text, _drift_text()]
	if total > 0 and _recorder.max_drift_path != "":
		return T.t("Last replay finished · max drift %s") % _drift_text()
	return T.t("Choose a recording, then Play.")


func _drift_text() -> String:
	if _recorder.max_drift_path == "":
		return "0"
	return "%.2f (%s)" % [_recorder.max_drift, _recorder.max_drift_path]

extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Signals » : journal des signaux émis par l'objet sélectionné
## (barre de sélection en haut), depuis sa sélection : instant, image, nom et
## arguments. Filtre par texte, ou signaux du script seulement.
## L'écoute est faite par signal_log.gd ; elle s'arrête à la fermeture.

const SignalLog = preload("res://addons/debug_menu/objects/signals/signal_log.gd")

var _selection: Node # selection.gd
var _log: SignalLog = SignalLog.new()
var _start_time: float = 0.0
var _script_only: bool = false
var _filter: String = ""
var _shown_version: int = -1
var _scroll_frames: int = 0 # images restantes pour descendre en bas (la barre se met à jour au dessin)
var _list: ItemList


func _ready() -> void:
	if get_debug_menu() != null:
		_selection = get_debug_menu().get("selection")
		_selection.selection_changed.connect(_on_selection_changed)
		_watch(_selection.get_selected())
	super()


func _exit_tree() -> void:
	_log.stop()


func _process(delta: float) -> void:
	if _list != null and _shown_version != _log.version:
		_fill_list()
	if _list != null and _scroll_frames > 0:
		_scroll_frames -= 1
		_list.get_v_scroll_bar().value = _list.get_v_scroll_bar().max_value
	super(delta)


func _build() -> void:
	if _selection == null:
		add_note(T.t("DebugMenu not found: Signals needs the addon to be active."))
		return
	add_selection_bar()
	add_status(_status_text)
	_list = null
	if _selection.get_selected() == null:
		add_note(T.t("Choose an object: search, picker, or click in a list."))
		return
	add_check(T.t("Script signals only"), func() -> bool: return _script_only, func(on: bool) -> void:
		_script_only = on
		_fill_list()
	)
	var filter: LineEdit = add_text_field(T.t("Filter"), _filter, T.t("Signal name or value"), func(_text: String) -> void: pass)
	filter.text_changed.connect(func(text: String) -> void:
		_filter = text
		_fill_list()
	)
	add_button(T.t("Clear"), _log.clear)
	_list = ItemList.new()
	_list.focus_mode = Control.FOCUS_NONE
	_list.custom_minimum_size.y = 120.0
	add_custom(_list, true)
	_fill_list()


func _watch(object: Object) -> void:
	_log.watch(object)
	_start_time = Time.get_ticks_msec() / 1000.0


func _on_selection_changed(object: Object) -> void:
	_watch(object)
	rebuild()


# Lignes du journal qui passent le filtre, la plus récente en bas.
func _fill_list() -> void:
	_shown_version = _log.version
	if _list == null:
		return
	_list.clear()
	var filter: String = _filter.strip_edges().to_lower()
	for entry in _log.entries:
		if _script_only and not entry["is_script"]:
			continue
		if filter != "" and not String(entry["text"]).to_lower().contains(filter):
			continue
		_list.add_item("%7.2f s   #%d   %s" % [entry["time"] - _start_time, entry["frame"], entry["text"]])
	_scroll_frames = 2


func _status_text() -> String:
	if _selection == null or _selection.get_selected() == null:
		return ""
	var text: String = T.t("%d signal(s) watched · %d emission(s)") % [_log.get_watched_count(), _log.entries.size()]
	if not _log.get_skipped().is_empty():
		text += " · " + T.t("not watched (too many arguments): %s") % ", ".join(_log.get_skipped())
	return text

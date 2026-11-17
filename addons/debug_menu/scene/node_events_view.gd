extends VBoxContainer

## Événements des nœuds (node_recorder.gd), du plus ancien au plus récent :
## Temps | Événement | Ordre | Nom | Type | Chemin.
## Filtre par nom ou chemin, cases par type d'événement, « Suivre » pour
## rester sur les derniers événements. Clic = sélectionner le nœud,
## double-clic = Inspecteur, s'il existe encore (ui/node_actions.gd).

const NodeRecorder = preload("res://addons/debug_menu/scene/node_recorder.gd")
const NodeActions = preload("res://addons/debug_menu/ui/node_actions.gd")
const T = preload("res://addons/debug_menu/i18n/t.gd")
const MAX_ROWS: int = 500 # les plus récents parmi ceux qui passent le filtre
const Tokens = preload("res://addons/debug_menu/settings/design_tokens.gd")
static var KIND_COLORS: Array[Color] = [Tokens.color("sand_dim"), Tokens.color("good"), Tokens.color("info"), Tokens.color("bad")]

var recorder: NodeRecorder
var _filter_edit: LineEdit
var _kind_checks: Array[CheckBox] = []
var _follow_check: CheckBox
var _list: Tree
var _built_revision: int = -1


func _init() -> void:
	var filter_row: HBoxContainer = HBoxContainer.new()
	add_child(filter_row)
	_filter_edit = LineEdit.new()
	_filter_edit.placeholder_text = T.t("Filter by name or path")
	_filter_edit.clear_button_enabled = true
	_filter_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter_edit.text_changed.connect(func(_text: String) -> void: _rebuild())
	filter_row.add_child(_filter_edit)
	for kind in NodeRecorder.KIND_NAMES.size():
		var check: CheckBox = CheckBox.new()
		check.text = T.t(NodeRecorder.KIND_NAMES[kind])
		check.button_pressed = kind != NodeRecorder.Kind.PRESENT
		check.focus_mode = Control.FOCUS_NONE
		check.toggled.connect(func(_on: bool) -> void: _rebuild())
		filter_row.add_child(check)
		_kind_checks.append(check)
	_follow_check = CheckBox.new()
	_follow_check.text = T.t("Follow")
	_follow_check.tooltip_text = T.t("Always show the latest events")
	_follow_check.button_pressed = true
	_follow_check.focus_mode = Control.FOCUS_NONE
	filter_row.add_child(_follow_check)

	_list = Tree.new()
	_list.columns = 6
	_list.column_titles_visible = true
	_list.hide_root = true
	_list.select_mode = Tree.SELECT_ROW
	_list.focus_mode = Control.FOCUS_NONE
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var titles: Array[String] = ["Time", "Event", "Order", "Name", "Type", "Path"]
	var ratios: Array[int] = [1, 1, 1, 2, 2, 4]
	for column in titles.size():
		_list.set_column_title(column, T.t(titles[column]))
		_list.set_column_expand_ratio(column, ratios[column])
	_list.item_selected.connect(func() -> void: NodeActions.select(get_tree(), _selected_node()))
	_list.item_activated.connect(func() -> void: NodeActions.inspect(get_tree(), _selected_node()))
	add_child(_list)


## Reconstruit si de nouveaux événements sont arrivés.
func refresh() -> void:
	if recorder != null and recorder.revision != _built_revision:
		_rebuild()


func _rebuild() -> void:
	if recorder == null:
		return
	_built_revision = recorder.revision
	_list.clear()
	var root: TreeItem = _list.create_item()
	var rows: Array[Dictionary] = _matching_events()
	for event in rows:
		_add_row(root, event)
	if _follow_check.button_pressed and root.get_child_count() > 0:
		_list.scroll_to_item(root.get_child(root.get_child_count() - 1))


func _matching_events() -> Array[Dictionary]:
	var needle: String = _filter_edit.text.to_lower()
	var rows: Array[Dictionary] = []
	for index in range(recorder.events.size() - 1, -1, -1):
		var event: Dictionary = recorder.events[index]
		if not _kind_checks[event["kind"]].button_pressed:
			continue
		if needle != "" and String(event["name"]).to_lower().find(needle) == -1 and String(event["path"]).to_lower().find(needle) == -1:
			continue
		rows.append(event)
		if rows.size() >= MAX_ROWS:
			break
	rows.reverse()
	return rows


func _add_row(root: TreeItem, event: Dictionary) -> void:
	var item: TreeItem = _list.create_item(root)
	var kind: int = event["kind"]
	item.set_text(0, "%.2f s" % event["time"])
	item.set_text(1, T.t(NodeRecorder.KIND_NAMES[kind]))
	item.set_custom_color(1, KIND_COLORS[kind])
	item.set_text(2, str(event["order"]) if event["order"] >= 0 else "")
	item.set_text(3, event["name"])
	item.set_text(4, event["class"])
	item.set_text(5, event["path"])
	item.set_tooltip_text(5, event["path"])
	item.set_metadata(0, event["id"])


func _selected_node() -> Object:
	var item: TreeItem = _list.get_selected()
	return null if item == null else instance_from_id(item.get_metadata(0))

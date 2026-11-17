extends Window

## Base de toutes les fenêtres du debug menu (et de celles du jeu).
## Une fenêtre l'étend :
##     extends "res://addons/debug_menu/ui/debug_window.gd"
## et redéfinit _build() avec des add_...() (voir les sections plus bas).
## Mise en page commune :
##   haut fixe     barre de sélection (add_selection_bar), si la fenêtre en a une
##   contenu       les lignes de _build(), qui défilent
##   bas fixe      ligne d'état grise (add_status), si la fenêtre en a une
## L'apparence vient du thème du debug menu (réglable dans les Paramètres).
## Si la fenêtre redéfinit _ready() ou _process(), elle doit appeler super().

const ThemeBuilder = preload("res://addons/debug_menu/settings/debug_menu_theme.gd")
const ValueFormat = preload("res://addons/debug_menu/ui/value_format.gd")
const NodeList = preload("res://addons/debug_menu/ui/node_list.gd")
const SelectionBar = preload("res://addons/debug_menu/ui/selection_bar.gd")
const PropertyFields = preload("res://addons/debug_menu/ui/property_fields.gd")
## Traduction : T.t("English text") (voir i18n/t.gd), héritée par les fenêtres.
const T = preload("res://addons/debug_menu/i18n/t.gd")
const LABEL_WIDTH: float = 150.0 # colonne des libellés, pour aligner les champs
const SPIN_BOX_WIDTH: float = 110.0
const MARGIN: int = 8
const HINT_POPUP_WIDTH: float = 260.0 # largeur de la note d'add_hint() au survol
const DEBUG_MENU_PATH: NodePath = ^"/root/DebugMenu"

var _top: VBoxContainer # haut fixe
var _rows: VBoxContainer # contenu qui défile
var _status: Label # bas fixe
var _status_getter: Callable
var _selection_bar: SelectionBar = null
var _tabs: TabBar = null # barre d'onglets d'add_tabs(), dans le haut fixe
var _tabs_changed: Callable
var _live_labels: Array[Dictionary] = [] # {label, getter}
var _hint_popup: PanelContainer = null # note d'add_hint() au survol
var _hint_popup_label: Label


func _ready() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	margin.add_child(column)
	_top = VBoxContainer.new()
	column.add_child(_top)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Remplit la hauteur : un contrôle ajouté avec add_custom(..., true) prend
	# la place restante.
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	_status = Label.new()
	_status.theme_type_variation = ThemeBuilder.PANEL_NOTE
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.visible = false
	column.add_child(_status)
	_build()


func _process(_delta: float) -> void:
	for live in _live_labels:
		var label: Label = live["label"]
		var getter: Callable = live["getter"]
		label.text = getter.call()
	if _status_getter.is_valid():
		_status.text = _status_getter.call()


## À redéfinir : ajoute les lignes de la fenêtre.
func _build() -> void:
	pass


## Vide le contenu et rappelle _build() (après un changement de structure).
## Le haut et le bas fixes sont gardés.
func rebuild() -> void:
	_hide_hint_popup()
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_live_labels.clear()
	_build()


## L'autoload DebugMenu (sélection, temps...), ou null si l'addon est inactif.
func get_debug_menu() -> Node:
	return get_tree().root.get_node_or_null(DEBUG_MENU_PATH)


# --- Haut et bas fixes ---

## Barre de sélection en haut de la fenêtre (une seule, même si _build() est
## rappelé) : [←] [recherche] [pipette] objet sélectionné.
func add_selection_bar() -> SelectionBar:
	if _selection_bar == null:
		_selection_bar = SelectionBar.new()
		_top.add_child(_selection_bar)
	return _selection_bar


## Ligne d'état grise en bas de la fenêtre, recalculée à chaque frame par
## [param getter] () -> String.
func add_status(getter: Callable) -> void:
	_status_getter = getter
	_status.visible = true


# --- Textes ---

## Titre de section : surtitre étroit en capitales, couleur d'accent.
func add_section(title: String) -> Label:
	var label: Label = _add_text(title, ThemeBuilder.PANEL_SECTION)
	label.uppercase = true
	return label


func add_label(text: String) -> Label:
	return _add_text(text, "")


## Texte discret toujours affiché : pour un état ou un message (« aucun objet
## choisi »...). Pour expliquer un champ, préférer add_hint().
func add_note(text: String) -> Label:
	return _add_text(text, ThemeBuilder.PANEL_NOTE)


## Explication de la ligne précédente, rangée dans une bulle : un petit « ? »
## juste à droite du nom (libellé, case, section), sinon au bout de la ligne.
## Survol du « ? » ou du nom : la note s'ouvre dans une fenêtre au-dessus ;
## clic sur le « ? » : elle s'affiche sous la ligne (re-clic : masquée).
## Plusieurs add_hint() de suite sur la même ligne s'ajoutent à la même note.
## Sans ligne précédente, le texte reste affiché (add_note).
func add_hint(text: String) -> void:
	if _rows.get_child_count() == 0:
		add_note(text)
		return
	var last: Node = _rows.get_child(_rows.get_child_count() - 1)
	# Juste après un add_hint() : le dernier enfant est son texte caché.
	var row: HBoxContainer = last.get_meta(&"hint_row") if last.has_meta(&"hint_row") else _hint_row(last)
	var full_text: String = text
	if not row.has_meta(&"hint_button"):
		var button: Button = Button.new()
		button.text = "?"
		button.theme_type_variation = ThemeBuilder.HINT_BUTTON
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_HELP
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_place_hint_button(row, button)
		row.set_meta(&"hint_button", button)
		var detail: Label = Label.new()
		detail.theme_type_variation = ThemeBuilder.PANEL_NOTE
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.visible = false
		detail.set_meta(&"hint_row", row)
		_rows.add_child(detail)
		_rows.move_child(detail, row.get_index() + 1)
		row.set_meta(&"hint_detail", detail)
		button.pressed.connect(func() -> void:
			detail.visible = not detail.visible
			_hide_hint_popup())
		var hovered: Array[Control] = [button]
		if row.has_meta(&"hint_word"):
			hovered.append(row.get_meta(&"hint_word"))
		for control: Control in hovered:
			control.mouse_entered.connect(_show_hint_popup.bind(row))
			control.mouse_exited.connect(_hide_hint_popup)
			if control is Label:
				control.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		full_text = String(row.get_meta(&"hint_text")) + "\n" + text
	row.set_meta(&"hint_text", full_text)
	(row.get_meta(&"hint_detail") as Label).text = full_text

## Texte recalculé à chaque frame par [param getter] () -> String.
func add_live_label(getter: Callable) -> Label:
	var label: Label = _add_text("", ThemeBuilder.PANEL_NOTE)
	_live_labels.append({"label": label, "getter": getter})
	return label


## Valeur de target.property affichée en direct, en lecture seule.
func add_value(target: Object, property: StringName, text: String) -> Label:
	var row: HBoxContainer = _add_row(text)
	var value_label: Label = Label.new()
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.clip_text = true
	row.add_child(value_label)
	_live_labels.append({"label": value_label, "getter": func() -> String: return ValueFormat.text(target.get(property))})
	return value_label


# --- Champs liés à une propriété ---

## Curseur et champ numérique liés à target.property.
## [param extra_text] (value: float) -> String : texte affiché à droite
## (par exemple une conversion d'unité), mis à jour avec la valeur.
func add_slider(target: Object, property: StringName, text: String, min_value: float, max_value: float, step: float, unit: String = "", extra_text: Callable = Callable()) -> HSlider:
	var row: HBoxContainer = _add_row(text)
	var slider: HSlider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = target.get(property)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.x = 100.0
	# Pas de focus clavier : les touches doivent aller au jeu, pas au curseur.
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)

	var spin_box: SpinBox = SpinBox.new()
	# Le champ adopte la plage et la valeur du curseur, puis les deux restent liés.
	slider.share(spin_box)
	spin_box.suffix = unit
	spin_box.custom_minimum_size.x = SPIN_BOX_WIDTH
	row.add_child(spin_box)

	var extra_label: Label = null
	if extra_text.is_valid():
		extra_label = Label.new()
		extra_label.custom_minimum_size.x = 50.0
		extra_label.text = extra_text.call(slider.value)
		row.add_child(extra_label)

	slider.value_changed.connect(func(value: float) -> void:
		target.set(property, value)
		if extra_label != null:
			extra_label.text = extra_text.call(value)
	)
	return slider


## Case à cocher liée à target.property.
func add_property_check(target: Object, property: StringName, text: String) -> CheckBox:
	return add_check(text, func() -> bool: return target.get(property), func(value: bool) -> void: target.set(property, value))


## Case à cocher avec lecture ([param getter] () -> bool) et écriture
## ([param setter] (value: bool)) personnalisées.
func add_check(text: String, getter: Callable, setter: Callable) -> CheckBox:
	var check_box: CheckBox = CheckBox.new()
	check_box.text = text
	check_box.button_pressed = getter.call()
	check_box.focus_mode = Control.FOCUS_NONE
	check_box.toggled.connect(setter)
	_rows.add_child(check_box)
	return check_box


func add_button(text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	_rows.add_child(button)
	return button


## Rangée de boutons côte à côte. [param on_pressed] (index: int) reçoit
## l'indice du bouton dans [param labels].
func add_buttons(text: String, labels: Array, on_pressed: Callable) -> HBoxContainer:
	var row: HBoxContainer = _add_row(text)
	for index in labels.size():
		var button: Button = Button.new()
		button.text = str(labels[index])
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(on_pressed.bind(index))
		row.add_child(button)
	return row


## Choix d'une couleur. [param on_changed] (color: Color) à chaque changement.
func add_color(text: String, value: Color, edit_alpha: bool, on_changed: Callable) -> ColorPickerButton:
	var row: HBoxContainer = _add_row(text)
	var picker: ColorPickerButton = ColorPickerButton.new()
	picker.color = value
	picker.edit_alpha = edit_alpha
	picker.custom_minimum_size.y = 28.0
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.focus_mode = Control.FOCUS_NONE
	picker.color_changed.connect(on_changed)
	row.add_child(picker)
	return picker


## Champ numérique seul. [param on_changed] (value: float) à chaque changement.
func add_spin(text: String, value: float, min_value: float, max_value: float, step: float, on_changed: Callable) -> SpinBox:
	var row: HBoxContainer = _add_row(text)
	var spin_box: SpinBox = SpinBox.new()
	spin_box.min_value = min_value
	spin_box.max_value = max_value
	spin_box.step = step
	spin_box.value = value
	spin_box.custom_minimum_size.x = SPIN_BOX_WIDTH
	spin_box.value_changed.connect(on_changed)
	row.add_child(spin_box)
	return spin_box


## Champ de texte. [param on_submitted] (text: String) quand on valide
## avec Entrée.
func add_text_field(text: String, value: String, placeholder: String, on_submitted: Callable) -> LineEdit:
	var row: HBoxContainer = _add_row(text)
	var line_edit: LineEdit = LineEdit.new()
	line_edit.text = value
	line_edit.placeholder_text = placeholder
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.text_submitted.connect(on_submitted)
	row.add_child(line_edit)
	return line_edit


## Liste déroulante. [param on_selected] (index: int) à chaque choix.
func add_option(text: String, options: Array, selected: int, on_selected: Callable) -> OptionButton:
	var row: HBoxContainer = _add_row(text)
	var option: OptionButton = OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.focus_mode = Control.FOCUS_NONE
	for option_text in options:
		option.add_item(str(option_text))
	option.select(selected)
	option.item_selected.connect(on_selected)
	row.add_child(option)
	return option


## Liste de nœuds remise à jour toute seule (ui/node_list.gd) :
## clic = sélectionner, double-clic = Inspecteur.
## [param getter] () -> Array de nœuds.
func add_node_list(getter: Callable, height: float = 110.0) -> ItemList:
	var list: NodeList = NodeList.new()
	list.getter = getter
	list.custom_minimum_size.y = height
	_rows.add_child(list)
	return list


## Onglets, dans le haut fixe de la fenêtre : ils restent visibles quand le
## contenu défile. [param on_changed] (index: int) quand on change d'onglet ;
## en général la fenêtre retient l'onglet puis appelle rebuild(). Une seule
## barre d'onglets : rappelé par rebuild(), add_tabs() la met à jour.
func add_tabs(titles: Array, current: int, on_changed: Callable) -> TabBar:
	if _tabs == null:
		_tabs = TabBar.new()
		_tabs.focus_mode = Control.FOCUS_NONE
		_top.add_child(_tabs)
	# Mise à jour sans émettre tab_changed (sinon rebuild() en boucle).
	if _tabs_changed.is_valid() and _tabs.tab_changed.is_connected(_tabs_changed):
		_tabs.tab_changed.disconnect(_tabs_changed)
	_tabs.clear_tabs()
	for title in titles:
		_tabs.add_tab(str(title))
	_tabs.current_tab = current
	_tabs_changed = on_changed
	_tabs.tab_changed.connect(on_changed)
	return _tabs


## Ajoute un contrôle fait à la main (tableau, graphe...). Avec
## [param fill], il prend toute la hauteur restante de la fenêtre.
func add_custom(control: Control, fill: bool = false) -> Control:
	if fill:
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.add_child(control)
	return control


## Un champ par variable exportée (@export) de [param target] : voir
## ui/property_fields.gd. [param only_group] limite à un @export_group.
func add_properties(target: Object, only_group: String = "") -> void:
	PropertyFields.build(self, target, only_group)


# --- Mise en page ---

# Ligne qui reçoit le « ? » d'add_hint() : [param control] s'il est déjà une
# ligne (HBoxContainer), sinon une ligne créée à sa place qui le contient.
# Une case à cocher ou un titre de section garde sa largeur (le « ? » se
# colle à son texte) ; un autre contrôle prend la ligne.
func _hint_row(control: Node) -> HBoxContainer:
	if control is HBoxContainer:
		return control
	var target: Control = control as Control
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_vertical = target.size_flags_vertical
	var index: int = target.get_index()
	_rows.remove_child(target)
	var word: bool = target is CheckBox or (target is Label and (target as Label).theme_type_variation == ThemeBuilder.PANEL_SECTION)
	if word:
		if target is Label:
			(target as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
		row.set_meta(&"hint_word", target)
	else:
		target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(target)
	_rows.add_child(row)
	_rows.move_child(row, index)
	return row


# Place le « ? » : collé au libellé de la ligne s'il y en a un (colonne des
# libellés : le libellé et le « ? » y tiennent ensemble), collé au nom d'une
# case ou d'une section, sinon au bout de la ligne.
func _place_hint_button(row: HBoxContainer, button: Button) -> void:
	var first: Control = row.get_child(0) as Control if row.get_child_count() > 0 else null
	if first is Label and is_equal_approx(first.custom_minimum_size.x, LABEL_WIDTH):
		var cell: HBoxContainer = HBoxContainer.new()
		cell.custom_minimum_size.x = LABEL_WIDTH
		cell.add_theme_constant_override(&"separation", 0)
		row.remove_child(first)
		first.custom_minimum_size.x = 0.0
		cell.add_child(first)
		cell.add_child(button)
		row.add_child(cell)
		row.move_child(cell, 0)
		row.set_meta(&"hint_word", first)
	elif row.has_meta(&"hint_word"):
		row.add_child(button)
		row.move_child(button, (row.get_meta(&"hint_word") as Node).get_index() + 1)
		var spacer: Control = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer)
	else:
		row.add_child(button)


# Note de la ligne dans une petite fenêtre au-dessus du « ? » (en dessous s'il
# n'y a pas la place), tant que la note n'est pas dépliée sous la ligne.
func _show_hint_popup(row: HBoxContainer) -> void:
	if (row.get_meta(&"hint_detail") as Label).visible:
		return
	if _hint_popup == null:
		_hint_popup = PanelContainer.new()
		_hint_popup.theme_type_variation = ThemeBuilder.HINT_POPUP
		_hint_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint_popup_label = Label.new()
		_hint_popup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_hint_popup_label.custom_minimum_size.x = HINT_POPUP_WIDTH
		_hint_popup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint_popup.add_child(_hint_popup_label)
		add_child(_hint_popup)
	_hint_popup_label.text = row.get_meta(&"hint_text")
	_hint_popup.reset_size()
	var popup_size: Vector2 = _hint_popup.get_combined_minimum_size()
	var anchor: Control = row.get_meta(&"hint_button")
	var at: Vector2 = anchor.global_position + Vector2(-12.0, -popup_size.y - 4.0)
	if at.y < 0.0:
		at.y = anchor.global_position.y + anchor.size.y + 4.0
	at.x = clampf(at.x, 4.0, maxf(float(size.x) - popup_size.x - 4.0, 4.0))
	_hint_popup.position = at
	_hint_popup.size = popup_size
	move_child(_hint_popup, -1)
	_hint_popup.visible = true


func _hide_hint_popup() -> void:
	if _hint_popup != null:
		_hint_popup.visible = false

func _add_text(text: String, type_variation: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = type_variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(label)
	return label


# Ligne « libellé + champ(s) », le libellé dans une colonne de largeur fixe
# (pas de libellé si [param text] est vide).
func _add_row(text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	_rows.add_child(row)
	if text == "":
		return row
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size.x = LABEL_WIDTH
	row.add_child(label)
	return row

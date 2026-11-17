extends RefCounted

## Construit le thème de la barre et des fenêtres : jetons de design
## (design_tokens.gd, règles dans DESIGN.md) et réglages de l'utilisateur
## (accent, fond, taille, police : settings_store.gd).
## Le même Theme est modifié sur place : tout ce qui l'utilise se met à jour.
## Une fonction par zone : barre, menus déroulants, fenêtres, champs, listes.

const Tokens = preload("res://addons/debug_menu/settings/design_tokens.gd")
const BAR_BUTTON: String = "DebugBarButton" # boutons plats de la barre et des fenêtres
# Noms repris dans windows/window_frame.gd :
const WINDOW_PANEL: String = "DebugWindowPanel"
const WINDOW_PANEL_FOCUSED: String = "DebugWindowPanelFocused"
const WINDOW_TITLE: String = "DebugWindowTitle"
# Noms repris dans ui/debug_window.gd :
const PANEL_SECTION: String = "DebugPanelSection"
const PANEL_NOTE: String = "DebugPanelNote"
const HINT_BUTTON: String = "DebugHintButton"
const HINT_POPUP: String = "DebugHintPopup"
const T = preload("res://addons/debug_menu/i18n/t.gd")


## [param values] : réglages de settings_store.gd.
static func apply(theme: Theme, values: Dictionary) -> void:
	var background: Color = values["background_color"]
	var base_font: Font = _load_font(values["font_path"])
	var from_tokens: bool = values["font_path"] == Tokens.FONT_FROM_TOKENS
	# Couleurs et polices partagées par toutes les zones : jetons, sauf
	# l'accent et le fond, réglables par l'utilisateur.
	var palette: Dictionary = {
		"accent": values["accent_color"],
		"background": background,
		"deep": Tokens.color("ink"),
		"raised": Tokens.color("ink_raised"),
		"line": Tokens.color("ink_line"),
		"text": Tokens.color("sand"),
		"muted": Tokens.color("sand_dim"),
		"bad": Tokens.color("bad"),
		"radius": Tokens.size("radius"),
		"regular": base_font if from_tokens else _weight(base_font, 500),
		"bold": Tokens.font(&"condensed") if from_tokens else _weight(base_font, 700),
		"mono": Tokens.font(&"mono"),
		"font_size": values["font_size"],
	}

	theme.set_block_signals(true)
	theme.clear()
	theme.default_font = palette["regular"]
	theme.default_font_size = palette["font_size"]
	_apply_bar(theme, palette)
	_apply_popup_menus(theme, palette)
	_apply_windows(theme, palette)
	_apply_fields(theme, palette)
	_apply_lists(theme, palette)
	theme.set_block_signals(false)
	theme.emit_changed()


# Barre, ses menus et les boutons plats (⚙, étoile, épingle, croix) : texte
# estompé ; au survol, texte dans l'accent et filet d'accent dessous.
static func _apply_bar(theme: Theme, palette: Dictionary) -> void:
	var accent: Color = palette["accent"]
	var bar: StyleBoxFlat = _box(palette["background"], 6, 3)
	bar.border_color = palette["line"]
	bar.border_width_bottom = 1
	theme.set_stylebox("panel", "PanelContainer", bar)
	var underline: StyleBoxFlat = _box(Color(palette["raised"], 0.6), 12, 5, palette["radius"])
	underline.border_color = accent
	underline.border_width_bottom = 2
	for type_name in ["MenuButton", BAR_BUTTON]:
		theme.set_font("font", type_name, palette["bold"])
		theme.set_stylebox("normal", type_name, _box(Color(0, 0, 0, 0), 12, 5))
		theme.set_stylebox("hover", type_name, underline)
		theme.set_stylebox("pressed", type_name, underline)
		theme.set_stylebox("hover_pressed", type_name, underline)
		theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())
		theme.set_stylebox("disabled", type_name, _box(Color(0, 0, 0, 0), 12, 5))
		theme.set_color("font_color", type_name, palette["muted"])
		theme.set_color("font_disabled_color", type_name, Color(palette["muted"], 0.3))
		theme.set_color("icon_disabled_color", type_name, Color(palette["muted"], 0.3))
		theme.set_color("font_hover_color", type_name, accent)
		theme.set_color("font_pressed_color", type_name, accent)
		theme.set_color("font_hover_pressed_color", type_name, accent)
		# Les icônes SVG sont blanches : le thème les colore comme le texte.
		theme.set_color("icon_normal_color", type_name, palette["muted"])
		theme.set_color("icon_hover_color", type_name, accent)
		theme.set_color("icon_pressed_color", type_name, accent)
		theme.set_color("icon_hover_pressed_color", type_name, accent)
		theme.set_color("icon_focus_color", type_name, palette["muted"])
	theme.set_type_variation(BAR_BUTTON, "Button")


# Menus déroulants : panneau encre cerné d'un filet ; l'entrée survolée a un
# trait d'accent à gauche.
static func _apply_popup_menus(theme: Theme, palette: Dictionary) -> void:
	var popup_panel: StyleBoxFlat = _box(Color(palette["background"], 0.98), 4, 4, palette["radius"])
	popup_panel.border_color = palette["line"]
	popup_panel.set_border_width_all(1)
	theme.set_stylebox("panel", "PopupMenu", popup_panel)
	var hover: StyleBoxFlat = _box(palette["raised"], 8, 4, 2)
	hover.border_color = palette["accent"]
	hover.border_width_left = 2
	theme.set_stylebox("hover", "PopupMenu", hover)
	var separator: StyleBoxLine = StyleBoxLine.new()
	separator.color = palette["line"]
	separator.thickness = 1
	theme.set_stylebox("separator", "PopupMenu", separator)
	theme.set_color("font_color", "PopupMenu", palette["text"])
	theme.set_color("font_hover_color", "PopupMenu", palette["accent"])
	theme.set_color("font_disabled_color", "PopupMenu", palette["muted"])
	theme.set_color("font_accelerator_color", "PopupMenu", palette["muted"])
	theme.set_constant("v_separation", "PopupMenu", 10)
	theme.set_constant("item_start_padding", "PopupMenu", 10)
	theme.set_constant("item_end_padding", "PopupMenu", 10)

	var tooltip: StyleBoxFlat = _box(palette["raised"], 8, 5, palette["radius"])
	tooltip.border_color = palette["line"]
	tooltip.set_border_width_all(1)
	theme.set_stylebox("panel", "TooltipPanel", tooltip)
	theme.set_color("font_color", "TooltipLabel", palette["text"])


# Cadre des fenêtres (window_frame.gd) : panneau encre et filet ; filet
# d'accent en haut quand la fenêtre a le focus. Titre étroit, en sable.
static func _apply_windows(theme: Theme, palette: Dictionary) -> void:
	for type_name in [WINDOW_PANEL, WINDOW_PANEL_FOCUSED]:
		var window_panel: StyleBoxFlat = _box(palette["background"], 0, 0, palette["radius"] + 2)
		window_panel.border_color = palette["line"]
		window_panel.set_border_width_all(1)
		if type_name == WINDOW_PANEL_FOCUSED:
			window_panel.border_color = Color(palette["accent"], 0.55)
			window_panel.border_width_top = 2
		theme.set_stylebox("panel", type_name, window_panel)
		theme.set_type_variation(type_name, "Panel")
	theme.set_font("font", WINDOW_TITLE, palette["bold"])
	theme.set_font_size("font_size", WINDOW_TITLE, palette["font_size"] + 1)
	theme.set_color("font_color", WINDOW_TITLE, palette["text"])
	theme.set_type_variation(WINDOW_TITLE, "Label")


# Contenu des fenêtres : textes, boutons, cases, curseurs, champs, onglets.
static func _apply_fields(theme: Theme, palette: Dictionary) -> void:
	var accent: Color = palette["accent"]
	var radius: int = palette["radius"]
	theme.set_color("font_color", "Label", palette["text"])
	# Section : surtitre étroit dans l'accent (le texte est mis en capitales
	# par debug_window.gd).
	theme.set_font("font", PANEL_SECTION, palette["bold"])
	theme.set_font_size("font_size", PANEL_SECTION, palette["font_size"] - 2)
	theme.set_color("font_color", PANEL_SECTION, accent)
	theme.set_type_variation(PANEL_SECTION, "Label")
	theme.set_color("font_color", PANEL_NOTE, palette["muted"])
	theme.set_font_size("font_size", PANEL_NOTE, palette["font_size"] - 2)
	theme.set_type_variation(PANEL_NOTE, "Label")

	# Boutons : relief encre cerné d'un filet ; accent au survol.
	theme.set_stylebox("normal", "Button", _framed(palette["raised"], palette["line"], 10, 4, radius))
	theme.set_stylebox("hover", "Button", _framed(palette["raised"].lightened(0.05), accent, 10, 4, radius))
	theme.set_stylebox("pressed", "Button", _framed(palette["deep"], accent, 10, 4, radius))
	theme.set_stylebox("hover_pressed", "Button", _framed(palette["deep"], accent, 10, 4, radius))
	theme.set_stylebox("disabled", "Button", _framed(Color(palette["raised"], 0.4), Color(palette["line"], 0.4), 10, 4, radius))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", palette["text"])
	theme.set_color("font_hover_color", "Button", accent)
	theme.set_color("font_pressed_color", "Button", accent)
	theme.set_color("font_hover_pressed_color", "Button", accent)
	theme.set_color("font_disabled_color", "Button", palette["muted"])
	# Cases à cocher : sans cadre (sinon elles prendraient celui des boutons),
	# un léger relief au survol.
	for type_name in ["CheckBox", "CheckButton"]:
		for state in ["normal", "pressed", "disabled", "focus"]:
			theme.set_stylebox(state, type_name, _box(Color(0, 0, 0, 0), 4, 2))
		theme.set_stylebox("hover", type_name, _box(Color(palette["raised"], 0.6), 4, 2, radius))
		theme.set_stylebox("hover_pressed", type_name, _box(Color(palette["raised"], 0.6), 4, 2, radius))
		theme.set_color("font_color", type_name, palette["text"])
		theme.set_icon("unchecked", type_name, _check_icon(palette["muted"], Color(0, 0, 0, 0), false))
		theme.set_icon("checked", type_name, _check_icon(accent, accent, true))
		theme.set_icon("unchecked_disabled", type_name, _check_icon(Color(palette["muted"], 0.4), Color(0, 0, 0, 0), false))
		theme.set_icon("checked_disabled", type_name, _check_icon(Color(accent, 0.4), Color(accent, 0.4), true))
		theme.set_color("font_hover_color", type_name, accent)
		theme.set_color("font_pressed_color", type_name, palette["text"])
		theme.set_color("font_hover_pressed_color", type_name, accent)

	# Bulle « ? » d'add_hint() : discrète, accent au survol.
	theme.set_type_variation(HINT_BUTTON, "Button")
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		theme.set_stylebox(state, HINT_BUTTON, _box(Color(0, 0, 0, 0), 4, 0))
	theme.set_font("font", HINT_BUTTON, palette["bold"])
	theme.set_color("font_color", HINT_BUTTON, palette["muted"])
	theme.set_color("font_hover_color", HINT_BUTTON, accent)
	theme.set_color("font_pressed_color", HINT_BUTTON, accent)
	theme.set_color("font_hover_pressed_color", HINT_BUTTON, accent)

	# Note d'add_hint() au survol : petite fenêtre en relief, cernée d'accent
	# (trait plus épais à gauche), ombre portée.
	var popup: StyleBoxFlat = _framed(palette["raised"], Color(accent, 0.55), 10, 7, radius)
	popup.border_width_left = 3
	popup.shadow_color = Color(0, 0, 0, 0.45)
	popup.shadow_size = 6
	theme.set_type_variation(HINT_POPUP, "PanelContainer")
	theme.set_stylebox("panel", HINT_POPUP, popup)

	var track: StyleBoxFlat = _framed(palette["deep"], palette["line"], 0, 3, 3)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", _box(accent.darkened(0.25), 0, 3, 3))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(accent, 0, 3, 3))

	theme.set_stylebox("normal", "LineEdit", _framed(palette["deep"], palette["line"], 6, 3, radius))
	theme.set_stylebox("read_only", "LineEdit", _framed(Color(palette["deep"], 0.5), palette["line"], 6, 3, radius))
	theme.set_stylebox("focus", "LineEdit", _framed(Color(0, 0, 0, 0), accent, 6, 3, radius))
	theme.set_font("font", "LineEdit", palette["mono"])
	theme.set_color("font_color", "LineEdit", palette["text"])
	theme.set_color("font_placeholder_color", "LineEdit", palette["muted"])
	theme.set_color("caret_color", "LineEdit", accent)
	theme.set_color("selection_color", "LineEdit", Color(accent, 0.35))

	# Onglets (fixés en haut des fenêtres) : l'onglet choisi est souligné
	# dans l'accent, les autres estompés.
	var tab_selected: StyleBoxFlat = _box(Color(0, 0, 0, 0), 12, 5)
	tab_selected.border_color = accent
	tab_selected.border_width_bottom = 2
	var tab_idle: StyleBoxFlat = _box(Color(0, 0, 0, 0), 12, 5)
	tab_idle.border_color = palette["line"]
	tab_idle.border_width_bottom = 1
	theme.set_stylebox("tab_selected", "TabBar", tab_selected)
	theme.set_stylebox("tab_unselected", "TabBar", tab_idle)
	theme.set_stylebox("tab_hovered", "TabBar", tab_idle)
	theme.set_stylebox("tab_focus", "TabBar", StyleBoxEmpty.new())
	theme.set_font("font", "TabBar", palette["bold"])
	theme.set_color("font_selected_color", "TabBar", palette["text"])
	theme.set_color("font_unselected_color", "TabBar", palette["muted"])
	theme.set_color("font_hovered_color", "TabBar", accent)

	var grabber: StyleBoxFlat = _box(Color(palette["line"], 0.8), 0, 0, 3)
	for type_name in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type_name, _box(Color(0, 0, 0, 0), 3, 3))
		theme.set_stylebox("grabber", type_name, grabber)
		theme.set_stylebox("grabber_highlight", type_name, _box(palette["muted"], 0, 0, 3))
		theme.set_stylebox("grabber_pressed", type_name, _box(accent, 0, 0, 3))


# Listes et arbres (scène, nœuds, console...) : creusés dans l'encre ; la
# ligne choisie a un trait d'accent à gauche.
static func _apply_lists(theme: Theme, palette: Dictionary) -> void:
	var accent: Color = palette["accent"]
	var selected: StyleBoxFlat = _box(palette["raised"], 4, 2, 2)
	selected.border_color = accent
	selected.border_width_left = 2
	for type_name in ["ItemList", "Tree"]:
		theme.set_stylebox("panel", type_name, _framed(palette["deep"], palette["line"], 4, 4, palette["radius"]))
		theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())
		theme.set_stylebox("selected", type_name, selected)
		theme.set_stylebox("selected_focus", type_name, selected)
		theme.set_stylebox("hovered", type_name, _box(Color(palette["raised"], 0.6), 4, 2, 2))
		theme.set_color("font_color", type_name, palette["text"])
		theme.set_color("font_selected_color", type_name, accent)
		theme.set_color("font_hovered_color", type_name, palette["text"])
		theme.set_color("guide_color", type_name, Color(palette["line"], 0.6))
	theme.set_stylebox("cursor", "Tree", StyleBoxEmpty.new())
	theme.set_stylebox("cursor_unfocused", "Tree", StyleBoxEmpty.new())
	theme.set_color("relationship_line_color", "Tree", palette["line"])
	theme.set_color("title_button_color", "Tree", palette["muted"])
	theme.set_stylebox("title_button_normal", "Tree", _box(palette["background"], 4, 3))
	theme.set_font("title_button_font", "Tree", palette["bold"])

	var rich: Font = palette["mono"]
	theme.set_font("normal_font", "RichTextLabel", rich)
	theme.set_color("default_color", "RichTextLabel", palette["text"])


static func _load_font(path: String) -> Font:
	if path == Tokens.FONT_FROM_TOKENS:
		return Tokens.font(&"ui")
	if path != "" and ResourceLoader.exists(path):
		var font: Font = load(path) as Font
		if font != null:
			return font
	if path != "":
		push_warning(T.t("DebugMenu: font \"%s\" not found, using the Godot font.") % path)
	return ThemeDB.fallback_font


# Sur une police variable (Montserrat) la graisse change ; sur une police
# classique elle est ignorée.
static func _weight(base_font: Font, weight: int) -> FontVariation:
	var variation: FontVariation = FontVariation.new()
	variation.base_font = base_font
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return variation


static func _box(color: Color, margin_h: float, margin_v: float, radius: int = 0) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	box.set_corner_radius_all(radius)
	return box


# Icône de case à cocher (14 px) : carré cerné de [param border], rempli de
# [param fill] ; cochée, un carré d'encre au centre.
static func _check_icon(border: Color, fill: Color, checked: bool) -> ImageTexture:
	var side: int = 14
	var image: Image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	image.fill(fill)
	for i in side:
		for edge in [0, side - 1]:
			image.set_pixel(i, edge, border)
			image.set_pixel(edge, i, border)
	if checked:
		image.fill_rect(Rect2i(4, 4, side - 8, side - 8), Tokens.color("ink"))
	return ImageTexture.create_from_image(image)


# Boîte cernée d'un filet de 1 px.
static func _framed(color: Color, border: Color, margin_h: float, margin_v: float, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = _box(color, margin_h, margin_v, radius)
	box.border_color = border
	box.set_border_width_all(1)
	return box

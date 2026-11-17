extends Node2D

## Gizmos dessinés par le jeu (DebugMenu.draw_line, draw_circle, draw_rect,
## draw_text, draw_arrow), en coordonnées du monde 2D, sur le calque qui
## suit la caméra.
## Durée : 0 = une seule image (à redemander à chaque image) ; sinon en
## secondes de temps réel. Un gizmo demandé dans _physics_process avec une
## durée 0 reste jusqu'au pas de physique suivant (pas de clignotement quand
## l'affichage va plus vite que la physique).
## Chaque catégorie a sa case dans le menu Display (signal category_added).

signal category_added(category: String)

const DEFAULT_CATEGORY: String = "Gizmos"
const FONT_SIZE: int = 12

var _items: Array[Dictionary] = []
var _hidden_categories: Dictionary = {} # catégorie -> true
var _known_categories: Dictionary = {}


func add(item: Dictionary, duration: float, category: String) -> void:
	if category == "":
		category = DEFAULT_CATEGORY
	if not _known_categories.has(category):
		_known_categories[category] = true
		category_added.emit(category)
	item["category"] = category
	if duration > 0.0:
		item["until"] = Time.get_ticks_msec() / 1000.0 + duration
	elif Engine.is_in_physics_frame():
		item["physics_frame"] = Engine.get_physics_frames()
	else:
		item["process_frame"] = Engine.get_process_frames()
	_items.append(item)


func is_category_shown(category: String) -> bool:
	return not _hidden_categories.has(category)


func set_category_shown(category: String, shown: bool) -> void:
	if shown:
		_hidden_categories.erase(category)
	else:
		_hidden_categories[category] = true


# DebugMenu passe avant les nœuds du jeu : les gizmos d'une image sont retirés
# avant que le jeu ne redemande les suivants.
func _process(_delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var process_frame: int = Engine.get_process_frames()
	var physics_frame: int = Engine.get_physics_frames()
	_items = _items.filter(func(item: Dictionary) -> bool:
		if item.has("until"):
			return item["until"] >= now
		if item.has("physics_frame"):
			return item["physics_frame"] >= physics_frame - 1
		return item["process_frame"] >= process_frame
	)
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for item in _items:
		if _hidden_categories.has(item["category"]):
			continue
		var color: Color = item["color"]
		match item["kind"]:
			"line":
				draw_line(item["from"], item["to"], color, item["width"], true)
			"arrow":
				_draw_arrow(item["from"], item["to"], color, item["width"])
			"circle":
				if item["filled"]:
					draw_circle(item["center"], item["radius"], color)
				else:
					draw_arc(item["center"], item["radius"], 0.0, TAU, 32, color, item["width"], true)
			"rect":
				draw_rect(item["rect"], color, item["filled"], -1.0 if item["filled"] else item["width"])
			"text":
				draw_string(font, item["position"], item["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _draw_arrow(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, color, width, true)
	if from.distance_to(to) < 1.0:
		return
	var back: Vector2 = (from - to).normalized() * minf(10.0, from.distance_to(to) * 0.5)
	draw_line(to, to + back.rotated(0.5), color, width, true)
	draw_line(to, to + back.rotated(-0.5), color, width, true)

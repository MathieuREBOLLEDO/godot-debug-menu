extends Control

## Cadres des sprites (Core > Display > Grid > Sprite frames) : autour de
## chaque Sprite2D et AnimatedSprite2D visible, et de chaque TextureRect et
## ColorRect posé dans le monde (parent Node2D), un cadre et son nom, la
## taille de l'image en pixels et la place occupée en cases de la grille
## (« Chili · 16×16 px · 1×1 »). Enfant du calque de la grille, dessiné en
## coordonnées d'écran. La liste des sprites est relue toutes les
## REFRESH_INTERVAL secondes.

signal enabled_changed

const REFRESH_INTERVAL: float = 0.5
const MAX_SPRITES: int = 300
const FONT_SIZE: int = 11
const FRAME_COLOR: Color = Color(0.3, 1.0, 1.0, 0.8)
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.8)

var enabled: bool = false:
	set(value):
		enabled = value
		_sprites.clear()
		_refresh_time = REFRESH_INTERVAL
		queue_redraw()
		enabled_changed.emit()

## Le calque de la grille (taille d'une case).
var grid: CanvasLayer

var _sprites: Array[Node] = []
var _refresh_time: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if not enabled:
		return
	_refresh_time += delta
	if _refresh_time >= REFRESH_INTERVAL:
		_refresh_time = 0.0
		_read_sprites()
	queue_redraw()


func _read_sprites() -> void:
	var skip: Node = grid.get_parent()
	_sprites.clear()
	for type_name in ["Sprite2D", "AnimatedSprite2D", "TextureRect", "ColorRect"]:
		for node in get_tree().root.find_children("*", type_name, true, false):
			if _sprites.size() >= MAX_SPRITES:
				return
			# Contrôles : seulement ceux posés dans le monde, pas l'interface.
			if node is Control and not node.get_parent() is Node2D:
				continue
			if skip == null or not skip.is_ancestor_of(node):
				_sprites.append(node)


func _draw() -> void:
	if not enabled:
		return
	var font: Font = ThemeDB.fallback_font
	var screen: Rect2 = Rect2(Vector2.ZERO, size)
	var cell_size: Vector2 = grid.get("cell_size")
	for sprite in _sprites:
		if not is_instance_valid(sprite) or not (sprite as CanvasItem).is_visible_in_tree():
			continue
		var rect: Rect2 = _local_rect(sprite)
		if not rect.has_area():
			continue
		# Coordonnées de l'écran, caméra et calques compris.
		var to_screen: Transform2D = (sprite as CanvasItem).get_global_transform_with_canvas()
		if not screen.intersects(to_screen * rect):
			continue
		var corners: PackedVector2Array = PackedVector2Array([
			to_screen * rect.position,
			to_screen * Vector2(rect.end.x, rect.position.y),
			to_screen * rect.end,
			to_screen * Vector2(rect.position.x, rect.end.y),
			to_screen * rect.position,
		])
		draw_polyline(corners, FRAME_COLOR, 1.0)
		var world_size: Vector2 = (to_screen.basis_xform(rect.size) / _canvas_zoom()).abs()
		var text: String = "%s · %s px · %s" % [sprite.name, _size_text(rect.size), _size_text(world_size / cell_size)]
		var at: Vector2 = (to_screen * rect).position - Vector2(0.0, 3.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, OUTLINE_COLOR)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, FRAME_COLOR)


# Zoom de la caméra (pixels d'écran par pixel du monde).
func _canvas_zoom() -> Vector2:
	return get_viewport().get_canvas_transform().get_scale()


# Rectangle de l'image dans les coordonnées du sprite.
static func _local_rect(sprite: Node) -> Rect2:
	if sprite is Control:
		return Rect2(Vector2.ZERO, (sprite as Control).size)
	if sprite is Sprite2D:
		return (sprite as Sprite2D).get_rect()
	var animated: AnimatedSprite2D = sprite as AnimatedSprite2D
	if animated.sprite_frames == null or not animated.sprite_frames.has_animation(animated.animation):
		return Rect2()
	var texture: Texture2D = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
	if texture == null:
		return Rect2()
	var texture_size: Vector2 = texture.get_size()
	var position: Vector2 = animated.offset
	if animated.centered:
		position -= texture_size / 2.0
	return Rect2(position, texture_size)


func _size_text(value: Vector2) -> String:
	return grid.call("size_text", value)

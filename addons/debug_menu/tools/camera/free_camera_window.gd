extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Free camera » (Core) : lancer ou quitter la caméra libre
## (tools/camera/free_camera.gd), ses vitesses, le FOV et la pause du jeu.

const Shortcuts = preload("res://addons/debug_menu/settings/shortcuts.gd")

var _camera: Node = null


func _ready() -> void:
	if get_debug_menu() != null:
		_camera = get_debug_menu().get("free_camera")
	super()
	if _camera != null:
		_camera.connect("changed", rebuild)


func _build() -> void:
	if _camera == null:
		add_note(T.t("DebugMenu not found: this window needs the addon to be active."))
		return
	add_status(func() -> String: return _camera.call("describe"))
	var active: bool = _camera.get("active")
	add_button(T.t("Leave the free camera") if active else T.t("Fly the free camera"), func() -> void: _camera.call("toggle"))
	add_hint(T.t("Shortcut %s (Settings to change it). 3D: replaces the active Camera3D; 2D: the view of the screen. The game camera comes back as it was.") % Shortcuts.key_text(Shortcuts.FREE_CAMERA))
	if _camera.call("has_player"):
		add_label(T.t("Left click while flying: teleport the player"))
	else:
		add_label(T.t("No player to teleport"))
	add_hint(T.t("The game declares its player with DebugMenu.set_player(node). Left click while flying puts it where you click (3D: where the click hits the scenery); its velocity is reset. A player with a debug_teleport(position) method places itself."))
	add_property_check(_camera, &"pause_game", T.t("Pause the game while flying"))
	add_hint(T.t("Otherwise the movement keys also move the player."))

	add_section(T.t("3D"))
	add_slider(_camera, &"speed_3d", T.t("Speed"), 0.1, 100.0, 0.1, " m/s")
	add_slider(_camera, &"fov", T.t("Field of view"), 10.0, 150.0, 1.0, "°")
	add_slider(_camera, &"sensitivity", T.t("Mouse sensitivity"), 0.02, 1.0, 0.01, "°/px")
	add_hint(T.t("%s to move, %s / %s down / up, Shift: faster, right click held: look around, wheel: speed (size of the view for an orthographic or isometric camera).") % [
		_camera.call("move_keys_text"), Shortcuts.physical_label(KEY_Q), Shortcuts.physical_label(KEY_E)])

	add_section(T.t("2D"))
	add_slider(_camera, &"speed_2d", T.t("Speed"), 50.0, 5000.0, 10.0, " px/s")
	add_hint(T.t("%s to move, wheel: zoom toward the mouse, right or middle drag: pan.") % _camera.call("move_keys_text"))

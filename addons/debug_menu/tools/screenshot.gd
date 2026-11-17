extends RefCounted

## Capture d'écran du jeu seul : la barre, les fenêtres et les dessins du
## debug menu sont cachés le temps d'une image, puis l'image est enregistrée
## en PNG dans FOLDER (user://, propre à la machine).

const FOLDER: String = "user://debug_menu/screenshots"


## Prend la capture et renvoie le chemin du fichier ("" en cas d'échec).
## À appeler avec await : il faut attendre une image sans le debug menu.
static func take(debug_menu: CanvasLayer) -> String:
	var hidden: Array[Object] = _hide_debug_ui(debug_menu)
	# Deux images : la première redessine l'écran sans le debug menu.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = debug_menu.get_viewport().get_texture().get_image()
	for item in hidden:
		item.set("visible", true)
	if image == null or image.is_empty():
		return "" # pas de rendu (lancement sans affichage, par exemple)
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var path: String = FOLDER.path_join("%s.png" % Time.get_datetime_string_from_system().replace(":", "-"))
	return path if image.save_png(path) == OK else ""


# Barre, fenêtres et calques du debug menu actuellement visibles.
static func _hide_debug_ui(debug_menu: CanvasLayer) -> Array[Object]:
	var hidden: Array[Object] = []
	for child in debug_menu.get_children():
		if (child is CanvasItem or child is CanvasLayer) and child.get("visible"):
			hidden.append(child)
	for window in debug_menu.get_node("Windows").get_children():
		if window is Window and (window as Window).visible:
			hidden.append(window)
	for item in hidden:
		item.set("visible", false)
	return hidden

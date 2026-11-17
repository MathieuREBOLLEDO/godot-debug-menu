extends RefCounted

## Couleurs ANSI dans les logs (« ESC[38;2;R;G;Bm », « ESC[93m », « ESC[39m ») :
## print_rich() les produit pour la sortie texte, par exemple avec log.gd.
## La console les convertit en BBCode pour sa RichTextLabel ; sans ça, elles
## s'afficheraient en clair. Les autres codes (gras...) sont retirés.

const PATTERN: String = "\\x1b\\[([0-9;]*)m"
## Codes 30-37 et 90-97 (couleur du texte).
const BASIC_COLORS: Dictionary = {
	30: "#000000", 31: "#cd3131", 32: "#0dbc79", 33: "#e5e510",
	34: "#2472c8", 35: "#bc3fbc", 36: "#11a8cd", 37: "#e5e5e5",
	90: "#666666", 91: "#f14c4c", 92: "#23d18b", 93: "#f5f543",
	94: "#3b8eea", 95: "#d670d6", 96: "#29b8db", 97: "#ffffff",
}


## [param text] en BBCode : les « [ » du texte sont protégés, les couleurs
## ANSI deviennent des [color].
static func to_bbcode(text: String) -> String:
	var result: String = ""
	var position: int = 0
	var open: int = 0 # [color] ouverts
	for found in RegEx.create_from_string(PATTERN).search_all(text):
		result += text.substr(position, found.get_start() - position).replace("[", "[lb]")
		position = found.get_end()
		var params: String = found.get_string(1)
		var color: String = _color(params)
		if color != "":
			result += "[color=%s]" % color
			open += 1
		elif params == "39" and open > 0: # fin de couleur
			result += "[/color]"
			open -= 1
		elif params == "" or params == "0": # tout remettre à zéro
			result += "[/color]".repeat(open)
			open = 0
	result += text.substr(position).replace("[", "[lb]")
	return result + "[/color]".repeat(open)


# « 38;2;R;G;B » ou un code de base ; "" si ce n'est pas une couleur de texte.
static func _color(params: String) -> String:
	var parts: PackedStringArray = params.split(";")
	if parts.size() >= 5 and parts[0] == "38" and parts[1] == "2":
		return "#" + Color8(parts[2].to_int(), parts[3].to_int(), parts[4].to_int()).to_html(false)
	if parts.size() == 1 and parts[0].is_valid_int() and BASIC_COLORS.has(parts[0].to_int()):
		return BASIC_COLORS[parts[0].to_int()]
	return ""

// Tramage ordonné (matrice de Bayer) de tout l'écran, pour le debug menu
// (display/dithering.gd). Réduit chaque couleur à « levels » niveaux en
// répartissant l'erreur selon la matrice ; gros pixels (pixel_size) ;
// palette : couleurs, niveaux de gris, ou deux couleurs.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform int matrix_size = 4; // 2, 4 ou 8
uniform float levels = 4.0; // niveaux par canal (2 à 32)
uniform float pixel_size = 1.0;
uniform float spread = 1.0; // force du tramage (0 : simple réduction)
uniform int palette_mode = 0; // 0 couleurs, 1 gris, 2 deux couleurs
uniform vec4 dark_color : source_color = vec4(0.08, 0.09, 0.14, 1.0);
uniform vec4 light_color : source_color = vec4(0.93, 0.85, 0.68, 1.0);

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

// Seuil de Bayer entre 0 et 1 pour la case p d'une matrice 2^bits.
float bayer(ivec2 p, int bits) {
	int size = 1 << bits;
	int x = p.x & (size - 1);
	int y = p.y & (size - 1);
	int mixed = x ^ y;
	int value = 0;
	for (int b = 0; b < bits; b++) {
		value = (value << 2) | (((mixed >> b) & 1) << 1) | ((y >> b) & 1);
	}
	return (float(value) + 0.5) / float(size * size);
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / pixel_size);
	vec2 uv = (cell + 0.5) * pixel_size * SCREEN_PIXEL_SIZE;
	vec3 color = texture(screen_texture, uv).rgb;
	int bits = matrix_size >= 8 ? 3 : (matrix_size >= 4 ? 2 : 1);
	float threshold = (bayer(ivec2(cell), bits) - 0.5) * spread;
	if (palette_mode != 0) {
		color = vec3(dot(color, LUMA));
	}
	float steps = max(levels - 1.0, 1.0);
	vec3 result = clamp(floor(color * steps + 0.5 + threshold) / steps, 0.0, 1.0);
	if (palette_mode == 2) {
		result = mix(dark_color.rgb, light_color.rgb, result.r);
	}
	COLOR = vec4(result, 1.0);
}

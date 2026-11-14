shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

// Inverted hull: draw only the back faces of an expanded copy of the mesh.
uniform vec4 outline_color : source_color = vec4(0.025, 0.035, 0.055, 1.0);
uniform float outline_width_pixels : hint_range(0.0, 8.0, 0.1) = 2.5;

void vertex() {
	vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec4 clip_position = PROJECTION_MATRIX * view_position;
	vec2 projected_normal = vec2(PROJECTION_MATRIX[0][0] * view_normal.x, PROJECTION_MATRIX[1][1] * view_normal.y);
	vec2 pixel_direction = projected_normal * VIEWPORT_SIZE;
	float direction_length = length(pixel_direction);
	// A normal facing directly into the camera has no silhouette expansion.
	if (direction_length > 0.0001) {
		pixel_direction /= direction_length;
		clip_position.xy += pixel_direction * (2.0 * outline_width_pixels / VIEWPORT_SIZE) * clip_position.w;
	}
	POSITION = clip_position;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}

shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform vec4 tint : source_color = vec4(1.0);

varying vec3 terrain_pigment;

void vertex() {
	terrain_pigment = CUSTOM0.rgb;
}

void fragment() {
	ALBEDO = terrain_pigment * tint.rgb;
	ROUGHNESS = 1.0;
}

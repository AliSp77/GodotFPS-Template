shader_type spatial;
render_mode diffuse_lambert, ambient_light_disabled;

// Opaque cel shading. The material's Next Pass adds the silhouette outline.
group_uniforms Surface;
uniform vec4 base_color : source_color = vec4(0.64, 1.0, 0.80, 1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool use_vertex_color = false;

group_uniforms Cel_Lighting;
uniform int light_bands : hint_range(2, 6, 1) = 3;
uniform float light_wrap : hint_range(0.0, 0.5, 0.01) = 0.08;
uniform vec4 shadow_tint : source_color = vec4(0.31, 0.39, 0.57, 1.0);
uniform float shadow_fill : hint_range(0.0, 1.0, 0.01) = 0.28;

group_uniforms Highlights;
uniform vec4 highlight_color : source_color = vec4(1.0, 0.93, 0.76, 1.0);
uniform float highlight_strength : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float highlight_size : hint_range(0.01, 0.5, 0.01) = 0.10;
uniform vec4 rim_color : source_color = vec4(0.62, 0.86, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0, 0.01) = 0.06;
uniform float rim_threshold : hint_range(0.0, 1.0, 0.01) = 0.78;

void fragment() {
	vec3 surface = base_color.rgb * texture(albedo_texture, UV).rgb;
	if (use_vertex_color) {
		surface *= COLOR.rgb;
	}
	ALBEDO = surface;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	float edge = 1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	// Explicit fill makes the shadow palette predictable in different environments.
	EMISSION = surface * shadow_tint.rgb * shadow_fill;
	EMISSION += rim_color.rgb * rim_strength * step(rim_threshold, edge);
}

void light() {
	float facing = clamp((dot(NORMAL, LIGHT) + light_wrap) / (1.0 + light_wrap), 0.0, 1.0);
	float steps = float(max(light_bands - 1, 1));
	float band = floor(facing * steps + 0.5) / steps;
	// Keep real shadow maps and point/spot light range attenuation.
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
	vec3 halfway = normalize(LIGHT + VIEW);
	float highlight = step(1.0 - highlight_size, max(dot(NORMAL, halfway), 0.0));
	SPECULAR_LIGHT += highlight_color.rgb * highlight_strength * highlight * step(0.001, facing) * ATTENUATION * LIGHT_COLOR / PI;
}

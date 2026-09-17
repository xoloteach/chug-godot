shader_type canvas_item;

uniform vec4 silhouette_color : source_color = vec4(0.06, 0.06, 0.08, 1.0);
uniform vec4 rim_color : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform float rim_intensity : hint_range(0.0, 3.0) = 0.8;
uniform vec4 eye_glow_color : source_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform float eye_glow_intensity : hint_range(0.0, 5.0) = 1.0;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.01) {
		discard;
	}
	
	// Base silhouette body
	vec3 base_col = silhouette_color.rgb;
	
	// Eye glow / highlight (represented by bright red or cyan pixels in sprite)
	if (tex.r > 0.8 && tex.g < 0.3 && tex.b < 0.3) {
		base_col = mix(base_col, eye_glow_color.rgb * eye_glow_intensity, 0.95);
	}
	
	// Rim edge detection from alpha neighbors
	vec2 pixel_size = TEXTURE_PIXEL_SIZE * 1.5;
	float a_up = texture(TEXTURE, UV + vec2(0.0, -pixel_size.y)).a;
	float a_down = texture(TEXTURE, UV + vec2(0.0, pixel_size.y)).a;
	float a_left = texture(TEXTURE, UV + vec2(-pixel_size.x, 0.0)).a;
	float a_right = texture(TEXTURE, UV + vec2(pixel_size.x, 0.0)).a;
	float edge = clamp((1.0 - (a_up * a_down * a_left * a_right)), 0.0, 1.0);
	
	base_col += rim_color.rgb * edge * rim_intensity;
	
	// Hit flash (pure white impact)
	base_col = mix(base_col, vec3(1.0), hit_flash);
	
	COLOR = vec4(base_col, tex.a);
}

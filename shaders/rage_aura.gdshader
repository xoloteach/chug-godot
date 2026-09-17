shader_type canvas_item;

uniform int aura_tier : hint_range(0, 3) = 1;
uniform float intensity : hint_range(0.0, 3.0) = 1.0;
uniform vec4 tier1_color : source_color = vec4(0.1, 0.8, 1.0, 0.7); // Soft Cyan
uniform vec4 tier2_color : source_color = vec4(0.8, 0.1, 0.9, 0.8); // Shadow Flame Magenta/Violet
uniform vec4 tier3_color : source_color = vec4(1.0, 0.85, 0.2, 0.9); // Golden Celestial

float noise(vec2 st) {
	return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	if (aura_tier == 0) {
		COLOR = vec4(0.0);
		return;
	}
	
	vec2 center = vec2(0.5, 0.5);
	vec2 uv = UV;
	float dist = distance(uv, center);
	
	vec4 target_color = tier1_color;
	if (aura_tier == 2) {
		target_color = tier2_color;
	} else if (aura_tier == 3) {
		target_color = tier3_color;
	}
	
	// Wavy flame distortion
	float angle = atan(uv.y - center.y, uv.x - center.x);
	float wave = sin(angle * 6.0 + TIME * 8.0) * 0.05 + cos(dist * 20.0 - TIME * 10.0) * 0.03;
	float flame = smoothstep(0.48 + wave, 0.15, dist);
	
	// Flickering particle noise
	float n = noise(uv * 10.0 + vec2(0.0, -TIME * 3.0));
	flame *= (0.8 + 0.4 * n);
	
	COLOR = vec4(target_color.rgb, flame * target_color.a * intensity);
}

shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.003;
uniform float scanline_density : hint_range(100.0, 1200.0) = 600.0;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.15;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.4;

float random(vec2 uv) {
	return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// Glitch block horizontal shift
	if (glitch_intensity > 0.01) {
		float block_y = floor(uv.y * 30.0);
		float noise = random(vec2(block_y, floor(TIME * 20.0)));
		if (noise > 0.85) {
			uv.x += (noise - 0.85) * glitch_intensity * 0.1;
		}
	}
	
	// Chromatic Aberration
	float r = texture(screen_texture, uv + vec2(chromatic_aberration * (1.0 + glitch_intensity * 3.0), 0.0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - vec2(chromatic_aberration * (1.0 + glitch_intensity * 3.0), 0.0)).b;
	vec3 col = vec3(r, g, b);
	
	// Scanlines
	float scanline = sin(uv.y * scanline_density) * 0.5 + 0.5;
	col = mix(col, col * scanline, scanline_opacity);
	
	// Vignette
	vec2 vig_uv = uv * (1.0 - uv.yx);
	float vig = vig_uv.x * vig_uv.y * 15.0;
	vig = clamp(pow(vig, vignette_intensity), 0.0, 1.0);
	col *= vig;
	
	COLOR = vec4(col, 1.0);
}

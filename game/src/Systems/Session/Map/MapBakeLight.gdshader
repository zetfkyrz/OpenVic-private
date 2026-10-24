shader_type canvas_item;
// Bakes the lighting of the relief from the baked heights: the normal (R, G = x, y of the normal), the ambient
// occlusion (B, 1 = open) and a soft shadow of the sun (A, 1 = lit).

uniform sampler2D height_tex: filter_linear, repeat_enable;
uniform vec2 map_pixels;
// Height of the highest terrain in map pixels, makes the slopes steeper and the shadows longer
uniform float height_scale = 70.0;
uniform float normal_strength = 9.0;
uniform float ao_radius = 9.0;
// Direction towards the sun on the map (u right, v down) and its elevation in radians
uniform vec2 sun_direction = vec2(-0.7071, -0.7071);
uniform float sun_elevation = 0.8;
uniform float shadow_length = 60.0;
// The land stands this much above the sea at the coast (in height units)
uniform float coast_cliff = 0.55;

const int AO_TAPS = 16;
const int SHADOW_STEPS = 24;
const float GOLDEN_ANGLE = 2.39996323;

float h(vec2 uv) {
	vec4 t = texture(height_tex, uv);
	return t.r + t.g * coast_cliff;
}

void fragment() {
	vec2 px = 1.0 / map_pixels;
	float centre = h(UV);

	// Slope from a wide Sobel kernel
	vec2 s = px * 2.0;
	float tl = h(UV + vec2(-s.x, -s.y)), t = h(UV + vec2(0.0, -s.y)), tr = h(UV + vec2(s.x, -s.y));
	float l = h(UV + vec2(-s.x, 0.0)), r = h(UV + vec2(s.x, 0.0));
	float bl = h(UV + vec2(-s.x, s.y)), b = h(UV + vec2(0.0, s.y)), br = h(UV + vec2(s.x, s.y));
	float dx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl);
	float dy = (bl + 2.0 * b + br) - (tl + 2.0 * t + tr);
	vec3 normal = normalize(vec3(-dx * normal_strength * 0.25, -dy * normal_strength * 0.25, 1.0));

	// Ambient occlusion: the terrain around is higher than the pixel
	float around = 0.0;
	for (int i = 0; i < AO_TAPS; i++) {
		float rad = sqrt((float(i) + 0.5) / float(AO_TAPS));
		float a = float(i) * GOLDEN_ANGLE;
		around += h(UV + vec2(cos(a), sin(a)) * rad * px * ao_radius);
	}
	around /= float(AO_TAPS);
	float ao = clamp(1.0 - max(around - centre, 0.0) * height_scale * 0.12, 0.0, 1.0);

	// Shadow: march towards the sun, a high terrain in the way casts a soft shadow
	float shadow = 0.0;
	float tan_el = tan(sun_elevation);
	for (int i = 1; i <= SHADOW_STEPS; i++) {
		float dist = shadow_length * float(i) / float(SHADOW_STEPS);
		float ray_height = centre * height_scale + dist * tan_el;
		float terrain = h(UV + sun_direction * dist * px) * height_scale;
		shadow = max(shadow, smoothstep(0.0, 4.0, terrain - ray_height));
	}

	COLOR = vec4(normal.xy * 0.5 + 0.5, ao, 1.0 - shadow);
}

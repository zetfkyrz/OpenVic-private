shader_type canvas_item;
// Bakes the relief of the map once: the height of the terrain (blurred terrain types plus fine noise), the land mask
// and the closeness to the coast. R = height, G = land mask (slightly blurred), B = land fraction around the pixel
// (0 in the open sea, about 0.5 at the coast), A = 1.

#include "res://src/Systems/Session/Map/ProvinceIndexSampler.gdshaderinc"

uniform float terrain_heights[128];
uniform sampler2D noise_tex: repeat_enable, filter_linear;
// Size of the province image in pixels
uniform vec2 map_pixels;
uniform float terrain_blur = 12.0;
uniform float height_detail = 0.35;
// Radius in map pixels over which the closeness to the coast is measured
uniform float shore_distance = 40.0;

const int HEIGHT_TAPS = 32;
const int COAST_TAPS = 24;
const float GOLDEN_ANGLE = 2.39996323;

float height_at(vec2 uv) {
	uint terrain = read_uvec3(uv).z;
	return terrain_heights[min(terrain, 127u)];
}

// Land is everything whose terrain type is not water (shallow seas have a texture index too)
float land_at(vec2 uv) {
	return float(terrain_heights[min(read_uvec3(uv).z, 127u)] > 0.0);
}

void fragment() {
	vec2 px = 1.0 / map_pixels;

	// Terrain heights blurred over a disc, so hills and mountains get smooth slopes
	float height = 0.0;
	float land_near = 0.0;
	for (int i = 0; i < HEIGHT_TAPS; i++) {
		float r = sqrt((float(i) + 0.5) / float(HEIGHT_TAPS));
		float a = float(i) * GOLDEN_ANGLE;
		vec2 offset = vec2(cos(a), sin(a)) * r;
		vec2 uv = UV + offset * px * terrain_blur;
		height += height_at(uv);
		land_near += land_at(UV + offset * px * 2.5);
	}
	height /= float(HEIGHT_TAPS);
	land_near /= float(HEIGHT_TAPS);

	// Fine noise, stronger on the high terrain
	float noise = texture(noise_tex, UV * vec2(24.0, 24.0 * map_pixels.y / map_pixels.x)).r
		+ 0.5 * texture(noise_tex, UV * vec2(96.0, 96.0 * map_pixels.y / map_pixels.x)).r;
	noise = noise / 1.5 - 0.5;
	height += noise * height_detail * (0.15 + height) * step(0.01, height);

	// Land fraction in a wide disc: the closeness to the coast for the layers of the water
	float coast = 0.0;
	for (int i = 0; i < COAST_TAPS; i++) {
		float r = sqrt((float(i) + 0.5) / float(COAST_TAPS));
		float a = float(i) * GOLDEN_ANGLE;
		coast += land_at(UV + vec2(cos(a), sin(a)) * r * px * shore_distance);
	}
	coast /= float(COAST_TAPS);

	COLOR = vec4(clamp(height, 0.0, 1.0), land_near, coast, 1.0);
}

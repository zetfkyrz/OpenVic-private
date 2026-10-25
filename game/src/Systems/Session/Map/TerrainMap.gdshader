shader_type spatial;

render_mode unshaded;

#include "res://src/Systems/Session/Map/ProvinceIndexSampler.gdshaderinc"

// The samplers below do not have the source_color hint because we do not want them
// to be converted from sRGB to linear colour space, we do that manually at the end.

// Province colour texture
uniform sampler2D province_colour_tex: repeat_enable, filter_nearest;
// Index of the mouse over the map mesh
uniform uint hover_index;
// Index of the currently selected province
uniform uint selected_index;
// How much to mix between the near detailed map (0) and the far parchment map (1)
uniform float parchment_mix;
// Cosmetic terrain textures
uniform sampler2DArray terrain_tex: repeat_enable, filter_linear;
// Factor converting pixels to terrain tile size
uniform float terrain_tile_factor;
// Map stripe mask texture
uniform sampler2D stripe_tex: repeat_enable, filter_linear;
// Factor converting pixels to stripe tile size
uniform float stripe_tile_factor;
// Map parchment overlay texture
uniform sampler2D overlay_tex: repeat_enable, filter_linear;
// Factor converting pixels to overlay tile size
uniform float overlay_tile_factor;
// Land map tint
uniform sampler2D colormap_land_tex: repeat_enable, filter_linear;
// Water map tint
uniform sampler2D colormap_water_tex: repeat_enable, filter_linear;
// Overlay map tint
uniform sampler2D colormap_overlay_tex: repeat_enable, filter_linear;

// Region (state) of every province: red and green bytes of the id, one texel per province number
uniform sampler2D province_region_tex: filter_nearest;

// ---- Look of the map (values come from the map theme, see MapBaker.gd) ----

// 0 low, 1 medium, 2 high: the number of samples of the borders and the layers of the relief and the water
uniform int quality = 0;
uniform int border_taps = 8;
// Widths of the lines scale with the zoom so that they keep a similar width on the screen
uniform float border_scale = 1.0;
uniform vec4 border_colour = vec4(0.015, 0.015, 0.025, 1.0);
uniform float border_opacity = 0.8;
uniform float border_width = 1.1;
uniform float glow_width = 8.0;
uniform float glow_opacity = 0.45;
uniform float tint_width = 26.0;
uniform float tint_opacity = 0.0;
// Darkens the colours of the countries (0.2 is 20 percent darker)
uniform float colour_darken = 0.1;
// Lines inside a country: one between its provinces and a wider one, a little more opaque, between its states (regions). The widths
// are in pixels of the screen, they do not change with the zoom.
uniform vec4 province_border_colour = vec4(0.1, 0.07, 0.05, 1.0);
uniform float province_border_opacity = 0.4;
uniform float province_border_width = 3.0;
uniform vec4 region_border_colour = vec4(0.1, 0.07, 0.05, 1.0);
uniform float region_border_opacity = 0.5;
uniform float region_border_width = 5.0;
// How visible the lines are for the current zoom (1 close, 0 far away: the lines of the provinces go first, then those of the regions)
uniform float province_border_fade = 1.0;
uniform float region_border_fade = 1.0;
uniform vec4 coast_colour = vec4(0.03, 0.04, 0.06, 1.0);
uniform float coast_opacity = 0.55;
uniform float coast_width = 1.1;

// Baked relief: heights / land mask / coast closeness, and normal / ambient occlusion / shadow
uniform sampler2D height_tex: filter_linear, repeat_enable;
uniform sampler2D relief_tex: filter_linear, repeat_enable;
uniform sampler2D sea_normal_tex: filter_linear, repeat_enable;
// 1 once the relief is baked
uniform float relief_amount = 0.0;
// Height of the highest mountains in world units, the mesh of the map is displaced by the baked heights
uniform float displacement = 0.0;
// Strength of the relief for the current zoom (0 far away)
uniform float relief_zoom = 0.0;
// Direction towards the sun (u right, v down, z up), moves a little with the camera
uniform vec3 sun_vector = vec3(-0.5, -0.5, 0.7);
uniform vec3 sun_colour = vec3(1.0, 0.96, 0.88);
uniform float relief_ambient = 0.6;
uniform float relief_diffuse = 0.7;
uniform float shadow_strength = 0.5;
uniform float ao_strength = 0.6;

uniform vec3 shallow_colour = vec3(0.55, 0.85, 0.95);
uniform vec3 deep_colour = vec3(0.12, 0.28, 0.5);
uniform float depth_strength = 0.55;
uniform vec3 shelf_colour = vec3(0.45, 0.64, 0.88);
uniform float shelf_strength = 0.4;
uniform float shelf_edge = 0.17;
uniform float rim_strength = 0.06;
uniform vec3 foam_colour = vec3(0.62, 0.8, 0.9);
uniform float foam_opacity = 0.4;
uniform float wave_speed = 0.8;
uniform float specular_strength = 0.35;

struct corner_args_t {
	vec2 uv, half_pixel_size; // Components for calculating a corner's sampling UV
	vec2 terrain_uv; // UV coordinates scaled for terrain texture tiling
	vec3 land_tint_colour, water_tint_colour; // Colours for tinting the terrain
	float stripe_mask; // Weight for mixing base and stripe province colours
};

struct corner_ret_t {
	vec3 terrain_colour;
	vec4 province_colour;
	float highlight_mix_val;
	// How strongly the current pixel is part of a border between regions of different colour
	float border_val;
};

// Calculate terrain colour at the specified corner of the current pixel
corner_ret_t get_corner_colour(const corner_args_t corner_args, const vec2 corner) {
	corner_ret_t ret;

	uvec3 province_data = read_uvec3(fma(corner, corner_args.half_pixel_size, corner_args.uv));

	// Find the terrain index at the specified corner of the current pixel
	uint terrain_index = province_data.z;

	// Get the tinted land colour at the current position
	vec3 land_colour = texture(terrain_tex, vec3(corner_args.terrain_uv, float(terrain_index))).rgb;
	land_colour = mix(land_colour, corner_args.land_tint_colour, 0.3);

	// TODO - proper water texture
	vec3 water_colour = corner_args.water_tint_colour;

	// Select land or water colour based on the terrain index (0 is water, otherwise land)
	ret.terrain_colour = mix(land_colour, water_colour, float(terrain_index == 0u));

	uint province_index = uvec2_to_uint(province_data.xy);

	// Get base and stripe colours for province at the current position
	province_data.x *= 2u; // Double "x coordinate" as colours come in (base, stripe) pairs
	vec4 province_base_colour = texelFetch(province_colour_tex, ivec2(province_data.xy), 0);

	province_data.x += 1u; // Add 1 to "x coordinate" to move from base to strip colour
	vec4 province_stripe_colour = texelFetch(province_colour_tex, ivec2(province_data.xy), 0);

	// Blend the base and stripe colours according to the current position's stripe mask value
	ret.province_colour = mix(province_base_colour, province_stripe_colour, corner_args.stripe_mask);

	ret.province_colour = mix(ret.province_colour, vec4(corner_args.water_tint_colour, 0.0), float(terrain_index == 0u));

	ret.highlight_mix_val = 0.4 * (
		float(province_index == hover_index) + float(province_index == selected_index)
	) * float(province_index != 0u);

	ret.border_val = 0.0;

	return ret;
}

// Difference in province colour between two corners, only counted where both are land (alpha is 0 for water)
float corner_colour_difference(const corner_ret_t a, const corner_ret_t b) {
	return length(a.province_colour.rgb - b.province_colour.rgb) * min(a.province_colour.a, b.province_colour.a);
}

// Blend together terrain colours from the four corners of the current pixel
corner_ret_t mix_terrain_colour(const corner_args_t corner_args, const vec2 pixel_offset) {
	corner_ret_t mm = get_corner_colour(corner_args, vec2(-1, -1));
	corner_ret_t pm = get_corner_colour(corner_args, vec2(+1, -1));
	corner_ret_t mp = get_corner_colour(corner_args, vec2(-1, +1));
	corner_ret_t pp = get_corner_colour(corner_args, vec2(+1, +1));

	corner_ret_t ret;

	ret.terrain_colour = mix(
		mix(mm.terrain_colour, pm.terrain_colour, pixel_offset.x),
		mix(mp.terrain_colour, pp.terrain_colour, pixel_offset.x),
		pixel_offset.y
	);

	ret.province_colour = mix(
		mix(mm.province_colour, pm.province_colour, pixel_offset.x),
		mix(mp.province_colour, pp.province_colour, pixel_offset.x),
		pixel_offset.y
	);

	ret.highlight_mix_val = mix(
		mix(mm.highlight_mix_val, pm.highlight_mix_val, pixel_offset.x),
		mix(mp.highlight_mix_val, pp.highlight_mix_val, pixel_offset.x),
		pixel_offset.y
	);

	// Pixels whose corners belong to regions with a different colour are on a border (e.g. between countries
	// in the political mapmode, provinces of the same country share a colour and so have no border between them)
	ret.border_val = max(
		max(corner_colour_difference(mm, pm), corner_colour_difference(mp, pp)),
		max(corner_colour_difference(mm, mp), corner_colour_difference(pm, pp))
	);

	return ret;
}

// Mix overlay and base colours, used for the parchment map
vec3 mix_overlay(const vec3 overlay_colour, const vec3 base_colour) {
	return mix(
		2.0 * overlay_colour * base_colour,
		1.0 - 2.0 * (1.0 - overlay_colour) * (1.0 - base_colour),
		greaterThanEqual(overlay_colour.rrb, vec3(0.5))
	);
}

const float GOLDEN_ANGLE = 2.39996323;

// Base colour (rgb) and land flag (a) of the province at a position, used by the smooth borders
vec4 flat_province_colour(vec2 uv) {
	uvec3 province_data = read_uvec3(uv);
	vec4 colour = texelFetch(province_colour_tex, ivec2(int(province_data.x) * 2, int(province_data.y)), 0);
	colour.a *= float(province_data.z != 0u);
	return colour;
}

// Fraction (0..1) of the samples of a disc around the position that belong to a region of another colour, or with
// coast = true to land of the other kind. It is about 0.5 on a border and falls to 0 at the radius of the disc, so it
// has no steps even though the province map is made of pixels.
float border_fraction(vec2 uv, vec2 pixel_uv, float radius, int taps, vec4 centre, bool coast) {
	float different = 0.0;
	for (int i = 0; i < taps; i++) {
		float r = sqrt((float(i) + 0.5) / float(taps));
		float a = float(i) * GOLDEN_ANGLE;
		vec4 other = flat_province_colour(uv + vec2(cos(a), sin(a)) * r * radius * pixel_uv);
		if (coast) {
			different += abs(centre.a - other.a);
		} else {
			different += smoothstep(0.04, 0.14, length(other.rgb - centre.rgb) * min(other.a, centre.a));
		}
	}
	return different / float(taps);
}

// Outlines of the countries in the style of HOI4: a crisp dark line on the border, a darker band of the country colour
// next to it and a wide glow in the colour of the country that fades towards the inside. All of them are smooth, and a
// thin line runs along the coast.
vec3 apply_borders(vec3 colour, vec2 uv, vec2 pixel_uv) {
	vec4 centre = flat_province_colour(uv);

	float scale = border_scale * mix(1.0, 1.35, parchment_mix);
	float fade = 1.0 - 0.4 * parchment_mix;

	// Wide glow in the colour of the country
	if (quality >= 1 && tint_opacity > 0.0 && centre.a > 0.5) {
		float ft = border_fraction(uv, pixel_uv, tint_width * scale, quality >= 2 ? 12 : 8, centre, false);
		vec3 tint = clamp(centre.rgb * 1.5 + 0.12, 0.0, 1.0);
		colour = mix(colour, tint, smoothstep(0.0, 0.45, ft) * tint_opacity * fade);
	}

	// Darker band next to the line
	if (quality >= 1 && glow_opacity > 0.0) {
		float g = border_fraction(uv, pixel_uv, glow_width * scale, quality >= 2 ? 10 : 6, centre, false);
		colour = mix(colour, mix(colour, border_colour.rgb, 0.8), smoothstep(0.0, 0.5, g) * glow_opacity * fade);
	}

	// Crisp line
	float f = border_fraction(uv, pixel_uv, border_width * scale, border_taps, centre, false);
	float line = smoothstep(0.03, 0.42, f);
	colour = mix(colour, border_colour.rgb, clamp(line * border_opacity * mix(1.0, 0.7, parchment_mix), 0.0, 1.0));

	if (quality >= 2 && coast_opacity > 0.0) {
		float c = border_fraction(uv, pixel_uv, coast_width * scale, 8, centre, true);
		colour = mix(colour, coast_colour.rgb, smoothstep(0.03, 0.45, c) * coast_opacity * (1.0 - 0.5 * parchment_mix));
	}
	return colour;
}

// Region (state) id of a province, 0 if it has none
uint region_of(uvec2 province_xy) {
	uvec2 id = uvec2(texelFetch(province_region_tex, ivec2(province_xy), 0).rg * 255.0 + 0.5);
	return (id.y << 8u) | id.x;
}

// The lines inside a country as in the original game: a line between its provinces and a wider, more opaque one between its states
// (regions). They are drawn under the outlines of the countries. A line of the width W pixels of the screen is found with a ring of
// samples around the pixel whose radius is about W / 1.9: the pixel is on the line when the samples on the ring reach the next
// province. Pixels far from every border take only the first ring.
vec3 apply_inner_borders(vec3 colour, vec2 uv, vec2 pixel_uv) {
	if ((province_border_opacity <= 0.0 || province_border_fade <= 0.002) && (region_border_opacity <= 0.0 || region_border_fade <= 0.002)) {
		return colour;
	}
	uvec3 centre = read_uvec3(uv);
	if (centre.z == 0u) {
		return colour;
	}
	uint centre_province = uvec2_to_uint(centre.xy);
	uint centre_region = region_of(centre.xy);

	// Map pixels in one pixel of the screen: the lines keep their width on the screen at every zoom
	vec2 per_screen = fwidth(uv / pixel_uv);
	float screen_px = max(max(per_screen.x, per_screen.y), 0.05);
	float province_radius = province_border_width * screen_px / 1.9;
	float region_radius = region_border_width * screen_px / 1.9;
	float outer_radius = max(province_radius, region_radius);

	const int TAPS = 12;
	const float TAP_ANGLE = 6.2831853 / float(TAPS);

	// Is any border (of a province) within the widest line?
	float near_border = 0.0;
	for (int i = 0; i < TAPS; i++) {
		float a = float(i) * TAP_ANGLE;
		uvec3 other = read_uvec3(uv + vec2(cos(a), sin(a)) * pixel_uv * outer_radius);
		near_border += float(other.z != 0u && uvec2_to_uint(other.xy) != centre_province);
	}
	if (near_border <= 0.0) {
		return colour;
	}

	float province_edge = 0.0;
	float region_edge = 0.0;
	for (int i = 0; i < TAPS; i++) {
		float a = float(i) * TAP_ANGLE;
		vec2 direction = vec2(cos(a), sin(a)) * pixel_uv;
		uvec3 province_sample = read_uvec3(uv + direction * province_radius);
		province_edge += float(province_sample.z != 0u && uvec2_to_uint(province_sample.xy) != centre_province);
		uvec3 region_sample = read_uvec3(uv + direction * region_radius);
		region_edge += float(region_sample.z != 0u && uvec2_to_uint(region_sample.xy) != centre_province && region_of(region_sample.xy) != centre_region);
	}
	province_edge /= float(TAPS);
	region_edge /= float(TAPS);

	// The lines fade out when the camera moves away. Where both are present the stronger one is used (they do not add up, so the
	// lines have the opacity that was asked for).
	float province_line = smoothstep(0.02, 0.2, province_edge) * province_border_opacity * province_border_fade;
	float region_line = smoothstep(0.02, 0.2, region_edge) * region_border_opacity * region_border_fade;
	vec3 line_colour = region_line >= province_line ? region_border_colour.rgb : province_border_colour.rgb;
	return mix(colour, line_colour, max(province_line, region_line));
}

// Thin outline of a province (the hovered or the selected one): black, about one pixel of the screen wide
vec3 apply_province_outline(vec3 colour, vec2 uv, vec2 pixel_uv, uint province, float opacity) {
	if (province == 0u) {
		return colour;
	}
	const int TAPS = 8;
	bool inside = uvec2_to_uint(read_uvec3(uv).xy) == province;
	// Map pixels per pixel of the screen: the outline is half of that wide on each side of the border
	vec2 per_screen = fwidth(uv / pixel_uv);
	float radius = clamp(max(per_screen.x, per_screen.y) * 0.5, 0.6, 8.0);
	float edge = 0.0;
	for (int i = 0; i < TAPS; i++) {
		float a = float(i) * 6.2831853 / float(TAPS);
		bool other_inside = uvec2_to_uint(read_uvec3(uv + vec2(cos(a), sin(a)) * radius * pixel_uv).xy) == province;
		edge += float(inside != other_inside);
	}
	edge /= float(TAPS);
	return mix(colour, vec3(0.0), smoothstep(0.05, 0.45, edge) * opacity);
}

// Light and shade of the relief on land, depth, foam and glints on the water
vec3 apply_relief_and_water(vec3 colour, vec2 uv) {
	if (quality == 0 || relief_amount <= 0.0) {
		return colour;
	}

	vec4 heights = texture(height_tex, uv);
	vec4 relief = texture(relief_tex, uv);
	float k = relief_zoom * (1.0 - parchment_mix);
	float land = smoothstep(0.1, 0.9, heights.g);

	// Land: diffuse light on the baked normal with ambient occlusion and the soft shadow of the sun
	vec3 sun = normalize(sun_vector);
	vec2 n_xy = relief.xy * 2.0 - 1.0;
	vec3 normal = vec3(n_xy, sqrt(max(1.0 - dot(n_xy, n_xy), 0.0)));
	float flat_light = relief_ambient + relief_diffuse * sun.z;
	float light = relief_ambient + relief_diffuse * max(dot(normal, sun), 0.0) * mix(1.0, relief.a, shadow_strength);
	light = light / flat_light * mix(1.0, relief.b, ao_strength);
	vec3 land_colour = colour * mix(1.0, light, k) * mix(vec3(1.0), sun_colour, 0.35 * k);

	// Water: deeper and darker away from the coast, foam waves along it
	float coast = heights.b;
	float depth = 1.0 - smoothstep(0.0, 0.42, coast);
	vec3 water_tint = mix(shallow_colour, deep_colour, depth);
	vec3 water_colour = mix(colour, colour * water_tint * 1.8, depth_strength * (1.0 - parchment_mix));

	// Shelf: light shallow water along the coast, getting lighter towards the shore, and a darker rim at its edge
	// A wide, soft gradient: no visible edge between the shallow water and the deep sea
	float shelf = smoothstep(shelf_edge - 0.17, shelf_edge + 0.2, coast);
	float rim = exp(-pow((coast - shelf_edge) / 0.08, 2.0));
	vec3 shelf_tint = shelf_colour * (0.85 + 0.45 * smoothstep(shelf_edge, 0.5, coast));
	water_colour = mix(water_colour, shelf_tint, shelf * shelf_strength * (1.0 - parchment_mix));
	water_colour *= 1.0 - rim * rim_strength * (1.0 - parchment_mix);

	float time = TIME * wave_speed;
	vec2 sea_uv = uv * vec2(70.0, 70.0 * float(textureSize(province_shape_tex, 0).y) / float(max(textureSize(province_shape_tex, 0).x, 1)));
	vec3 sea = texture(sea_normal_tex, sea_uv + vec2(time * 0.03, time * 0.012)).rgb;

	// Surf: smooth waves that follow the coast line and roll towards the shore (surf is 0.5 on the coast, 0 away)
	float surf = heights.a;
	float zone = smoothstep(0.03, 0.22, surf);
	float phase = surf * 22.0 - (quality >= 2 ? time * 1.6 : 0.0);
	float wave = smoothstep(0.1, 0.9, 0.5 + 0.5 * sin(phase * 3.14159));
	// The foam is a lighter shade of the sea, brightest at the shore
	vec3 foam_tint = mix(water_colour * 1.35, foam_colour, 0.55);
	float foam = zone * (0.3 + 0.7 * wave) * foam_opacity * (1.0 - parchment_mix * 0.6);
	water_colour = mix(water_colour, foam_tint, clamp(foam, 0.0, 1.0));

	if (quality >= 2 && specular_strength > 0.0) {
		vec3 glint_normal = normalize(vec3((sea.xy * 2.0 - 1.0) * 0.4, 1.0));
		float glint = pow(max(dot(glint_normal, normalize(sun + vec3(0.0, 0.0, 1.0))), 0.0), 90.0);
		water_colour += sun_colour * glint * specular_strength * k * depth;
	}

	return mix(water_colour, land_colour, land);
}

// Calculate map colour at specified UV coordinates, combining terrain, province base and stripe colour,
// parchment overlay, and highlighting the result if it is a hovered over and/or selected province.
vec3 get_map_colour(vec2 uv) {
	vec2 map_size = vec2(textureSize(province_shape_tex, 0).xy) * province_shape_subdivisions;
	vec2 uv_map_pixels = fma(uv, map_size, vec2(0.5));
	// Offset of uv_map_pixels from the top left corner of the current pixel
	vec2 pixel_offset = fract(uv_map_pixels);

	corner_args_t corner_args;
	corner_args.uv = uv;
	corner_args.half_pixel_size = 0.49 / map_size;
	// Terrain texture tiling UV
	corner_args.terrain_uv = 0.5 - uv_map_pixels * terrain_tile_factor;

	vec2 stripe_uv = uv_map_pixels * stripe_tile_factor;
	// Stripe mask value - between 0 (base) and 1 (stripe)
	corner_args.stripe_mask = texture(stripe_tex, stripe_uv).b;

	vec2 colormap_uv = vec2(uv.x, 1.0 - uv.y);
	// Terrain tinting colours
	corner_args.land_tint_colour = texture(colormap_land_tex, colormap_uv).rgb;
	corner_args.water_tint_colour = texture(colormap_water_tex, colormap_uv).rgb;
	// Parchment tint colour
	vec3 overlay_tint_colour = texture(colormap_overlay_tex, colormap_uv).rgb;

	corner_ret_t colours = mix_terrain_colour(corner_args, pixel_offset);

	// Blended terrain colour (average of four corners of current pixel)
	vec3 terrain_colour = colours.terrain_colour;

	vec2 overlay_uv = vec2(uv_map_pixels.x, map_size.y - uv_map_pixels.y) * overlay_tile_factor;
	// Parchment overlay colour
	vec3 overlay_colour = texture(overlay_tex, overlay_uv).rgb;

	vec4 province_colour = colours.province_colour;
	// Darken the province colour
	province_colour.rgb -= 0.7;

	// Rec.709 luma coefficients
	const vec3 luma_weights = vec3(0.2126, 0.7152, 0.0722);
	float terrain_luma = dot(terrain_colour, luma_weights);

	// Near colour is either the terrain's luma component tinted with the province colour and brightened,
	// or the normal terrain colour
	vec3 near_province_colour = mix(vec3(terrain_luma), province_colour.rgb, 0.3) * 1.5;
	vec3 near_colour = mix(terrain_colour, near_province_colour, province_colour.a);

	// Far colour is either the province colour mixed with the overlay texture, tinted with the overlay colormap and brightened,
	// or the normal terrain colour mixed with the overlay texture (primarily for water)
	vec3 far_province_colour = mix_overlay(overlay_colour, province_colour.rgb);
	far_province_colour = mix(overlay_tint_colour, far_province_colour, 0.3) * 1.5;
	vec3 far_terrain_colour = mix_overlay(overlay_colour, terrain_colour);
	vec3 far_colour = mix(far_terrain_colour, far_province_colour, province_colour.a);

	// Blend the near (detailed terrain) and far (parchment) colours according to the parchment mix factor (0 for near, 1 for far)
	vec3 final_colour = mix(near_colour, far_colour, parchment_mix);

	final_colour *= 1.0 - colour_darken * province_colour.a;

	// Relief light and water layers, then the smooth dark outlines on top
	final_colour = apply_relief_and_water(final_colour, uv);
	final_colour = apply_inner_borders(final_colour, uv, 1.0 / map_size);
	final_colour = apply_borders(final_colour, uv, 1.0 / map_size);
	// Outline of the hovered province (half opaque) and of the selected one (three quarters opaque)
	if (hover_index != selected_index) {
		final_colour = apply_province_outline(final_colour, uv, 1.0 / map_size, hover_index, 0.5);
	}
	final_colour = apply_province_outline(final_colour, uv, 1.0 / map_size, selected_index, 0.75);

	// Significantly brighted the colour if it is hovered over and/or selected, but not if it has province index 0 (all invalid pixels)
	const vec3 highlight_colour = vec3(1.0);
	vec3 highlighted_colour = mix(final_colour, highlight_colour, colours.highlight_mix_val);

	return highlighted_colour;
}

// Convert from standard RGB to linear colour space (Godot requires the output to be linear)
vec3 srgb_to_linear(vec3 srgb) {
	return mix(
		srgb * (1.0 / 12.92),
		pow((srgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)),
		greaterThan(srgb, vec3(0.04045))
	);
}

void vertex() {
	if (displacement > 0.0) {
		VERTEX.y += textureLod(height_tex, UV, 0.0).r * displacement / length(MODEL_MATRIX[1].xyz);
	}
}

void fragment() {

	// TODO - add borders, coastlines, rivers, fog of war

	ALBEDO = srgb_to_linear(get_map_colour(UV));
}

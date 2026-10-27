shader_type spatial;

// A model with an ordinary material (ships, shadow blobs) whose animation is played by the video card: what StandardMaterial3D of the
// loader does (an albedo texture with alpha, an optional normal map, double sided, depth pre-pass for the alpha) and the vertex animation
render_mode cull_disabled, depth_prepass_alpha;

#include "res://src/Model/vat.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_albedo_texture = false;
uniform bool use_normal_texture = false;

void vertex() {
	int vertex_id = int(UV2.x + 0.5);
	VatFrame frame = vat_frame(TIME);
	VERTEX = mix(vat_fetch(vat_positions, frame.first, vertex_id), vat_fetch(vat_positions, frame.second, vertex_id), frame.mix_factor);
	NORMAL = normalize(mix(vat_fetch(vat_normals, frame.first, vertex_id), vat_fetch(vat_normals, frame.second, vertex_id), frame.mix_factor));
}

void fragment() {
	vec4 albedo = use_albedo_texture ? texture(albedo_texture, UV) : vec4(1.0);
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
	if (use_normal_texture) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
	}
}

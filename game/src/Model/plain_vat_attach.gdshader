shader_type spatial;

// The same as plain_vat.gdshader for a part that is carried by a bone of an animated model (see unit_vat_attach.gdshader)
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D vat_bones : filter_nearest, repeat_disable;
uniform int vat_bone = 0;
uniform vec4 vat_clips[3];

instance uniform float vat_clip = 0.0;
instance uniform float vat_phase = 0.0;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_albedo_texture = false;
uniform bool use_normal_texture = false;

void vertex() {
	vec4 clip = vat_clips[clamp(int(vat_clip + 0.5), 0, 2)];
	float position = fract((TIME + vat_phase) / max(clip.z, 0.001)) * clip.y;
	int count = max(int(clip.y + 0.5), 1);
	int local_first = int(floor(position));
	int first = int(clip.x + 0.5) + local_first % count;
	int second = int(clip.x + 0.5) + (local_first + 1) % count;
	float t = fract(position);

	vec4 a0 = mix(texelFetch(vat_bones, ivec2(vat_bone * 3 + 0, first), 0), texelFetch(vat_bones, ivec2(vat_bone * 3 + 0, second), 0), t);
	vec4 a1 = mix(texelFetch(vat_bones, ivec2(vat_bone * 3 + 1, first), 0), texelFetch(vat_bones, ivec2(vat_bone * 3 + 1, second), 0), t);
	vec4 a2 = mix(texelFetch(vat_bones, ivec2(vat_bone * 3 + 2, first), 0), texelFetch(vat_bones, ivec2(vat_bone * 3 + 2, second), 0), t);

	vec3 v = VERTEX;
	VERTEX = vec3(dot(a0.xyz, v) + a0.w, dot(a1.xyz, v) + a1.w, dot(a2.xyz, v) + a2.w);
	vec3 n = NORMAL;
	NORMAL = normalize(vec3(dot(a0.xyz, n), dot(a1.xyz, n), dot(a2.xyz, n)));
}

void fragment() {
	vec4 albedo = use_albedo_texture ? texture(albedo_texture, UV) : vec4(1.0);
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
	if (use_normal_texture) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
	}
}

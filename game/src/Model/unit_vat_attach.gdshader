shader_type spatial;

render_mode cull_disabled;

// A part that is carried by a bone of an animated model (the helmet, the rifle): it keeps its own shape and goes where the bone goes.
// The poses of the bones in all the frames of the clips of the model are in a texture (3 texels for a bone: the rows of the 3x4 matrix).

uniform sampler2D vat_bones : filter_nearest, repeat_disable;
uniform int vat_bone = 0;
uniform vec4 vat_clips[3];

instance uniform float vat_clip = 0.0;
instance uniform float vat_phase = 0.0;

uniform sampler2D texture_diffuse[32] : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_nation_colors_mask[32] : source_color, filter_linear_mipmap, repeat_enable;

instance uniform vec3 colour_primary : source_color;
instance uniform vec3 colour_secondary : source_color;
instance uniform vec3 colour_tertiary : source_color;

instance uniform uint tex_index_diffuse;
instance uniform uint tex_index_specular;

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
	vec2 base_uv = UV;
	vec4 diffuse_tex = texture(texture_diffuse[tex_index_diffuse], base_uv);
	vec4 nation_colours_tex = texture(texture_nation_colors_mask[tex_index_specular], base_uv);

	vec3 primary_col = mix(vec3(1.0, 1.0, 1.0), colour_primary, nation_colours_tex.g);
	vec3 secondary_col = mix(vec3(1.0, 1.0, 1.0), colour_secondary, nation_colours_tex.b);
	vec3 tertiary_col = mix(vec3(1.0, 1.0, 1.0), colour_tertiary, nation_colours_tex.r);

	ALBEDO = diffuse_tex.rgb * primary_col * secondary_col * tertiary_col;
}

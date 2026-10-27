// Vertex animation textures (see VatBake.gd): the video card plays the animation of a model.
// The positions and the normals of every vertex in every frame are in two textures, the frames of all the clips of the model one
// after another: the texel of (frame, vertex) is at (frame * vat_vertex_count + vertex) of the rows that are vat_width wide.

uniform sampler2D vat_positions : filter_nearest, repeat_disable;
uniform sampler2D vat_normals : filter_nearest, repeat_disable;
uniform int vat_width = 2048;
uniform int vat_vertex_count = 1;
// For every clip (idle, move, attack): x the first frame, y the number of frames, z the length of the clip in seconds
uniform vec4 vat_clips[3];

// Which clip plays and when it started (the phase is different for every unit, so that the units do not march in step)
instance uniform float vat_clip = 0.0;
instance uniform float vat_phase = 0.0;

struct VatFrame {
	int first;
	int second;
	float mix_factor;
};

VatFrame vat_frame(float time) {
	vec4 clip = vat_clips[clamp(int(vat_clip + 0.5), 0, 2)];
	float position = fract((time + vat_phase) / max(clip.z, 0.001)) * clip.y;
	int local_first = int(floor(position));
	int count = max(int(clip.y + 0.5), 1);
	VatFrame result;
	result.first = int(clip.x + 0.5) + local_first % count;
	result.second = int(clip.x + 0.5) + (local_first + 1) % count;
	result.mix_factor = fract(position);
	return result;
}

vec3 vat_fetch(sampler2D tex, int frame, int vertex) {
	int index = frame * vat_vertex_count + vertex;
	return texelFetch(tex, ivec2(index % vat_width, index / vat_width), 0).xyz;
}

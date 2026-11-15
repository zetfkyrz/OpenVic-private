// The icons over the armies (UnitBanners.gd), drawn by the video card: every icon is a quad of a MultiMesh at the position of its
// army, the picture is a cell of the atlas the panels of the icons are drawn into. The quads keep their size on the screen: the
// position is projected here and the corners are moved by pixels, so the processor does nothing when the camera moves.
//
// Data of an instance:
//   origin of the transform: the point on the ground the icon stands on (its anchor);
//   basis x: (left, top, width) of the quad in canvas units of a full size icon, relative to the anchor; basis y.x: its height;
//   custom data: the rectangle of its cell in the atlas (x, y, width, height in UV);
//   colour: the modulate (the selection).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled,
	skip_vertex_transform;

uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
// Pixels of the screen for a canvas unit of a full size icon: the size of the icons (zoom, setting) times the scale of the interface
uniform float pixel_scale = 1.0;

varying vec2 atlas_uv;
varying vec4 modulate;

void vertex() {
	vec3 anchor = MODEL_MATRIX[3].xyz;
	vec2 quad_position = MODEL_MATRIX[0].xy;
	vec2 quad_size = vec2(MODEL_MATRIX[0].z, MODEL_MATRIX[1].x);
	// The corner of the quad, 0..1 from the top left (the QuadMesh goes from -0.5 to 0.5, y up)
	vec2 corner = vec2(VERTEX.x + 0.5, 0.5 - VERTEX.y);
	vec4 clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(anchor, 1.0));
	if (clip.w <= 0.0) {
		// behind the camera
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	} else {
		vec2 pixels = (quad_position + corner * quad_size) * pixel_scale;
		clip.xy += vec2(pixels.x, -pixels.y) * 2.0 / VIEWPORT_SIZE * clip.w;
		POSITION = clip;
	}
	atlas_uv = INSTANCE_CUSTOM.xy + corner * INSTANCE_CUSTOM.zw;
	modulate = COLOR;
}

void fragment() {
	// The atlas is drawn on a transparent background: its colours are premultiplied by the alpha
	vec4 texel = texture(atlas, atlas_uv);
	ALBEDO = texel.rgb * modulate.rgb;
	ALPHA = texel.a;
}

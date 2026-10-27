#pragma once

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace OpenVic {
	/* Bakes the animation of a skinned model into textures (vertex animation textures): the position and the normal of every vertex
	 * for every frame of an animation. The shader of the model reads them by the number of the vertex and the time, so the processor
	 * does not play the animation (no skeleton, no animation player) and the video card does all the work. */
	class VATBaker : public godot::Object {
		GDCLASS(VATBaker, godot::Object)

	protected:
		static void _bind_methods();

	public:
		/* positions, normals: the vertices in the rest pose; bone_ids and weights: influences_per_vertex entries for every vertex;
		 * skin_matrices: for every frame and every bone 12 floats (the columns of the basis x, y, z and the origin) of the matrix
		 * that moves the rest pose of the bone to its pose in the frame (global pose times the inverse of the global rest pose).
		 * Returns {"positions": Image, "normals": Image} in the format RGBAH, the texel of (frame, vertex) is at
		 * frame * vertex_count + vertex of the row-major texture that is texture_width wide, and {"width", "height"}. */
		static godot::Dictionary bake_skinned(
			godot::PackedVector3Array const& positions, godot::PackedVector3Array const& normals,
			godot::PackedInt32Array const& bone_ids, godot::PackedFloat32Array const& weights, int32_t influences_per_vertex,
			godot::PackedFloat32Array const& skin_matrices, int32_t bone_count, int32_t frame_count, int32_t texture_width
		);

		/* The matrices of the bones for every frame as a texture (RGBAH): 3 texels for a bone and a frame, the rows of the 3x4 matrix,
		 * the texel (bone * 3 + row, frame). matrices: 12 floats for every frame and bone as above. */
		static godot::Ref<godot::Image> bake_matrices(
			godot::PackedFloat32Array const& matrices, int32_t bone_count, int32_t frame_count
		);
	};
}

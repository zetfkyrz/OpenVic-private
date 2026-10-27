#include "VATBaker.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

using namespace OpenVic;
using namespace godot;

namespace {
	// float32 -> float16 (round to nearest, no care for denormals: the values are positions of a model)
	uint16_t to_half(const float value) {
		uint32_t bits;
		std::memcpy(&bits, &value, sizeof(bits));
		const uint32_t sign = (bits >> 16) & 0x8000u;
		const int32_t exponent = static_cast<int32_t>((bits >> 23) & 0xFF) - 127 + 15;
		const uint32_t mantissa = bits & 0x7FFFFFu;
		if (exponent <= 0) {
			if (exponent < -10) {
				return static_cast<uint16_t>(sign);
			}
			const uint32_t full = mantissa | 0x800000u;
			const uint32_t shift = static_cast<uint32_t>(14 - exponent);
			uint32_t half = full >> shift;
			if ((full >> (shift - 1)) & 1u) {
				half++;
			}
			return static_cast<uint16_t>(sign | half);
		}
		if (exponent >= 31) {
			return static_cast<uint16_t>(sign | 0x7C00u);
		}
		uint32_t half = (static_cast<uint32_t>(exponent) << 10) | (mantissa >> 13);
		if (mantissa & 0x1000u) {
			half++;
		}
		return static_cast<uint16_t>(sign | half);
	}

	void write_texel(uint8_t* destination, const float x, const float y, const float z, const float w) {
		const uint16_t half[4] = { to_half(x), to_half(y), to_half(z), to_half(w) };
		std::memcpy(destination, half, sizeof(half));
	}
}

void VATBaker::_bind_methods() {
	ClassDB::bind_static_method(
		"VATBaker",
		D_METHOD(
			"bake_skinned", "positions", "normals", "bone_ids", "weights", "influences_per_vertex", "skin_matrices", "bone_count",
			"frame_count", "texture_width"
		),
		&VATBaker::bake_skinned
	);
	ClassDB::bind_static_method(
		"VATBaker", D_METHOD("bake_matrices", "matrices", "bone_count", "frame_count"), &VATBaker::bake_matrices
	);
}

Dictionary VATBaker::bake_skinned(
	PackedVector3Array const& positions, PackedVector3Array const& normals, PackedInt32Array const& bone_ids,
	PackedFloat32Array const& weights, const int32_t influences_per_vertex, PackedFloat32Array const& skin_matrices,
	const int32_t bone_count, const int32_t frame_count, const int32_t texture_width
) {
	Dictionary result;
	const int64_t vertex_count = positions.size();
	ERR_FAIL_COND_V(vertex_count <= 0 || frame_count <= 0 || bone_count <= 0 || texture_width <= 0, result);
	ERR_FAIL_COND_V(influences_per_vertex <= 0, result);
	ERR_FAIL_COND_V(bone_ids.size() < vertex_count * influences_per_vertex, result);
	ERR_FAIL_COND_V(weights.size() < vertex_count * influences_per_vertex, result);
	ERR_FAIL_COND_V(skin_matrices.size() < static_cast<int64_t>(frame_count) * bone_count * 12, result);
	const bool has_normals = normals.size() >= vertex_count;

	const int64_t texel_count = vertex_count * frame_count;
	const int32_t height = static_cast<int32_t>((texel_count + texture_width - 1) / texture_width);
	const int64_t padded_count = static_cast<int64_t>(height) * texture_width;

	PackedByteArray position_data;
	position_data.resize(padded_count * 8);
	PackedByteArray normal_data;
	normal_data.resize(padded_count * 8);
	uint8_t* const position_out = position_data.ptrw();
	uint8_t* const normal_out = normal_data.ptrw();
	std::memset(position_out, 0, static_cast<size_t>(padded_count * 8));
	std::memset(normal_out, 0, static_cast<size_t>(padded_count * 8));

	const Vector3* const position_in = positions.ptr();
	const Vector3* const normal_in = has_normals ? normals.ptr() : nullptr;
	const int32_t* const ids = bone_ids.ptr();
	const float* const weight_in = weights.ptr();
	const float* const matrix_in = skin_matrices.ptr();

	for (int32_t frame = 0; frame < frame_count; ++frame) {
		const float* const frame_matrices = matrix_in + static_cast<int64_t>(frame) * bone_count * 12;
		for (int64_t v = 0; v < vertex_count; ++v) {
			const Vector3 p = position_in[v];
			const Vector3 n = has_normals ? normal_in[v] : Vector3(0, 1, 0);
			float px = 0, py = 0, pz = 0, nx = 0, ny = 0, nz = 0, weight_sum = 0;
			for (int32_t i = 0; i < influences_per_vertex; ++i) {
				const float w = weight_in[v * influences_per_vertex + i];
				if (w <= 0.0f) {
					continue;
				}
				const int32_t bone = ids[v * influences_per_vertex + i];
				if (bone < 0 || bone >= bone_count) {
					continue;
				}
				const float* m = frame_matrices + bone * 12;
				px += w * (m[0] * p.x + m[3] * p.y + m[6] * p.z + m[9]);
				py += w * (m[1] * p.x + m[4] * p.y + m[7] * p.z + m[10]);
				pz += w * (m[2] * p.x + m[5] * p.y + m[8] * p.z + m[11]);
				nx += w * (m[0] * n.x + m[3] * n.y + m[6] * n.z);
				ny += w * (m[1] * n.x + m[4] * n.y + m[7] * n.z);
				nz += w * (m[2] * n.x + m[5] * n.y + m[8] * n.z);
				weight_sum += w;
			}
			if (weight_sum <= 0.0f) {
				// not skinned: stays where it is
				px = p.x;
				py = p.y;
				pz = p.z;
				nx = n.x;
				ny = n.y;
				nz = n.z;
			} else if (std::abs(weight_sum - 1.0f) > 1e-4f) {
				// Godot normalises the weights of a vertex
				const float inverse = 1.0f / weight_sum;
				px *= inverse;
				py *= inverse;
				pz *= inverse;
			}
			const float length = std::sqrt(nx * nx + ny * ny + nz * nz);
			if (length > 1e-8f) {
				nx /= length;
				ny /= length;
				nz /= length;
			}
			const int64_t texel = static_cast<int64_t>(frame) * vertex_count + v;
			write_texel(position_out + texel * 8, px, py, pz, 1.0f);
			write_texel(normal_out + texel * 8, nx, ny, nz, 0.0f);
		}
	}

	result["positions"] = Image::create_from_data(texture_width, height, false, Image::FORMAT_RGBAH, position_data);
	result["normals"] = Image::create_from_data(texture_width, height, false, Image::FORMAT_RGBAH, normal_data);
	result["width"] = texture_width;
	result["height"] = height;
	return result;
}

Ref<Image> VATBaker::bake_matrices(PackedFloat32Array const& matrices, const int32_t bone_count, const int32_t frame_count) {
	ERR_FAIL_COND_V(bone_count <= 0 || frame_count <= 0, Ref<Image>());
	ERR_FAIL_COND_V(matrices.size() < static_cast<int64_t>(frame_count) * bone_count * 12, Ref<Image>());
	const int32_t width = bone_count * 3;
	PackedByteArray data;
	data.resize(static_cast<int64_t>(width) * frame_count * 8);
	uint8_t* const out = data.ptrw();
	const float* const in = matrices.ptr();
	for (int32_t frame = 0; frame < frame_count; ++frame) {
		for (int32_t bone = 0; bone < bone_count; ++bone) {
			const float* m = in + (static_cast<int64_t>(frame) * bone_count + bone) * 12;
			uint8_t* texel = out + (static_cast<int64_t>(frame) * width + bone * 3) * 8;
			// the rows of the 3x4 matrix: (a row of the basis, the component of the origin)
			write_texel(texel + 0, m[0], m[3], m[6], m[9]);
			write_texel(texel + 8, m[1], m[4], m[7], m[10]);
			write_texel(texel + 16, m[2], m[5], m[8], m[11]);
		}
	}
	return Image::create_from_data(width, frame_count, false, Image::FORMAT_RGBAH, data);
}

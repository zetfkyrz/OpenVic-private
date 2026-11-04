// The lines of the fronts and of the plans of the field marshals on the map (docs/WAR_ASSUMPTIONS.md, section 6), part of PlayerSingleton: the
// pixel borders between pairs of provinces joined into polylines, what the tools of the plate of a marshal highlight and the commands of the lines
#include "PlayerSingleton.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include <openvic-simulation/DefinitionManager.hpp>
#include <openvic-simulation/InstanceManager.hpp>
#include <openvic-simulation/country/CountryInstance.hpp>
#include <openvic-simulation/country/CountryInstanceManager.hpp>
#include <openvic-simulation/map/MapDefinition.hpp>
#include <openvic-simulation/map/MapInstance.hpp>
#include <openvic-simulation/map/ProvinceInstance.hpp>
#include <openvic-simulation/military/ArmyGroup.hpp>
#include <openvic-simulation/military/UnitInstanceGroup.hpp>
#include <openvic-simulation/military/War.hpp>
#include <openvic-simulation/misc/GameAction.hpp>

#include "openvic-extension/core/Convert.hpp"
#include "openvic-extension/singletons/GameSingleton.hpp"
#include "openvic-extension/singletons/MenuSingleton.hpp"
#include "openvic-extension/utility/Utilities.hpp"

using namespace OpenVic;
using namespace godot;

namespace {
	std::vector<Vector2> simplify_polyline(std::vector<Vector2> const& points, const float epsilon) {
		if (points.size() < 3) {
			return points;
		}
		std::vector<bool> keep(points.size(), false);
		keep.front() = true;
		keep.back() = true;
		std::vector<std::pair<size_t, size_t>> stack;
		stack.emplace_back(0, points.size() - 1);
		while (!stack.empty()) {
			const auto [first, last] = stack.back();
			stack.pop_back();
			const Vector2 a = points[first];
			const Vector2 b = points[last];
			const Vector2 ab = b - a;
			const float length_squared = ab.length_squared();
			float max_distance = 0.0f;
			size_t max_index = first;
			for (size_t i = first + 1; i < last; ++i) {
				float distance = 0.0f;
				if (length_squared <= 0.0f) {
					distance = points[i].distance_to(a);
				} else {
					distance = std::abs((points[i] - a).cross(ab)) / std::sqrt(length_squared);
				}
				if (distance > max_distance) {
					max_distance = distance;
					max_index = i;
				}
			}
			if (max_distance > epsilon) {
				keep[max_index] = true;
				stack.emplace_back(first, max_index);
				stack.emplace_back(max_index, last);
			}
		}
		std::vector<Vector2> result;
		for (size_t i = 0; i < points.size(); ++i) {
			if (keep[i]) {
				result.push_back(points[i]);
			}
		}
		return result;
	}

	uint64_t pair_key(const uint32_t own, const uint32_t other) {
		return (static_cast<uint64_t>(own) << 32) | other;
	}

	uint32_t number_of(ProvinceInstance const& province) {
		return static_cast<uint32_t>(province.province_definition.get_province_number());
	}

	// The countries whose land touches the land the player controls
	bool touches(CountryInstance const& country, CountryInstance const& other, MapInstance const& map_instance) {
		for (ProvinceInstance const& province : map_instance.get_province_instances()) {
			if (province.get_controller() != &country || province.province_definition.is_water()) {
				continue;
			}
			for (ProvinceDefinition::adjacency_t const& adjacency : province.province_definition.get_adjacencies()) {
				if (adjacency.get_type() == ProvinceDefinition::adjacency_t::type_t::LAND
					&& map_instance.get_province_instance_by_definition(adjacency.get_to()).get_controller() == &other) {
					return true;
				}
			}
		}
		return false;
	}
}

std::vector<std::array<int32_t, 4>> const& PlayerSingleton::get_province_bounds() const {
	MapDefinition const& map_definition = GameSingleton::get_singleton()->get_definition_manager().get_map_definition();
	if (!province_bounds.empty()) {
		return province_bounds;
	}
	const int32_t width = map_definition.get_width();
	const int32_t height = map_definition.get_height();
	std::span<const MapDefinition::shape_pixel_t> const image = map_definition.get_province_shape_image();
	province_bounds.assign(map_definition.get_province_definition_count() + 1, { std::numeric_limits<int32_t>::max(), std::numeric_limits<int32_t>::max(), -1, -1 });
	if (width <= 0 || height <= 0 || image.size() < static_cast<size_t>(width) * static_cast<size_t>(height)) {
		return province_bounds;
	}
	for (int32_t y = 0; y < height; ++y) {
		for (int32_t x = 0; x < width; ++x) {
			const size_t number = image[static_cast<size_t>(y) * static_cast<size_t>(width) + static_cast<size_t>(x)].province_number;
			if (number < province_bounds.size()) {
				std::array<int32_t, 4>& bounds = province_bounds[number];
				bounds[0] = std::min(bounds[0], x);
				bounds[1] = std::min(bounds[1], y);
				bounds[2] = std::max(bounds[2], x);
				bounds[3] = std::max(bounds[3], y);
			}
		}
	}
	return province_bounds;
}

Array PlayerSingleton::make_border_polylines(std::vector<uint32_t> const& own_numbers, std::unordered_set<uint64_t> const& pairs) const {
	Array result;
	if (own_numbers.empty() || pairs.empty()) {
		return result;
	}
	MapDefinition const& map_definition = GameSingleton::get_singleton()->get_definition_manager().get_map_definition();
	const int32_t width = map_definition.get_width();
	const int32_t height = map_definition.get_height();
	std::span<const MapDefinition::shape_pixel_t> const image = map_definition.get_province_shape_image();
	ERR_FAIL_COND_V(width <= 0 || height <= 0 || image.size() < static_cast<size_t>(width) * static_cast<size_t>(height), result);
	std::vector<std::array<int32_t, 4>> const& bounds = get_province_bounds();

	struct segment_t {
		int64_t from, to;
	};
	const int64_t row = static_cast<int64_t>(width) + 1;
	const auto point_key = [row](const int32_t x, const int32_t y) -> int64_t {
		return static_cast<int64_t>(y) * row + x;
	};
	const auto number_at = [&](const int32_t x, const int32_t y) -> uint32_t {
		if (x < 0 || y < 0 || x >= width || y >= height) {
			return 0;
		}
		return image[static_cast<size_t>(y) * static_cast<size_t>(width) + static_cast<size_t>(x)].province_number;
	};
	// The pixel edges of every own province with a pixel of a province it is paired with
	std::vector<segment_t> segments;
	for (const uint32_t own : own_numbers) {
		if (own >= bounds.size() || bounds[own][2] < 0) {
			continue;
		}
		for (int32_t y = bounds[own][1]; y <= bounds[own][3]; ++y) {
			for (int32_t x = bounds[own][0]; x <= bounds[own][2]; ++x) {
				if (number_at(x, y) != own) {
					continue;
				}
				if (pairs.contains(pair_key(own, number_at(x + 1, y)))) {
					segments.push_back({ point_key(x + 1, y), point_key(x + 1, y + 1) });
				}
				if (pairs.contains(pair_key(own, number_at(x - 1, y)))) {
					segments.push_back({ point_key(x, y), point_key(x, y + 1) });
				}
				if (pairs.contains(pair_key(own, number_at(x, y + 1)))) {
					segments.push_back({ point_key(x, y + 1), point_key(x + 1, y + 1) });
				}
				if (pairs.contains(pair_key(own, number_at(x, y - 1)))) {
					segments.push_back({ point_key(x, y), point_key(x + 1, y) });
				}
			}
		}
	}
	if (segments.empty()) {
		return result;
	}

	// The segments joined into chains, simplified
	std::unordered_map<int64_t, std::vector<size_t>> at_point;
	for (size_t i = 0; i < segments.size(); ++i) {
		at_point[segments[i].from].push_back(i);
		at_point[segments[i].to].push_back(i);
	}
	std::vector<bool> used(segments.size(), false);
	const auto extend = [&](std::vector<int64_t>& chain, const bool at_end) {
		while (true) {
			const int64_t tip = at_end ? chain.back() : chain.front();
			size_t found = segments.size();
			for (const size_t candidate : at_point[tip]) {
				if (!used[candidate]) {
					found = candidate;
					break;
				}
			}
			if (found == segments.size()) {
				return;
			}
			used[found] = true;
			const int64_t other = segments[found].from == tip ? segments[found].to : segments[found].from;
			if (at_end) {
				chain.push_back(other);
			} else {
				chain.insert(chain.begin(), other);
			}
		}
	};
	const float map_width = static_cast<float>(width);
	const float map_height = static_cast<float>(height);
	for (size_t i = 0; i < segments.size(); ++i) {
		if (used[i]) {
			continue;
		}
		used[i] = true;
		std::vector<int64_t> chain { segments[i].from, segments[i].to };
		extend(chain, true);
		extend(chain, false);
		std::vector<Vector2> points;
		points.reserve(chain.size());
		for (const int64_t key : chain) {
			points.emplace_back(static_cast<float>(key % row), static_cast<float>(key / row));
		}
		points = simplify_polyline(points, 1.5f);
		if (points.size() < 2) {
			continue;
		}
		PackedVector2Array line;
		for (Vector2 const& point : points) {
			line.push_back(Vector2(point.x / map_width, point.y / map_height));
		}
		result.push_back(line);
	}
	return result;
}

Array PlayerSingleton::get_front_lines(int32_t front_id) const {
	Array result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	Front const* const front = instance_manager->get_war_manager().get_front_by_id(static_cast<uint32_t>(front_id));
	if (front == nullptr || front->country != player_country) {
		return result;
	}
	std::vector<uint32_t> own_numbers;
	std::unordered_set<uint64_t> pairs;
	for (FrontEdge const& edge : front->edges) {
		if (std::find(own_numbers.begin(), own_numbers.end(), number_of(*edge.own)) == own_numbers.end()) {
			own_numbers.push_back(number_of(*edge.own));
		}
		pairs.insert(pair_key(number_of(*edge.own), number_of(*edge.other)));
	}
	if (pairs.empty()) {
		// An automatic front of the earlier fronts: the border of its provinces with the land the country does not control
		MapInstance const& map_instance = instance_manager->get_map_instance();
		for (ProvinceInstance const* const province : front->provinces) {
			own_numbers.push_back(number_of(*province));
			for (ProvinceDefinition::adjacency_t const& adjacency : province->province_definition.get_adjacencies()) {
				ProvinceInstance const& other = map_instance.get_province_instance_by_definition(adjacency.get_to());
				if (!other.province_definition.is_water() && other.get_controller() != player_country) {
					pairs.insert(pair_key(number_of(*province), number_of(other)));
				}
			}
		}
	}
	return make_border_polylines(own_numbers, pairs);
}

Array PlayerSingleton::get_front_summaries() const {
	Array result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	UnitInstanceManager& unit_manager = instance_manager->get_unit_instance_manager();

	for (Front const& front : instance_manager->get_war_manager().get_fronts()) {
		if (front.country != player_country) {
			continue;
		}
		Dictionary entry;
		entry["id"] = static_cast<int32_t>(front.id);
		entry["mode"] = static_cast<int32_t>(front.mode);
		entry["kind"] = static_cast<int32_t>(front.kind);
		entry["enemy_index"] = front.enemy != nullptr ? static_cast<int32_t>(type_safe::get(front.enemy->index)) : -1;
		entry["sea_number"] = front.sea != nullptr ? static_cast<int32_t>(number_of(*front.sea)) : 0;
		entry["edited"] = front.edited;
		entry["army_count"] = static_cast<int32_t>(front.army_ids.size());
		entry["group_id"] = static_cast<int32_t>(front.group_id);
		entry["commanded"] = instance_manager->get_war_manager().is_front_commanded(front);
		int32_t divisions = 0;
		for (const unique_id_t army_id : front.army_ids) {
			UnitInstanceGroup const* const group = unit_manager.get_unit_instance_group_by_unique_id(army_id);
			if (group != nullptr && group->branch == unit_branch_t::LAND) {
				divisions += static_cast<int32_t>(static_cast<ArmyInstance const*>(group)->get_divisions().size());
			}
		}
		entry["division_count"] = divisions;
		PackedInt32Array province_numbers;
		for (ProvinceInstance const* const province : front.provinces) {
			province_numbers.push_back(static_cast<int32_t>(number_of(*province)));
		}
		entry["province_numbers"] = province_numbers;
		// The pieces of the line: own, other, own, other...
		PackedInt32Array edges;
		for (FrontEdge const& edge : front.edges) {
			edges.push_back(static_cast<int32_t>(number_of(*edge.own)));
			edges.push_back(static_cast<int32_t>(number_of(*edge.other)));
		}
		entry["edges"] = edges;
		result.push_back(entry);
	}
	return result;
}

Dictionary PlayerSingleton::get_border_highlights() const {
	Dictionary result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MapInstance const& map_instance = instance_manager->get_map_instance();
	MenuSingleton* const menu_singleton = MenuSingleton::get_singleton();

	// The pieces of the border of the land the player controls, by the country on the other side and by the sea
	struct group_t {
		std::vector<uint32_t> own_numbers;
		std::vector<uint32_t> other_numbers;
		std::unordered_set<uint64_t> pairs;
		PackedInt32Array edges; // own, other, own, other...
	};
	std::vector<std::pair<CountryInstance const*, group_t>> neighbours;
	std::vector<std::pair<ProvinceInstance const*, group_t>> seas;
	const auto add = [](group_t& group, const uint32_t own, const uint32_t other) {
		if (std::find(group.own_numbers.begin(), group.own_numbers.end(), own) == group.own_numbers.end()) {
			group.own_numbers.push_back(own);
		}
		if (std::find(group.other_numbers.begin(), group.other_numbers.end(), other) == group.other_numbers.end()) {
			group.other_numbers.push_back(other);
		}
		if (group.pairs.insert(pair_key(own, other)).second) {
			group.edges.push_back(static_cast<int32_t>(own));
			group.edges.push_back(static_cast<int32_t>(other));
		}
	};
	for (ProvinceInstance const& province : map_instance.get_province_instances()) {
		if (province.get_controller() != player_country || province.province_definition.is_water()) {
			continue;
		}
		for (ProvinceDefinition::adjacency_t const& adjacency : province.province_definition.get_adjacencies()) {
			ProvinceInstance const& other = map_instance.get_province_instance_by_definition(adjacency.get_to());
			if (adjacency.get_type() == ProvinceDefinition::adjacency_t::type_t::LAND && !other.province_definition.is_water()) {
				CountryInstance const* const controller = other.get_controller();
				if (controller == nullptr || controller == player_country) {
					continue;
				}
				auto it = std::find_if(neighbours.begin(), neighbours.end(), [controller](auto const& entry) -> bool {
					return entry.first == controller;
				});
				if (it == neighbours.end()) {
					neighbours.emplace_back(controller, group_t {});
					it = neighbours.end() - 1;
				}
				add(it->second, number_of(province), number_of(other));
			} else if (adjacency.get_type() == ProvinceDefinition::adjacency_t::type_t::COASTAL && other.province_definition.is_water()) {
				auto it = std::find_if(seas.begin(), seas.end(), [&other](auto const& entry) -> bool {
					return entry.first == &other;
				});
				if (it == seas.end()) {
					seas.emplace_back(&other, group_t {});
					it = seas.end() - 1;
				}
				add(it->second, number_of(province), number_of(other));
			}
		}
	}
	const auto numbers = [](std::vector<uint32_t> const& list) -> PackedInt32Array {
		PackedInt32Array array;
		for (const uint32_t number : list) {
			array.push_back(static_cast<int32_t>(number));
		}
		return array;
	};
	Array neighbour_entries;
	for (auto const& [country, group] : neighbours) {
		Dictionary entry;
		entry["country_index"] = static_cast<int32_t>(type_safe::get(country->index));
		entry["name"] = menu_singleton != nullptr ? Utilities::get_country_name(*menu_singleton, *country) : String();
		entry["at_war"] = player_country->is_at_war_with(*country);
		entry["own_numbers"] = numbers(group.own_numbers);
		entry["other_numbers"] = numbers(group.other_numbers);
		entry["edges"] = group.edges;
		entry["polylines"] = make_border_polylines(group.own_numbers, group.pairs);
		neighbour_entries.push_back(entry);
	}
	Array sea_entries;
	for (auto const& [sea, group] : seas) {
		Dictionary entry;
		entry["sea_number"] = static_cast<int32_t>(number_of(*sea));
		entry["own_numbers"] = numbers(group.own_numbers);
		entry["edges"] = group.edges;
		entry["polylines"] = make_border_polylines(group.own_numbers, group.pairs);
		sea_entries.push_back(entry);
	}
	result["neighbours"] = neighbour_entries;
	result["seas"] = sea_entries;
	return result;
}

PackedInt32Array PlayerSingleton::get_plan_candidates(int32_t type, int32_t group_id) const {
	PackedInt32Array result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MapInstance const& map_instance = instance_manager->get_map_instance();
	WarManager& war_manager = instance_manager->get_war_manager();
	// The countries an offensive aims at: the ones across the fronts of the field marshal (with the countries of their side in a war with the player);
	// a landing: the enemies and the neighbours of the player
	std::unordered_set<CountryInstance const*> aims;
	if (type == static_cast<int32_t>(PlanLine::type_t::OFFENSIVE) || type == static_cast<int32_t>(PlanLine::type_t::BREAKTHROUGH)) {
		for (Front const& front : war_manager.get_fronts()) {
			if (front.country != player_country || front.group_id != static_cast<uint32_t>(group_id) || front.kind != Front::kind_t::BORDER) {
				continue;
			}
			for (FrontEdge const& edge : front.edges) {
				CountryInstance const* const across = edge.other->get_controller();
				if (across == nullptr || across == player_country) {
					continue;
				}
				aims.insert(across);
				if (War* const war = war_manager.find_war_between(*player_country, *across); war != nullptr) {
					for (CountryInstance const* const ally : war->get_side(war->is_attacker(*across))) {
						aims.insert(ally);
					}
				}
			}
		}
	} else {
		for (CountryInstance const& country : instance_manager->get_country_instance_manager().get_country_instances()) {
			if (&country != player_country && country.exists() && (player_country->is_at_war_with(country) || touches(*player_country, country, map_instance))) {
				aims.insert(&country);
			}
		}
	}
	for (ProvinceInstance const& province : map_instance.get_province_instances()) {
		if (province.province_definition.is_water()) {
			continue;
		}
		CountryInstance const* const controller = province.get_controller();
		bool fits = false;
		switch (type) {
		case static_cast<int32_t>(PlanLine::type_t::OFFENSIVE):
		case static_cast<int32_t>(PlanLine::type_t::BREAKTHROUGH):
			fits = controller != player_country && aims.contains(controller);
			break;
		case static_cast<int32_t>(PlanLine::type_t::DEFENCE):
			fits = controller == player_country;
			break;
		case static_cast<int32_t>(PlanLine::type_t::NAVAL):
			// The ports of the player (where the landing starts) and the coast of the countries it aims at
			fits = (controller == player_country && province.province_definition.has_port())
				|| (controller != player_country && aims.contains(controller) && province.province_definition.is_coastal());
			break;
		default:
			break;
		}
		if (fits) {
			result.push_back(static_cast<int32_t>(number_of(province)));
		}
	}
	return result;
}

Array PlayerSingleton::get_plan_lines() const {
	Array result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	WarManager const& war_manager = instance_manager->get_war_manager();
	for (PlanLine const& line : war_manager.get_plan_lines()) {
		if (line.country != player_country) {
			continue;
		}
		Dictionary entry;
		entry["id"] = static_cast<int32_t>(line.id);
		entry["group_id"] = static_cast<int32_t>(line.group_id);
		entry["type"] = static_cast<int32_t>(line.type);
		entry["front_id"] = static_cast<int32_t>(line.front_id);
		entry["port_number"] = line.port != nullptr ? static_cast<int32_t>(number_of(*line.port)) : 0;
		PackedInt32Array province_numbers;
		for (ProvinceInstance const* const province : line.provinces) {
			province_numbers.push_back(static_cast<int32_t>(number_of(*province)));
		}
		entry["province_numbers"] = province_numbers;
		PackedInt32Array zone_numbers;
		if (line.type == PlanLine::type_t::OFFENSIVE) {
			for (ProvinceInstance const* const province : war_manager.get_offensive_zone(*instance_manager, line)) {
				zone_numbers.push_back(static_cast<int32_t>(number_of(*province)));
			}
		}
		entry["zone_numbers"] = zone_numbers;
		entry["division_count"] = static_cast<int32_t>(line.army_ids.size());
		result.push_back(entry);
	}
	return result;
}

Array PlayerSingleton::get_offensive_line(int32_t line_id) const {
	Array result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	WarManager const& war_manager = instance_manager->get_war_manager();
	PlanLine const* const line = war_manager.get_plan_line_by_id(static_cast<uint32_t>(line_id));
	if (line == nullptr || line->country != player_country || line->type != PlanLine::type_t::OFFENSIVE) {
		return result;
	}
	// The far border of the targets: with the land that is neither a target, nor in the zone, nor ours
	MapInstance const& map_instance = instance_manager->get_map_instance();
	const memory::vector<ProvinceInstance*> zone = war_manager.get_offensive_zone(*instance_manager, *line);
	std::vector<uint32_t> own_numbers;
	std::unordered_set<uint64_t> pairs;
	for (ProvinceInstance const* const target : line->provinces) {
		own_numbers.push_back(number_of(*target));
		for (ProvinceDefinition::adjacency_t const& adjacency : target->province_definition.get_adjacencies()) {
			ProvinceInstance const& other = map_instance.get_province_instance_by_definition(adjacency.get_to());
			const bool inside = std::find(zone.begin(), zone.end(), &other) != zone.end()
				|| std::find(line->provinces.begin(), line->provinces.end(), &other) != line->provinces.end();
			if (!inside && other.get_controller() != player_country) {
				pairs.insert(pair_key(number_of(*target), number_of(other)));
			}
		}
	}
	return make_border_polylines(own_numbers, pairs);
}

// The commands of the lines
namespace {
	ProvinceInstance const* province_by_number(InstanceManager& instance_manager, const int32_t number) {
		return instance_manager.get_map_instance().get_province_instance_from_number(number);
	}
}

bool PlayerSingleton::create_border_front(int32_t group_id, int32_t country_index) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(
		group_id < 0 || country_index < 0
			|| static_cast<size_t>(country_index) >= instance_manager->get_country_instance_manager().get_country_instances().size(),
		false
	);
	return instance_manager->queue_game_action<create_border_front_argument_t>(
		player_country->index, static_cast<uint32_t>(group_id), country_index_t(static_cast<uint32_t>(country_index))
	);
}

bool PlayerSingleton::create_coastal_front(int32_t group_id, int32_t sea_number) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ProvinceInstance const* const sea = province_by_number(*instance_manager, sea_number);
	ERR_FAIL_COND_V(group_id < 0 || sea == nullptr, false);
	return instance_manager->queue_game_action<create_coastal_front_argument_t>(player_country->index, static_cast<uint32_t>(group_id), sea->index);
}

bool PlayerSingleton::create_border_front_part(int32_t group_id, int32_t country_index, int32_t from_number, int32_t to_number) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ProvinceInstance const* const from = province_by_number(*instance_manager, from_number);
	ProvinceInstance const* const to = province_by_number(*instance_manager, to_number);
	ERR_FAIL_COND_V(
		group_id < 0 || country_index < 0 || from == nullptr || to == nullptr
			|| static_cast<size_t>(country_index) >= instance_manager->get_country_instance_manager().get_country_instances().size(),
		false
	);
	return instance_manager->queue_game_action<create_border_front_part_argument_t>(
		player_country->index, static_cast<uint32_t>(group_id), country_index_t(static_cast<uint32_t>(country_index)), from->index, to->index
	);
}

Array PlayerSingleton::get_border_part_lines(int32_t country_index, int32_t from_number, int32_t to_number) const {
	Array result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	CountryInstanceManager& countries = instance_manager->get_country_instance_manager();
	ERR_FAIL_COND_V(country_index < 0 || static_cast<size_t>(country_index) >= countries.get_country_instances().size(), result);
	CountryInstance const& neighbour = countries.get_country_instance_by_index(country_index_t(static_cast<uint32_t>(country_index)));
	ProvinceInstance const* const from = province_by_number(*instance_manager, from_number);
	ProvinceInstance const* const to = province_by_number(*instance_manager, to_number);
	std::vector<uint32_t> own_numbers;
	std::unordered_set<uint64_t> pairs;
	for (FrontEdge const& edge : instance_manager->get_war_manager().get_border_part(*instance_manager, *player_country, neighbour, from, to)) {
		if (std::find(own_numbers.begin(), own_numbers.end(), number_of(*edge.own)) == own_numbers.end()) {
			own_numbers.push_back(number_of(*edge.own));
		}
		pairs.insert(pair_key(number_of(*edge.own), number_of(*edge.other)));
	}
	return make_border_polylines(own_numbers, pairs);
}

bool PlayerSingleton::toggle_front_edge(int32_t front_id, int32_t own_number, int32_t other_number) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ProvinceInstance const* const own = province_by_number(*instance_manager, own_number);
	ProvinceInstance const* const other = province_by_number(*instance_manager, other_number);
	ERR_FAIL_COND_V(front_id <= 0 || own == nullptr || other == nullptr, false);
	return instance_manager->queue_game_action<toggle_front_edge_argument_t>(player_country->index, static_cast<uint32_t>(front_id), own->index, other->index);
}

bool PlayerSingleton::create_plan_line(int32_t group_id, int32_t type, int32_t province_number) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ProvinceInstance const* const province = province_by_number(*instance_manager, province_number);
	ERR_FAIL_COND_V(group_id <= 0 || type < 0 || province == nullptr, false);
	return instance_manager->queue_game_action<create_plan_line_argument_t>(
		player_country->index, static_cast<uint32_t>(group_id), static_cast<uint32_t>(type), province->index
	);
}

bool PlayerSingleton::toggle_plan_line_province(int32_t line_id, int32_t province_number) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ProvinceInstance const* const province = province_by_number(*instance_manager, province_number);
	ERR_FAIL_COND_V(line_id <= 0 || province == nullptr, false);
	return instance_manager->queue_game_action<toggle_plan_line_province_argument_t>(player_country->index, static_cast<uint32_t>(line_id), province->index);
}

bool PlayerSingleton::extend_plan_line(int32_t line_id, bool at_end, int32_t province_number) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ProvinceInstance const* const province = province_by_number(*instance_manager, province_number);
	ERR_FAIL_COND_V(line_id <= 0 || province == nullptr, false);
	return instance_manager->queue_game_action<extend_plan_line_argument_t>(player_country->index, static_cast<uint32_t>(line_id), at_end, province->index);
}

bool PlayerSingleton::delete_plan_line(int32_t line_id) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(line_id <= 0, false);
	return instance_manager->queue_game_action<delete_plan_line_argument_t>(player_country->index, static_cast<uint32_t>(line_id));
}

bool PlayerSingleton::delete_group_lines(int32_t group_id) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(group_id <= 0, false);
	return instance_manager->queue_game_action<delete_group_lines_argument_t>(player_country->index, static_cast<uint32_t>(group_id));
}

bool PlayerSingleton::set_army_group_modes(int32_t group_id, int32_t aggression, int32_t integrity) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* const instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(group_id <= 0 || aggression < 1 || aggression > 3 || integrity < 0 || integrity > 2, false);
	return instance_manager->queue_game_action<set_army_group_modes_argument_t>(
		player_country->index, static_cast<uint32_t>(group_id), static_cast<uint32_t>(aggression), static_cast<uint32_t>(integrity)
	);
}

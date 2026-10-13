#include "PlayerSingleton.hpp"

#include <algorithm>
#include <vector>

#include <openvic-simulation/core/FormatValidate.hpp>
#include <openvic-simulation/DefinitionManager.hpp>
#include <openvic-simulation/InstanceManager.hpp>
#include <openvic-simulation/country/CountryInstance.hpp>
#include <openvic-simulation/diplomacy/CountryRelation.hpp>
#include <openvic-simulation/diplomacy/DiplomaticAction.hpp>
#include <openvic-simulation/politics/Government.hpp>
#include <openvic-simulation/map/ProvinceInstance.hpp>
#include <openvic-simulation/misc/GameAction.hpp>
#include <openvic-simulation/types/TypedIndices.hpp>

#include "openvic-extension/classes/GUIScrollbar.hpp"
#include "openvic-extension/core/Bind.hpp"
#include "openvic-extension/core/Convert.hpp"
#include "openvic-extension/singletons/GameSingleton.hpp"
#include "openvic-extension/singletons/MenuSingleton.hpp"
#include "openvic-extension/utility/Utilities.hpp"

using namespace OpenVic;
using namespace godot;

/* StringNames cannot be constructed until Godot has called StringName::setup(),
 * so we must use these wrapper functions to delay their initialisation. */
StringName const& PlayerSingleton::_signal_province_selected() {
	static const StringName signal_province_selected = "province_selected";
	return signal_province_selected;
}

void PlayerSingleton::_bind_methods() {
	OV_BIND_METHOD(PlayerSingleton::reset_player_singleton);

	// Player country
	OV_BIND_METHOD(PlayerSingleton::set_player_country_by_province_number, { "province_number" });
	OV_BIND_METHOD(PlayerSingleton::get_player_country_capital_position);
	OV_BIND_METHOD(PlayerSingleton::get_player_country_identifier);
	OV_BIND_METHOD(PlayerSingleton::get_player_country_name);

	// Selected province
	OV_BIND_METHOD(PlayerSingleton::set_selected_province_by_number, { "province_number" });
	OV_BIND_METHOD(PlayerSingleton::unset_selected_province);
	OV_BIND_METHOD(PlayerSingleton::get_selected_province_number);

	// Core
	OV_BIND_METHOD(PlayerSingleton::toggle_paused);
	OV_BIND_METHOD(PlayerSingleton::increase_speed);
	OV_BIND_METHOD(PlayerSingleton::decrease_speed);

	// Production
	OV_BIND_METHOD(PlayerSingleton::expand_selected_province_building, { "building_index" });

	// Budget

	// Technology

	// Politics

	// Population

	// Trade
	OV_BIND_METHOD(PlayerSingleton::set_good_automated, { "good_index", "is_automated" });
	OV_BIND_METHOD(PlayerSingleton::set_good_trade_order, { "good_index", "is_selling", "amount_slider" });

	// Diplomacy

	// Military
	OV_BIND_METHOD(PlayerSingleton::create_leader, { "is_general" });
	OV_BIND_METHOD(PlayerSingleton::set_can_use_leader, { "leader_id", "can_use" });
	OV_BIND_METHOD(PlayerSingleton::set_auto_create_leaders, { "value" });
	OV_BIND_METHOD(PlayerSingleton::set_auto_assign_leaders, { "value" });
	OV_BIND_METHOD(PlayerSingleton::set_mobilise, { "value" });

	OV_BIND_METHOD(PlayerSingleton::get_diplomatic_action_identifiers);
	OV_BIND_METHOD(PlayerSingleton::get_diplomacy_country_list);
	OV_BIND_METHOD(PlayerSingleton::get_diplomatic_relation, { "country_index" });
	OV_BIND_METHOD(PlayerSingleton::send_diplomatic_action, { "receiver_country_index", "action_index" });

	ADD_SIGNAL(MethodInfo(_signal_province_selected(), PropertyInfo(Variant::INT, "index")));
}

PlayerSingleton* PlayerSingleton::get_singleton() {
	return singleton;
}

PlayerSingleton::PlayerSingleton() {
	ERR_FAIL_COND(singleton != nullptr);
	singleton = this;
}

PlayerSingleton::~PlayerSingleton() {
	ERR_FAIL_COND(singleton != this);
	singleton = nullptr;
}

void PlayerSingleton::reset_player_singleton() {
	// This function is called when a game session ends, so we don't use functions like set_player_country or
	// unset_selected_province here as they can dereference leftover pointers from the previous game session which
	// are either already or soon to be invalid.
	player_country = nullptr;
	selected_province = nullptr;
}

// Player country
void PlayerSingleton::set_player_country(CountryInstance* new_player_country) {
	if (OV_unlikely(player_country == new_player_country)) {
		return;
	}

	GameSingleton& game_singleton = *GameSingleton::get_singleton();
	InstanceManager* instance_manager = game_singleton.get_instance_manager();
	ERR_FAIL_NULL(instance_manager);

	if (player_country != nullptr) {
		instance_manager->queue_game_action<set_ai_argument_t>(player_country->index, true);
	}

	player_country = new_player_country;

	if (player_country != nullptr) {
		instance_manager->queue_game_action<set_ai_argument_t>(player_country->index, false);
	}

	SPDLOG_INFO("Set player country to: {}", ovfmt::validate(player_country));

	game_singleton._on_gamestate_updated();
}

void PlayerSingleton::set_player_country_by_province_number(int32_t province_number) {
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL(instance_manager);

	ProvinceInstance* province_instance = instance_manager->get_map_instance().get_province_instance_from_number(
	    province_number
	);
	ERR_FAIL_NULL(province_instance);

	// Sea and unowned provinces do not change the player country
	CountryInstance* owner = province_instance->get_owner();
	if (owner == nullptr) {
		return;
	}

	set_player_country(owner);
}

String PlayerSingleton::get_player_country_identifier() const {
	if (player_country == nullptr) {
		return {};
	}
	return convert_to<String>(player_country->get_identifier());
}

String PlayerSingleton::get_player_country_name() const {
	MenuSingleton const* menu_singleton = MenuSingleton::get_singleton();
	if (player_country == nullptr || menu_singleton == nullptr) {
		return {};
	}
	return Utilities::get_country_name(*menu_singleton, *player_country);
}

Vector2 PlayerSingleton::get_player_country_capital_position() const {
	if (player_country != nullptr) {
		ProvinceInstance const* capital = player_country->get_capital();

		if (capital != nullptr) {
			return GameSingleton::get_singleton()->get_billboard_pos(capital->province_definition);
		}
	}

	return {};
}

// Selected province
void PlayerSingleton::set_selected_province(ProvinceInstance const* new_selected_province) {
	if (selected_province != new_selected_province) {
		selected_province = new_selected_province;

		GameSingleton::get_singleton()->_update_colour_image();

		emit_signal(_signal_province_selected(), get_selected_province_number());
	}
}

void PlayerSingleton::set_selected_province_by_number(int32_t province_number) {
	if (province_number == ProvinceDefinition::NULL_PROVINCE_NUMBER) {
		unset_selected_province();
	} else {
		InstanceManager const* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
		ERR_FAIL_NULL(instance_manager);

		MapInstance const& map_instance = instance_manager->get_map_instance();

		set_selected_province(map_instance.get_province_instance_from_number(province_number));

		if (selected_province == nullptr) {
			spdlog::error_s(
			    "Trying to set selected province to an invalid number {} (max number is {})",
			    map_instance.get_province_instance_by_definition().get_count(),
			    province_number
			);
		}
	}
}

void PlayerSingleton::unset_selected_province() {
	set_selected_province(nullptr);
}

int32_t PlayerSingleton::get_selected_province_number() const {
	return selected_province == nullptr
	         ? ProvinceDefinition::NULL_PROVINCE_NUMBER
	         : selected_province->province_definition.get_province_number();
}

// Core
void PlayerSingleton::toggle_paused() const {
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL(instance_manager);

	instance_manager->queue_game_action<set_pause_argument_t>(!instance_manager->get_simulation_clock().is_paused());
}

void PlayerSingleton::increase_speed() const {
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL(instance_manager);

	instance_manager->queue_game_action<set_speed_argument_t>(
	    instance_manager->get_simulation_clock().get_simulation_speed() + 1
	);
}

void PlayerSingleton::decrease_speed() const {
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL(instance_manager);

	instance_manager->queue_game_action<set_speed_argument_t>(
	    instance_manager->get_simulation_clock().get_simulation_speed() - 1
	);
}

// Production
void PlayerSingleton::expand_selected_province_building(int32_t province_building_index) const {
	ERR_FAIL_NULL(selected_province);

	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL(instance_manager);
	ERR_FAIL_NULL(player_country);

	instance_manager->queue_game_action<expand_province_building_argument_t>(
	    player_country->index, selected_province->index, province_building_index_t(province_building_index)
	);
}

// Budget
#define SET_SLIDER_GAME_ACTION_EXPLICIT(value_name, argument_name) \
	void PlayerSingleton::set_##value_name##_slider_value(fixed_point_t const value) const { \
		if (player_country == nullptr) { \
			return; \
		} \
		GameSingleton::get_singleton()->get_instance_manager()->queue_game_action<set_##argument_name##_argument_t>( \
		    player_country->index, value \
		); \
	}
#define SET_SLIDER_GAME_ACTION(value_name) SET_SLIDER_GAME_ACTION_EXPLICIT(value_name, value_name)

SET_SLIDER_GAME_ACTION(administration_spending)
SET_SLIDER_GAME_ACTION(education_spending)
SET_SLIDER_GAME_ACTION(military_spending)
SET_SLIDER_GAME_ACTION(social_spending)
SET_SLIDER_GAME_ACTION_EXPLICIT(national_stockpile_army_spending, army_spending)
SET_SLIDER_GAME_ACTION_EXPLICIT(national_stockpile_navy_spending, navy_spending)
SET_SLIDER_GAME_ACTION_EXPLICIT(national_stockpile_construction_spending, construction_spending)
SET_SLIDER_GAME_ACTION(tariff_rate)

#undef SET_SLIDER_GAME_ACTION

void PlayerSingleton::set_strata_tax_rate_slider_value(Strata const& strata, fixed_point_t const value) const {
	if (player_country == nullptr) {
		return;
	}
	GameSingleton::get_singleton()->get_instance_manager()->queue_game_action<set_strata_tax_argument_t>(
	    player_country->index, strata.index, value
	);
}

// Technology

// Politics

// Population

// Trade
void PlayerSingleton::set_good_automated(int32_t good_index, bool is_automated) const {
	ERR_FAIL_NULL(player_country);

	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL(instance_manager);

	instance_manager->queue_game_action<set_good_automated_argument_t>(
	    player_country->index, good_index_t(good_index), is_automated
	);
}

void PlayerSingleton::set_good_trade_order(int32_t good_index, bool is_selling, GUIScrollbar const* amount_slider) const {
	ERR_FAIL_NULL(amount_slider);
	ERR_FAIL_NULL(player_country);

	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL(instance_manager);

	instance_manager->queue_game_action<set_good_trade_order_argument_t>(
	    player_country->index,
	    good_index_t(good_index),
	    is_selling,
	    MenuSingleton::calculate_trade_menu_stockpile_cutoff_amount_fp(amount_slider->get_value_scaled_fp())
	);
}

// Diplomacy

// Military
void PlayerSingleton::create_leader(bool is_general) const {
	ERR_FAIL_NULL(player_country);

	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL(instance_manager);

	instance_manager->queue_game_action<create_leader_argument_t>(
	    player_country->index, is_general ? unit_branch_t::LAND : unit_branch_t::NAVAL
	);
}

void PlayerSingleton::set_can_use_leader(uint64_t leader_id, bool can_use) const {
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL(instance_manager);

	instance_manager->queue_game_action<set_use_leader_argument_t>(unique_id_t(leader_id), can_use);
}

void PlayerSingleton::set_auto_create_leaders(bool value) const {
	ERR_FAIL_NULL(player_country);

	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL(instance_manager);

	instance_manager->queue_game_action<set_auto_create_leaders_argument_t>(player_country->index, value);
}

void PlayerSingleton::set_auto_assign_leaders(bool value) const {
	ERR_FAIL_NULL(player_country);

	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL(instance_manager);

	instance_manager->queue_game_action<set_auto_assign_leaders_argument_t>(player_country->index, value);
}

void PlayerSingleton::set_mobilise(bool value) const {
	ERR_FAIL_NULL(player_country);

	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL(instance_manager);

	instance_manager->queue_game_action<set_mobilise_argument_t>(player_country->index, value);
}

// Diplomacy
PackedStringArray PlayerSingleton::get_diplomatic_action_identifiers() const {
	PackedStringArray result;

	GameSingleton const* game_singleton = GameSingleton::get_singleton();
	ERR_FAIL_NULL_V(game_singleton, result);

	for (auto const& action_type : game_singleton->get_definition_manager().get_diplomatic_action_manager().get_diplomatic_action_types()) {
		result.push_back(convert_to<String>(action_type.get_identifier()));
	}

	return result;
}

Array PlayerSingleton::get_diplomacy_country_list() const {
	Array result;

	GameSingleton const* game_singleton = GameSingleton::get_singleton();
	ERR_FAIL_NULL_V(game_singleton, result);
	InstanceManager const* instance_manager = game_singleton->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MenuSingleton const* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, result);

	static const StringName index_key = "index";
	static const StringName identifier_key = "identifier";
	static const StringName name_key = "name";
	static const StringName government_key = "government";
	static const StringName prestige_key = "prestige";
	static const StringName prestige_rank_key = "prestige_rank";
	static const StringName industrial_power_key = "industrial_power";
	static const StringName industrial_rank_key = "industrial_rank";
	static const StringName military_power_key = "military_power";
	static const StringName military_rank_key = "military_rank";
	static const StringName total_rank_key = "total_rank";
	static const StringName population_key = "population";
	static const StringName relation_key = "relation";
	static const StringName opinion_key = "opinion";

	CountryRelationManager const& relations = instance_manager->get_country_relation_manager();

	std::vector<std::pair<String, Dictionary>> entries;

	for (CountryInstance const& country : instance_manager->get_country_instance_manager().get_country_instances()) {
		if (&country == player_country || !country.exists() || country.get_capital() == nullptr) {
			continue;
		}

		String name = Utilities::get_country_name(*menu_singleton, country);

		Dictionary entry;
		entry[index_key] = static_cast<int32_t>(type_safe::get(country.index));
		entry[identifier_key] = convert_to<String>(country.get_identifier());
		entry[name_key] = name;

		GovernmentType const* government_type = country.get_government_type_untracked();
		entry[government_key] =
		    government_type != nullptr ? menu_singleton->tr(convert_to<String>(government_type->get_identifier())) : String {};

		entry[prestige_key] = static_cast<float>(country.get_prestige_untracked());
		entry[prestige_rank_key] = static_cast<int32_t>(country.get_prestige_rank());
		entry[industrial_power_key] = static_cast<float>(country.get_industrial_power_untracked());
		entry[industrial_rank_key] = static_cast<int32_t>(country.get_industrial_rank());
		entry[military_power_key] = static_cast<float>(
		    country.get_military_power_from_land_untracked() + country.get_military_power_from_sea_untracked() +
		    country.get_military_power_from_leaders_untracked()
		);
		entry[military_rank_key] = static_cast<int32_t>(country.get_military_rank());
		entry[total_rank_key] = static_cast<int32_t>(country.get_total_rank());
		entry[population_key] = static_cast<int64_t>(country.get_total_population());

		if (player_country != nullptr) {
			entry[relation_key] = static_cast<int32_t>(relations.get_country_relation(player_country, &country));
			entry[opinion_key] = menu_singleton->tr(convert_to<String>(
			    CountryRelationManager::get_opinion_identifier(relations.get_country_opinion(player_country, &country))
			));
		}

		entries.emplace_back(std::move(name), std::move(entry));
	}

	std::sort(entries.begin(), entries.end(), [](auto const& a, auto const& b) -> bool {
		return a.first < b.first;
	});

	result.resize(entries.size());
	for (size_t i = 0; i < entries.size(); ++i) {
		result[i] = entries[i].second;
	}

	return result;
}

Dictionary PlayerSingleton::get_diplomatic_relation(int32_t country_index) const {
	Dictionary result;

	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);

	CountryInstanceManager& country_manager = instance_manager->get_country_instance_manager();
	ERR_FAIL_COND_V(country_index < 0 || static_cast<size_t>(country_index) >= country_manager.get_country_instances().size(), result);

	CountryInstance* other = &country_manager.get_country_instance_by_index(country_index_t(static_cast<uint32_t>(country_index)));
	CountryInstance* player = player_country;
	CountryRelationManager const& relations = instance_manager->get_country_relation_manager();

	const CountryRelationManager::OpinionType opinion = relations.get_country_opinion(player, other);

	result["relation"] = static_cast<int32_t>(relations.get_country_relation(player, other));
	result["opinion"] = static_cast<int32_t>(opinion);
	result["opinion_identifier"] = convert_to<String>(CountryRelationManager::get_opinion_identifier(opinion));
	result["influence"] = static_cast<int32_t>(static_cast<uint16_t>(relations.get_influence_with(player, other)));
	result["allied"] = relations.get_country_alliance(player, other);
	result["at_war"] = relations.get_at_war_with(player, other);
	result["we_have_military_access"] = relations.get_has_military_access_to(player, other);
	result["they_have_military_access"] = relations.get_has_military_access_to(other, player);
	result["we_subsidise"] = relations.get_war_subsidies_to(player, other);
	result["they_subsidise"] = relations.get_war_subsidies_to(other, player);
	result["we_have_vision"] = relations.get_has_vision(player, other);
	result["they_have_vision"] = relations.get_has_vision(other, player);

	return result;
}

bool PlayerSingleton::send_diplomatic_action(int32_t receiver_country_index, int32_t action_index) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);

	ERR_FAIL_COND_V(receiver_country_index < 0, false);
	ERR_FAIL_COND_V(action_index < 0, false);
	ERR_FAIL_COND_V(
	    static_cast<size_t>(receiver_country_index) >= instance_manager->get_country_instance_manager().get_country_instances().size(),
	    false
	);

	return instance_manager->queue_game_action<diplomatic_action_argument_t>(
	    player_country->index,
	    country_index_t(static_cast<uint32_t>(receiver_country_index)),
	    static_cast<uint32_t>(action_index)
	);
}

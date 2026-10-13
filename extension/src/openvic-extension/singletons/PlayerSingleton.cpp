#include "PlayerSingleton.hpp"

#include <algorithm>
#include <vector>

#include <openvic-simulation/core/FormatValidate.hpp>
#include <openvic-simulation/DefinitionManager.hpp>
#include <openvic-simulation/InstanceManager.hpp>
#include <openvic-simulation/country/CountryInstance.hpp>
#include <openvic-simulation/diplomacy/CountryRelation.hpp>
#include <openvic-simulation/diplomacy/DiplomaticAction.hpp>
#include <openvic-simulation/economy/BuildingType.hpp>
#include <openvic-simulation/economy/production/FactoryInstance.hpp>
#include <openvic-simulation/economy/production/ProductionType.hpp>
#include <openvic-simulation/economy/trading/MarketInstance.hpp>
#include <openvic-simulation/map/State.hpp>
#include <openvic-simulation/politics/Government.hpp>
#include <openvic-simulation/research/ResearchManager.hpp>
#include <openvic-simulation/research/Technology.hpp>
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

	OV_BIND_METHOD(PlayerSingleton::get_production_info);
	OV_BIND_METHOD(PlayerSingleton::build_factory, { "province_index", "building_type_index" });
	OV_BIND_METHOD(PlayerSingleton::set_factory_open, { "province_index", "building_type_index", "open" });

	OV_BIND_METHOD(PlayerSingleton::get_technology_info);
	OV_BIND_METHOD(PlayerSingleton::start_research, { "technology_index" });

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

// Technology
Dictionary PlayerSingleton::get_technology_info() const {
	Dictionary result;

	ERR_FAIL_NULL_V(player_country, result);
	GameSingleton const* game_singleton = GameSingleton::get_singleton();
	ERR_FAIL_NULL_V(game_singleton, result);
	InstanceManager const* instance_manager = game_singleton->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MenuSingleton const* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, result);

	TechnologyManager const& technology_manager =
	    game_singleton->get_definition_manager().get_research_manager().get_technology_manager();
	const Date today = instance_manager->get_today();
	Technology const* current_research = player_country->get_current_research_untracked();

	Array folders;
	for (TechnologyFolder const& folder : technology_manager.get_technology_folders()) {
		Array areas;
		int32_t total_count = 0, researched_count = 0;

		for (TechnologyArea const& area : folder.get_technology_areas()) {
			Array technologies;

			for (Technology const& technology : area.get_technologies()) {
				int32_t status = 0;
				if (player_country->is_technology_unlocked(technology)) {
					status = 2;
					researched_count++;
				} else if (&technology == current_research) {
					status = 3;
				} else if (player_country->can_research_tech(technology, today)) {
					status = 1;
				}
				total_count++;

				const String identifier = convert_to<String>(technology.get_identifier());

				Dictionary technology_dict;
				technology_dict["index"] = static_cast<int32_t>(type_safe::get(technology.index));
				technology_dict["identifier"] = identifier;
				technology_dict["name"] = menu_singleton->tr(identifier);
				technology_dict["description"] = menu_singleton->tr(identifier + String("_desc"));
				technology_dict["year"] = static_cast<int32_t>(technology.year);
				technology_dict["cost"] = static_cast<float>(player_country->calculate_research_cost(technology));
				technology_dict["status"] = status;
				technology_dict["position"] = static_cast<int32_t>(technology.index_in_area);
				technologies.push_back(std::move(technology_dict));
			}

			const String area_identifier = convert_to<String>(area.get_identifier());

			Dictionary area_dict;
			area_dict["identifier"] = area_identifier;
			area_dict["name"] = menu_singleton->tr(area_identifier);
			area_dict["technologies"] = std::move(technologies);
			areas.push_back(std::move(area_dict));
		}

		const String folder_identifier = convert_to<String>(folder.get_identifier());

		Dictionary folder_dict;
		folder_dict["index"] = static_cast<int32_t>(type_safe::get(folder.index));
		folder_dict["identifier"] = folder_identifier;
		folder_dict["name"] = menu_singleton->tr(folder_identifier);
		folder_dict["researched_count"] = researched_count;
		folder_dict["total_count"] = total_count;
		folder_dict["areas"] = std::move(areas);
		folders.push_back(std::move(folder_dict));
	}
	result["folders"] = std::move(folders);

	if (current_research != nullptr) {
		const String identifier = convert_to<String>(current_research->get_identifier());
		const float cost = static_cast<float>(player_country->get_current_research_cost_untracked());
		const float invested = static_cast<float>(player_country->get_invested_research_points_untracked());

		Dictionary current;
		current["index"] = static_cast<int32_t>(type_safe::get(current_research->index));
		current["name"] = menu_singleton->tr(identifier);
		current["category"] = menu_singleton->tr(convert_to<String>(current_research->area.get_identifier()));
		current["cost"] = cost;
		current["invested"] = invested;
		current["progress"] = cost > 0.0f ? invested / cost : 0.0f;
		current["expected_completion"] =
		    convert_to<String>(player_country->get_expected_research_completion_date_untracked().to_string());
		result["current"] = std::move(current);
	}

	result["daily_research_points"] = static_cast<float>(player_country->get_daily_research_points_untracked());
	result["research_point_stockpile"] = static_cast<float>(player_country->get_research_point_stockpile_untracked());

	TechnologySchool const* school = player_country->get_tech_school_untracked();
	result["school"] = school != nullptr ? menu_singleton->tr(convert_to<String>(school->get_identifier())) : String {};

	return result;
}

bool PlayerSingleton::start_research(int32_t technology_index) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(technology_index < 0, false);

	return instance_manager->queue_game_action<start_research_argument_t>(
	    player_country->index, technology_index_t(static_cast<uint32_t>(technology_index))
	);
}

// Production
Array PlayerSingleton::get_production_info() const {
	Array result;

	ERR_FAIL_NULL_V(player_country, result);
	GameSingleton const* game_singleton = GameSingleton::get_singleton();
	ERR_FAIL_NULL_V(game_singleton, result);
	InstanceManager const* instance_manager = game_singleton->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MenuSingleton const* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, result);

	MarketInstance const& market_instance = instance_manager->get_market_instance();
	const Date today = instance_manager->get_today();
	const fixed_point_t cash = player_country->get_cash_stockpile().load();

	BuildingTypeManager const& building_type_manager =
	    game_singleton->get_definition_manager().get_economy_manager().get_building_type_manager();

	// Factory types the player can build, with their current cost
	struct FactoryTypeInfo {
		BuildingType const* building_type;
		fixed_point_t cost;
	};
	std::vector<FactoryTypeInfo> factory_types;
	for (BuildingType const& building_type : building_type_manager.get_building_types()) {
		ProductionType const* production_type = building_type.production_type;
		if (production_type != nullptr && production_type->template_type == ProductionType::template_type_t::FACTORY &&
		    player_country->is_building_type_unlocked(building_type)) {
			factory_types.push_back(
			    { &building_type, FactoryInstance::calculate_construction_cost(building_type, market_instance) }
			);
		}
	}

	for (StateSet const& state_set : instance_manager->get_map_instance().get_state_manager().get_state_sets()) {
		for (State const& state : state_set.get_states()) {
			if (state.get_owner() != player_country || state.get_capital() == nullptr) {
				continue;
			}

			const bool has_free_slot = state.has_free_factory_slot();

			Array factories;
			for (FactoryInstance const& factory : state.get_factories()) {
				BuildingType const& building_type = factory.building_type;
				const String identifier = convert_to<String>(building_type.get_identifier());

				Dictionary factory_dict;
				factory_dict["building_type_index"] = static_cast<int32_t>(type_safe::get(building_type.index));
				factory_dict["identifier"] = identifier;
				factory_dict["name"] = menu_singleton->tr(identifier);
				factory_dict["output_good"] =
				    menu_singleton->tr(convert_to<String>(factory.production_type.output_good.get_identifier()));
				factory_dict["output_good_index"] =
				    static_cast<int32_t>(type_safe::get(factory.production_type.output_good.index));

				const int32_t level_value = static_cast<int32_t>(type_safe::get(factory.get_level()));
				const int32_t max_employees_for_input = static_cast<int32_t>(type_safe::get(factory.get_max_employee_count()));
				Array factory_inputs;
				for (FactoryInstance::Input const& input : factory.get_inputs()) {
					// What the factory needs for a day at its current employment and throttle
					const fixed_point_t needed = input.quantity_per_level * std::max(level_value, 1);
					const fixed_point_t needed_now = needed * factory.get_throttle() *
					    (max_employees_for_input > 0
					         ? fp::from_fraction(
					               static_cast<int32_t>(type_safe::get(factory.get_employee_count())), max_employees_for_input
					           )
					         : fixed_point_t { 1 });

					Dictionary input_dict;
					input_dict["good_index"] = static_cast<int32_t>(type_safe::get(input.good.index));
					input_dict["quantity"] = static_cast<float>(needed);
					input_dict["stockpile"] = static_cast<float>(input.stockpile);
					// Less than a day of inputs left
					input_dict["lacking"] = input.stockpile < needed_now;
					factory_inputs.push_back(std::move(input_dict));
				}
				factory_dict["inputs"] = std::move(factory_inputs);

				const int32_t max_employees_value = static_cast<int32_t>(type_safe::get(factory.get_max_employee_count()));
				factory_dict["employment_ratio"] = max_employees_value > 0
				    ? static_cast<float>(type_safe::get(factory.get_employee_count())) / static_cast<float>(max_employees_value)
				    : 0.0f;
				factory_dict["level"] = static_cast<int32_t>(type_safe::get(factory.get_level()));
				factory_dict["max_level"] = static_cast<int32_t>(type_safe::get(building_type.max_level));
				factory_dict["constructing"] = factory.is_under_construction();
				factory_dict["construction_progress"] = static_cast<float>(factory.get_construction_progress(today));
				factory_dict["open"] = factory.is_open();
				factory_dict["employees"] = static_cast<int32_t>(type_safe::get(factory.get_employee_count()));
				factory_dict["max_employees"] = static_cast<int32_t>(type_safe::get(factory.get_max_employee_count()));
				factory_dict["efficiency"] = static_cast<float>(factory.get_efficiency());
				factory_dict["throttle"] = static_cast<float>(factory.get_throttle());
				factory_dict["budget"] = static_cast<float>(factory.get_budget());
				factory_dict["output_quantity"] = static_cast<float>(factory.get_output_quantity_yesterday());
				factory_dict["revenue"] = static_cast<float>(factory.get_revenue_yesterday());
				factory_dict["input_cost"] = static_cast<float>(factory.get_input_cost_yesterday());
				factory_dict["wages"] = static_cast<float>(factory.get_wages_yesterday());
				factory_dict["profit"] = static_cast<float>(factory.get_profit_yesterday());
				factory_dict["upgrade_cost"] =
				    static_cast<float>(FactoryInstance::calculate_construction_cost(building_type, market_instance));
				factory_dict["can_expand"] = factory.can_be_expanded();
				factories.push_back(std::move(factory_dict));
			}

			Array buildable;
			for (FactoryTypeInfo const& info : factory_types) {
				if (state.find_factory(*info.building_type) != nullptr) {
					continue;
				}

				const String identifier = convert_to<String>(info.building_type->get_identifier());

				Dictionary buildable_dict;
				buildable_dict["building_type_index"] = static_cast<int32_t>(type_safe::get(info.building_type->index));
				buildable_dict["identifier"] = identifier;
				buildable_dict["name"] = menu_singleton->tr(identifier);
				buildable_dict["output_good"] = menu_singleton->tr(
				    convert_to<String>(info.building_type->production_type->output_good.get_identifier())
				);
				buildable_dict["output_good_index"] = static_cast<int32_t>(
				    type_safe::get(info.building_type->production_type->output_good.index)
				);
				buildable_dict["output_quantity"] =
				    static_cast<float>(info.building_type->production_type->base_output_quantity);
				buildable_dict["workforce"] =
				    static_cast<int32_t>(type_safe::get(info.building_type->production_type->base_workforce_size));
				buildable_dict["build_time_days"] =
				    static_cast<int32_t>(FactoryInstance::calculate_construction_time(*info.building_type).to_int());
				buildable_dict["description"] = menu_singleton->tr(identifier + String("_desc"));

				Array buildable_inputs;
				for (auto const& [good, quantity] : info.building_type->production_type->input_goods) {
					Dictionary input_dict;
					input_dict["good_index"] = static_cast<int32_t>(type_safe::get(good->index));
					input_dict["quantity"] = static_cast<float>(quantity);
					buildable_inputs.push_back(std::move(input_dict));
				}
				buildable_dict["inputs"] = std::move(buildable_inputs);

				buildable_dict["cost"] = static_cast<float>(info.cost);
				buildable_dict["can_build"] = has_free_slot && cash >= info.cost &&
				    info.building_type->production_type->is_valid_for_factory_in(state);
				buildable.push_back(std::move(buildable_dict));
			}

			Dictionary state_dict;
			state_dict["province_index"] = static_cast<int32_t>(type_safe::get(state.get_capital()->index));
			state_dict["name"] = Utilities::get_state_name(*menu_singleton, state);
			state_dict["free_slots"] = static_cast<int32_t>(
			    FactoryInstance::MAX_FACTORIES_PER_STATE - std::min(FactoryInstance::MAX_FACTORIES_PER_STATE, state.get_factories().size())
			);
			state_dict["factories"] = std::move(factories);
			state_dict["buildable"] = std::move(buildable);
			result.push_back(std::move(state_dict));
		}
	}

	return result;
}

bool PlayerSingleton::build_factory(int32_t province_index, int32_t building_type_index) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(province_index < 0 || building_type_index < 0, false);

	return instance_manager->queue_game_action<build_factory_argument_t>(
	    player_country->index,
	    province_index_t(static_cast<uint32_t>(province_index)),
	    building_type_index_t(static_cast<uint32_t>(building_type_index))
	);
}

bool PlayerSingleton::set_factory_open(int32_t province_index, int32_t building_type_index, bool open) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(province_index < 0 || building_type_index < 0, false);

	return instance_manager->queue_game_action<set_factory_open_argument_t>(
	    player_country->index,
	    province_index_t(static_cast<uint32_t>(province_index)),
	    building_type_index_t(static_cast<uint32_t>(building_type_index)),
	    open
	);
}

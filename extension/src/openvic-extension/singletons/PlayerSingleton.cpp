#include "PlayerSingleton.hpp"

#include <algorithm>
#include <unordered_set>
#include <vector>

#include <openvic-simulation/core/FormatValidate.hpp>
#include <openvic-simulation/DefinitionManager.hpp>
#include <openvic-simulation/InstanceManager.hpp>
#include <openvic-simulation/country/CountryInstance.hpp>
#include <openvic-simulation/diplomacy/CountryRelation.hpp>
#include <openvic-simulation/diplomacy/DiplomaticAction.hpp>
#include <openvic-simulation/economy/BuildingType.hpp>
#include <openvic-simulation/economy/credit/Credit.hpp>
#include <openvic-simulation/economy/production/FactoryInstance.hpp>
#include <openvic-simulation/economy/production/ProductionType.hpp>
#include <openvic-simulation/economy/trading/MarketInstance.hpp>
#include <openvic-simulation/map/State.hpp>
#include <openvic-simulation/military/UnitInstanceGroup.hpp>
#include <openvic-simulation/military/War.hpp>
#include <openvic-simulation/politics/Government.hpp>
#include <openvic-simulation/politics/PoliticsDynamics.hpp>
#include <openvic-simulation/country/CountryParty.hpp>
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

	OV_BIND_METHOD(PlayerSingleton::get_map_units);
	OV_BIND_METHOD(PlayerSingleton::get_tariff_info);
	OV_BIND_METHOD(PlayerSingleton::get_production_info);
	OV_BIND_METHOD(PlayerSingleton::build_factory, { "province_index", "building_type_index" });
	OV_BIND_METHOD(PlayerSingleton::set_factory_subsidised, { "province_index", "building_type_index", "subsidised" });
	OV_BIND_METHOD(PlayerSingleton::set_all_factories_open, { "open" });
	OV_BIND_METHOD(PlayerSingleton::set_all_factories_subsidised, { "subsidised" });
	OV_BIND_METHOD(PlayerSingleton::expand_all_factories);
	OV_BIND_METHOD(PlayerSingleton::set_subsidy_mode, { "mode" });
	OV_BIND_METHOD(PlayerSingleton::get_subsidy_info);
	OV_BIND_METHOD(PlayerSingleton::buy_factory_share, { "province_index", "building_type_index", "percent" });
	OV_BIND_METHOD(PlayerSingleton::sell_factory_share, { "province_index", "building_type_index", "percent" });
	OV_BIND_METHOD(PlayerSingleton::set_factory_open, { "province_index", "building_type_index", "open" });

	OV_BIND_METHOD(PlayerSingleton::get_technology_info);
	OV_BIND_METHOD(PlayerSingleton::start_research, { "technology_index" });

	OV_BIND_METHOD(PlayerSingleton::get_war_overview);
	OV_BIND_METHOD(PlayerSingleton::move_army, { "army_id", "province_number" });
	OV_BIND_METHOD(PlayerSingleton::queue_army_move, { "army_id", "province_number" });
	OV_BIND_METHOD(PlayerSingleton::stop_army, { "army_id" });
	OV_BIND_METHOD(PlayerSingleton::propose_peace, { "war_id", "peace_type" });
	OV_BIND_METHOD(PlayerSingleton::create_front, { "enemy_country_index" });
	OV_BIND_METHOD(PlayerSingleton::delete_front, { "front_id" });
	OV_BIND_METHOD(PlayerSingleton::toggle_front_province, { "front_id", "province_number" });
	OV_BIND_METHOD(PlayerSingleton::set_front_mode, { "front_id", "mode" });
	OV_BIND_METHOD(PlayerSingleton::set_front_army, { "front_id", "army_id", "assigned" });
	OV_BIND_METHOD(PlayerSingleton::assign_free_armies, { "front_id" });
	OV_BIND_METHOD(PlayerSingleton::set_auto_plan, { "enabled" });
	OV_BIND_METHOD(PlayerSingleton::get_army_details, { "army_id" });
	OV_BIND_METHOD(PlayerSingleton::get_market_overview);
	OV_BIND_METHOD(PlayerSingleton::get_politics_info);
	OV_BIND_METHOD(PlayerSingleton::enact_reform, { "reform_index" });
	OV_BIND_METHOD(PlayerSingleton::get_peace_info, { "war_id" });
	OV_BIND_METHOD(PlayerSingleton::set_peace_demand, { "war_id", "kind", "province_number", "enabled" });
	OV_BIND_METHOD(PlayerSingleton::send_peace_offer, { "war_id" });
	OV_BIND_METHOD(PlayerSingleton::answer_peace_offer, { "war_id", "accept" });
	OV_BIND_METHOD(PlayerSingleton::get_peace_offers);
	OV_BIND_METHOD(PlayerSingleton::get_declarable_countries);
	OV_BIND_METHOD(PlayerSingleton::get_war_goal_states, { "country_index" });
	OV_BIND_METHOD(PlayerSingleton::declare_war_with_goal, { "country_index", "goal_type", "province_number" });
	OV_BIND_METHOD(PlayerSingleton::get_generals);
	OV_BIND_METHOD(PlayerSingleton::get_admirals);
	OV_BIND_METHOD(PlayerSingleton::load_army, { "army_id", "navy_id" });
	OV_BIND_METHOD(PlayerSingleton::unload_army, { "army_id" });
	OV_BIND_METHOD(PlayerSingleton::land_army, { "army_id", "province_number" });
	OV_BIND_METHOD(PlayerSingleton::get_ship_types, { "province_number" });
	OV_BIND_METHOD(PlayerSingleton::start_ship_building, { "ship_type_index", "province_number" });
	OV_BIND_METHOD(PlayerSingleton::get_blockade_info);
	OV_BIND_METHOD(PlayerSingleton::get_mergeable_armies, { "army_id" });
	OV_BIND_METHOD(PlayerSingleton::get_leader_settings);
	OV_BIND_METHOD(PlayerSingleton::set_leader_auto, { "auto_create", "auto_assign" });
	OV_BIND_METHOD(PlayerSingleton::create_general);
	OV_BIND_METHOD(PlayerSingleton::split_regiment, { "regiment_id" });
	OV_BIND_METHOD(PlayerSingleton::merge_armies, { "target_army_id", "source_army_id" });
	OV_BIND_METHOD(PlayerSingleton::set_army_leader, { "army_id", "leader_id" });
	OV_BIND_METHOD(PlayerSingleton::disband_regiment, { "regiment_id" });
	OV_BIND_METHOD(PlayerSingleton::disband_army, { "army_id" });
	OV_BIND_METHOD(PlayerSingleton::get_recruitment_info, { "province_number" });
	OV_BIND_METHOD(PlayerSingleton::get_recruitment_block_reason, { "regiment_type_index", "province_number", "pop_id" });
	OV_BIND_METHOD(PlayerSingleton::start_recruitment, { "regiment_type_index", "province_number", "pop_id" });
	OV_BIND_METHOD(PlayerSingleton::get_recruitment_queue);
	OV_BIND_METHOD(PlayerSingleton::cancel_recruitment, { "order_id" });

	OV_BIND_METHOD(PlayerSingleton::get_credit_overview);
	OV_BIND_METHOD(PlayerSingleton::take_external_loan, { "lender_index", "amount", "term" });
	OV_BIND_METHOD(PlayerSingleton::give_external_loans, { "group", "amount_each", "rate", "term" });
	OV_BIND_METHOD(PlayerSingleton::stage_loan_target, { "country_index", "selected" });
	OV_BIND_METHOD(PlayerSingleton::give_internal_loan, { "province_index", "amount", "rate", "term", "policy" });
	OV_BIND_METHOD(PlayerSingleton::repay_loan, { "loan_id", "amount" });
	OV_BIND_METHOD(PlayerSingleton::set_central_bank_rates, { "internal_rate", "external_rate" });
	OV_BIND_METHOD(PlayerSingleton::answer_alliance_request, { "from_index", "accept" });
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
			    { &building_type, building_type.cost } // the goods of the cost come from the national stockpile
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
				    static_cast<float>(building_type.cost);
				factory_dict["can_expand"] = factory.can_be_expanded();
				// Ownership, treasury and subsidies
				factory_dict["state_share"] = static_cast<float>(factory.get_state_share());
				factory_dict["subsidised"] = factory.is_subsidised();
				factory_dict["built_by_state"] = factory.was_built_by_state();
				factory_dict["expansion_fund"] = static_cast<float>(factory.get_expansion_fund());
				factory_dict["expansion_cost"] =
				    static_cast<float>(FactoryInstance::calculate_construction_cost(building_type, market_instance));
				factory_dict["subsidy"] = static_cast<float>(factory.get_subsidy_yesterday());
				factory_dict["private_cover"] = static_cast<float>(factory.get_private_cover_yesterday());
				factory_dict["average_profit"] = static_cast<float>(factory.get_average_profit());
				factory_dict["value"] = static_cast<float>(factory.calculate_value(market_instance));
				factory_dict["state_dividends"] = static_cast<float>(factory.get_state_income_yesterday());
				factory_dict["owner_dividends"] = static_cast<float>(factory.get_owner_income_yesterday());
				factory_dict["capitalist_fund"] = static_cast<float>(state.get_capitalist_fund());
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

bool PlayerSingleton::set_factory_subsidised(int32_t province_index, int32_t building_type_index, bool subsidised) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(province_index < 0 || building_type_index < 0, false);

	return instance_manager->queue_game_action<set_factory_subsidised_argument_t>(
	    player_country->index,
	    province_index_t(static_cast<uint32_t>(province_index)),
	    building_type_index_t(static_cast<uint32_t>(building_type_index)),
	    subsidised
	);
}

bool PlayerSingleton::set_all_factories_open(bool open) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	return instance_manager->queue_game_action<set_all_factories_open_argument_t>(player_country->index, open);
}

bool PlayerSingleton::set_all_factories_subsidised(bool subsidised) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	return instance_manager->queue_game_action<set_all_factories_subsidised_argument_t>(player_country->index, subsidised);
}

bool PlayerSingleton::expand_all_factories() const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	return instance_manager->queue_game_action<expand_all_factories_argument_t>(player_country->index);
}

bool PlayerSingleton::set_subsidy_mode(int32_t mode) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(mode < 0 || mode > 2, false);
	return instance_manager->queue_game_action<set_subsidy_mode_argument_t>(player_country->index, static_cast<uint32_t>(mode));
}

Dictionary PlayerSingleton::get_subsidy_info() const {
	Dictionary result;
	ERR_FAIL_NULL_V(player_country, result);

	fixed_point_t state_paid = 0, capitalists_paid = 0;
	for (State const* state : player_country->get_states()) {
		for (FactoryInstance const& factory : state->get_factories()) {
			state_paid += factory.get_subsidy_yesterday();
			capitalists_paid += factory.get_private_cover_yesterday();
		}
	}

	result["mode"] = static_cast<int32_t>(player_country->get_subsidy_mode());
	result["state_paid"] = static_cast<float>(state_paid);
	result["capitalists_paid"] = static_cast<float>(capitalists_paid);
	return result;
}

bool PlayerSingleton::buy_factory_share(int32_t province_index, int32_t building_type_index, int32_t percent) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(province_index < 0 || building_type_index < 0 || percent <= 0 || percent > 100, false);

	return instance_manager->queue_game_action<buy_factory_share_argument_t>(
	    player_country->index,
	    province_index_t(static_cast<uint32_t>(province_index)),
	    building_type_index_t(static_cast<uint32_t>(building_type_index)),
	    static_cast<uint32_t>(percent)
	);
}

bool PlayerSingleton::sell_factory_share(int32_t province_index, int32_t building_type_index, int32_t percent) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(province_index < 0 || building_type_index < 0 || percent <= 0 || percent > 100, false);

	return instance_manager->queue_game_action<sell_factory_share_argument_t>(
	    player_country->index,
	    province_index_t(static_cast<uint32_t>(province_index)),
	    building_type_index_t(static_cast<uint32_t>(building_type_index)),
	    static_cast<uint32_t>(percent)
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

// Wars, armies and fronts
namespace {
	Array make_war_side(
		MenuSingleton const& menu_singleton, memory::vector<CountryInstance*> const& countries
	) {
		Array result;
		for (CountryInstance const* country : countries) {
			Dictionary entry;
			entry["index"] = static_cast<int32_t>(type_safe::get(country->index));
			entry["name"] = Utilities::get_country_name(menu_singleton, *country);
			result.push_back(entry);
		}
		return result;
	}

	Dictionary make_province_entry(ProvinceInstance const& province) {
		Dictionary entry;
		entry["number"] = static_cast<int32_t>(province.province_definition.get_province_number());
		entry["identifier"] = convert_to<String>(province.get_identifier());
		return entry;
	}
}

Dictionary PlayerSingleton::get_war_overview() const {
	Dictionary result;

	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MenuSingleton const* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, result);

	WarManager const& war_manager = instance_manager->get_war_manager();
	UnitInstanceManager& unit_manager = instance_manager->get_unit_instance_manager();

	Array wars;
	for (War const* war : war_manager.get_wars_of(*player_country)) {
		Dictionary entry;
		entry["id"] = static_cast<int32_t>(war->id);
		entry["we_attack"] = war->is_attacker(*player_country);
		entry["days"] = static_cast<int32_t>((instance_manager->get_today() - war->start_date).to_int());
		entry["attacker_score"] = static_cast<float>(war->attacker_score);
		entry["defender_score"] = static_cast<float>(war->defender_score);
		entry["attackers"] = make_war_side(*menu_singleton, war->attackers);
		entry["defenders"] = make_war_side(*menu_singleton, war->defenders);
		wars.push_back(entry);
	}
	result["wars"] = wars;

	// The front each army is assigned to
	std::vector<std::pair<unique_id_t, uint32_t>> army_fronts;
	Array fronts;
	for (Front const& front : war_manager.get_fronts()) {
		if (front.country != player_country) {
			continue;
		}

		Dictionary entry;
		entry["id"] = static_cast<int32_t>(front.id);
		entry["mode"] = static_cast<int32_t>(front.mode);
		entry["enemy_index"] = front.enemy != nullptr ? static_cast<int32_t>(type_safe::get(front.enemy->index)) : -1;
		entry["enemy_name"] = front.enemy != nullptr ? Utilities::get_country_name(*menu_singleton, *front.enemy) : String {};

		Array provinces;
		for (ProvinceInstance const* province : front.provinces) {
			provinces.push_back(make_province_entry(*province));
		}
		entry["provinces"] = provinces;

		Array army_ids;
		for (const unique_id_t army_id : front.army_ids) {
			army_ids.push_back(static_cast<int64_t>(army_id));
			army_fronts.emplace_back(army_id, front.id);
		}
		entry["army_ids"] = army_ids;

		fronts.push_back(entry);
	}
	result["fronts"] = fronts;

	Array armies;
	for (ArmyInstance const& army : player_country->get_armies()) {
		Dictionary entry;
		entry["id"] = static_cast<int64_t>(army.unique_id);
		entry["name"] = convert_to<String>(army.get_name());
		entry["province_number"] = static_cast<int32_t>(army.get_location().province_definition.get_province_number());
		entry["province_identifier"] = convert_to<String>(army.get_location().get_identifier());
		entry["regiments"] = static_cast<int32_t>(army.get_unit_count());
		entry["strength"] = static_cast<float>(army.get_total_strength());
		entry["max_strength"] = static_cast<float>(army.get_total_max_strength());
		entry["organisation"] = static_cast<float>(army.get_organisation_proportion());
		entry["moving"] = army.is_moving();
		ProvinceInstance const* destination = army.get_movement_destination_province();
		entry["destination_number"] =
		    destination != nullptr ? static_cast<int32_t>(destination->province_definition.get_province_number()) : 0;
		entry["destination_identifier"] = destination != nullptr ? convert_to<String>(destination->get_identifier()) : String {};
		entry["in_combat"] = army.is_in_combat();

		int32_t front_id = 0;
		for (auto const& [army_id, assigned_front_id] : army_fronts) {
			if (army_id == army.unique_id) {
				front_id = static_cast<int32_t>(assigned_front_id);
				break;
			}
		}
		entry["front_id"] = front_id;

		armies.push_back(entry);
	}
	result["armies"] = armies;

	result["auto_plan"] = war_manager.is_auto_plan_enabled(*player_country);
	result["selected_province_number"] = get_selected_province_number();

	(void)unit_manager;
	return result;
}

bool PlayerSingleton::move_army(int64_t army_id, int32_t province_number) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);

	ProvinceInstance const* province = instance_manager->get_map_instance().get_province_instance_from_number(province_number);
	ERR_FAIL_NULL_V(province, false);

	// Only own armies can be ordered
	UnitInstanceGroup* group = instance_manager->get_unit_instance_manager().get_unit_instance_group_by_unique_id(
	    static_cast<unique_id_t>(army_id)
	);
	ERR_FAIL_NULL_V(group, false);
	ERR_FAIL_COND_V(&group->get_country() != player_country, false);

	return instance_manager->queue_game_action<move_army_argument_t>(
	    static_cast<unique_id_t>(army_id), province->index
	);
}

bool PlayerSingleton::queue_army_move(int64_t army_id, int32_t province_number) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);

	ProvinceInstance const* province = instance_manager->get_map_instance().get_province_instance_from_number(province_number);
	ERR_FAIL_NULL_V(province, false);

	UnitInstanceGroup* group = instance_manager->get_unit_instance_manager().get_unit_instance_group_by_unique_id(
	    static_cast<unique_id_t>(army_id)
	);
	ERR_FAIL_NULL_V(group, false);
	ERR_FAIL_COND_V(&group->get_country() != player_country, false);

	return instance_manager->queue_game_action<queue_army_move_argument_t>(
	    static_cast<unique_id_t>(army_id), province->index
	);
}

bool PlayerSingleton::stop_army(int64_t army_id) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);

	UnitInstanceGroup* group = instance_manager->get_unit_instance_manager().get_unit_instance_group_by_unique_id(
	    static_cast<unique_id_t>(army_id)
	);
	ERR_FAIL_NULL_V(group, false);
	ERR_FAIL_COND_V(&group->get_country() != player_country, false);

	return instance_manager->queue_game_action<stop_army_argument_t>(static_cast<unique_id_t>(army_id));
}

bool PlayerSingleton::propose_peace(int32_t war_id, int32_t peace_type) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(war_id <= 0 || peace_type < 0, false);

	return instance_manager->queue_game_action<propose_peace_argument_t>(
	    player_country->index, static_cast<uint32_t>(war_id), static_cast<uint32_t>(peace_type)
	);
}

bool PlayerSingleton::create_front(int32_t enemy_country_index) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);

	country_index_t enemy_index = player_country->index;
	if (enemy_country_index >= 0) {
		ERR_FAIL_COND_V(
		    static_cast<size_t>(enemy_country_index) >=
		        instance_manager->get_country_instance_manager().get_country_instances().size(),
		    false
		);
		enemy_index = country_index_t(static_cast<uint32_t>(enemy_country_index));
	}

	return instance_manager->queue_game_action<create_front_argument_t>(player_country->index, enemy_index);
}

bool PlayerSingleton::delete_front(int32_t front_id) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(front_id <= 0, false);

	return instance_manager->queue_game_action<delete_front_argument_t>(player_country->index, static_cast<uint32_t>(front_id));
}

bool PlayerSingleton::toggle_front_province(int32_t front_id, int32_t province_number) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(front_id <= 0, false);

	ProvinceInstance const* province = instance_manager->get_map_instance().get_province_instance_from_number(province_number);
	ERR_FAIL_NULL_V(province, false);

	return instance_manager->queue_game_action<toggle_front_province_argument_t>(
	    player_country->index, static_cast<uint32_t>(front_id), province->index
	);
}

bool PlayerSingleton::set_front_mode(int32_t front_id, int32_t mode) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(front_id <= 0 || mode < 0 || mode > 1, false);

	return instance_manager->queue_game_action<set_front_mode_argument_t>(
	    player_country->index, static_cast<uint32_t>(front_id), static_cast<uint32_t>(mode)
	);
}

bool PlayerSingleton::set_front_army(int32_t front_id, int64_t army_id, bool assigned) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(front_id <= 0, false);

	return instance_manager->queue_game_action<set_front_army_argument_t>(
	    player_country->index, static_cast<uint32_t>(front_id), static_cast<unique_id_t>(army_id), assigned
	);
}

bool PlayerSingleton::assign_free_armies(int32_t front_id) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(front_id <= 0, false);

	return instance_manager->queue_game_action<assign_free_armies_argument_t>(
	    player_country->index, static_cast<uint32_t>(front_id)
	);
}

bool PlayerSingleton::set_auto_plan(bool enabled) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);

	return instance_manager->queue_game_action<set_auto_plan_argument_t>(player_country->index, enabled);
}

// Map units
namespace {
	// Where a group is drawn for a province: ships in a port are drawn in the sea next to it
	Vector2 get_province_anchor(GameSingleton const& game_singleton, ProvinceInstance const& province, unit_branch_t branch) {
		ProvinceDefinition const& definition = province.province_definition;
		if (branch == unit_branch_t::NAVAL && !definition.is_water() && definition.get_port_adjacent_province() != nullptr) {
			return game_singleton.normalise_map_position(definition.get_port_adjacent_province()->get_unit_position());
		}
		return game_singleton.normalise_map_position(definition.get_unit_position());
	}

	// Positions (normalised map coordinates) of the path of a moving group, starting at its current province
	PackedVector2Array get_unit_path_positions(GameSingleton const& game_singleton, UnitInstanceGroup const& unit) {
		PackedVector2Array positions;
		if (unit.get_path().empty()) {
			return positions;
		}

		positions.push_back(get_province_anchor(game_singleton, unit.get_location(), unit.branch));
		for (ProvinceInstance const& province : unit.get_path()) {
			positions.push_back(get_province_anchor(game_singleton, province, unit.branch));
		}
		return positions;
	}

	// Position of a group on the map, between its province and the next one of its path while it moves
	Vector2 get_unit_current_position(GameSingleton const& game_singleton, UnitInstanceGroup const& unit) {
		Vector2 position = get_province_anchor(game_singleton, unit.get_location(), unit.branch);

		if (unit.get_path().empty()) {
			return position;
		}

		ProvinceInstance const& next = unit.get_path().front().get();
		const fixed_point_t step = unit.get_step_distance(unit.get_location(), next);
		if (step < fixed_point_t::_0) {
			return position;
		}

		const Vector2 target = get_province_anchor(game_singleton, next, unit.branch);
		const float distance = static_cast<float>(step);
		const float progress = distance > 0.0f ? static_cast<float>(unit.get_movement_progress()) / distance : 0.0f;
		return position.lerp(target, std::clamp(progress, 0.0f, 1.0f));
	}
}

Array PlayerSingleton::get_map_units() const {
	Array result;

	GameSingleton const* game_singleton = GameSingleton::get_singleton();
	ERR_FAIL_NULL_V(game_singleton, result);
	InstanceManager const* instance_manager = game_singleton->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);

	WarManager const& war_manager = instance_manager->get_war_manager();

	struct CountryGroup {
		CountryInstance const* country;
		int32_t army_count = 0, regiments = 0;
		fixed_point_t strength = 0, max_strength = 0, organisation = 0, max_organisation = 0;
		bool in_combat = false, moving = false;
		// The armies lose men: outside of friendly lands or without supplies
		bool attrition = false;
		int32_t carried = 0; // regiments carried by the fleets
		Array army_ids;
		Array paths;
		// Position of the last army of the group, which is also the one drawn on the map
		Vector2 position;
		bool has_position = false;
	};
	std::vector<CountryGroup> groups;

	for (ProvinceInstance const& province : instance_manager->get_map_instance().get_province_instances()) {
		if (province.province_definition.is_water() || province.get_armies().empty()) {
			continue;
		}

		groups.clear();

		for (ArmyInstance const& army : province.get_armies()) {
			// Armies on board of ships are shown with the fleet
			if (army.get_transport_navy() != nullptr) {
				continue;
			}
			CountryInstance const* country = &army.get_country();

			CountryGroup* group = nullptr;
			for (CountryGroup& existing : groups) {
				if (existing.country == country) {
					group = &existing;
					break;
				}
			}
			if (group == nullptr) {
				groups.push_back({ country });
				group = &groups.back();
			}

			group->army_count++;
			group->regiments += static_cast<int32_t>(army.get_unit_count());
			group->strength += army.get_total_strength();
			group->max_strength += army.get_total_max_strength();
			group->organisation += army.get_total_organisation();
			group->max_organisation += army.get_total_max_organisation();
			group->in_combat = group->in_combat || army.is_in_combat();
			group->moving = group->moving || army.is_moving();
			{
				CountryInstance const* owner = province.get_owner();
				const bool friendly = owner == country || (owner != nullptr && country->has_alliance_with(*owner));
				const bool unsupplied = country->is_at_war() && country->get_army_supply_ratio() < (fixed_point_t(3) / 4);
				group->attrition = group->attrition || (!country->is_rebel_country() && (!friendly || unsupplied));
			}
			group->army_ids.push_back(static_cast<int64_t>(army.unique_id));

			if (army.is_moving()) {
				PackedVector2Array path_positions = get_unit_path_positions(*game_singleton, army);
				if (!path_positions.is_empty()) {
					group->paths.push_back(std::move(path_positions));
				}
			}
			group->position = get_unit_current_position(*game_singleton, army);
			group->has_position = true;
		}

		WarManager::Siege const* siege = war_manager.get_siege(province);
		const bool occupied = province.get_controller() != nullptr && province.get_controller() != province.get_owner();

		for (CountryGroup const& group : groups) {
			Dictionary entry;
			entry["province_number"] = static_cast<int32_t>(province.province_definition.get_province_number());
			entry["position"] = group.has_position
			    ? group.position
			    : game_singleton->normalise_map_position(province.province_definition.get_unit_position());
			entry["paths"] = group.paths;
			entry["country_identifier"] = convert_to<String>(group.country->get_identifier());
			entry["country_index"] = static_cast<int32_t>(type_safe::get(group.country->index));
			entry["is_player"] = group.country == player_country;
			entry["army_count"] = group.army_count;
			entry["regiments"] = group.regiments;
			entry["strength"] = group.max_strength > 0 ? static_cast<float>(group.strength / group.max_strength) : 0.0f;
			entry["organisation"] =
			    group.max_organisation > 0 ? static_cast<float>(group.organisation / group.max_organisation) : 0.0f;
			entry["in_combat"] = group.in_combat;
			entry["moving"] = group.moving;
			entry["attrition"] = group.attrition;
			entry["army_ids"] = group.army_ids;
			entry["is_navy"] = false;
			entry["occupied"] = occupied;

			float siege_progress = -1.0f;
			if (siege != nullptr && siege->besieger == group.country && siege->days_required > 0) {
				siege_progress = std::min(1.0f, static_cast<float>(siege->days) / static_cast<float>(siege->days_required));
			}
			entry["siege_progress"] = siege_progress;

			result.push_back(std::move(entry));
		}
	}

	// Fleets, in the sea or docked in a port (drawn in the sea next to it)
	for (ProvinceInstance const& province : instance_manager->get_map_instance().get_province_instances()) {
		if (province.get_navies().empty()) {
			continue;
		}

		groups.clear();
		for (NavyInstance const& navy : province.get_navies()) {
			if (navy.empty()) {
				continue;
			}
			CountryInstance const* country = &navy.get_country();

			CountryGroup* group = nullptr;
			for (CountryGroup& existing : groups) {
				if (existing.country == country) {
					group = &existing;
					break;
				}
			}
			if (group == nullptr) {
				groups.push_back({ country });
				group = &groups.back();
			}

			group->army_count++;
			group->regiments += static_cast<int32_t>(navy.get_unit_count());
			group->strength += navy.get_total_strength();
			group->max_strength += navy.get_total_max_strength();
			group->organisation += navy.get_total_organisation();
			group->max_organisation += navy.get_total_max_organisation();
			group->in_combat = group->in_combat || navy.is_in_combat();
			group->moving = group->moving || navy.is_moving();
			group->army_ids.push_back(static_cast<int64_t>(navy.unique_id));
			group->carried += static_cast<int32_t>(navy.get_carried_regiment_count());
			if (war_manager.is_blockaded(province)) {
				group->attrition = true;
			}

			if (navy.is_moving()) {
				PackedVector2Array path_positions = get_unit_path_positions(*game_singleton, navy);
				if (!path_positions.is_empty()) {
					group->paths.push_back(std::move(path_positions));
				}
			}
			group->position = get_unit_current_position(*game_singleton, navy);
			group->has_position = true;
		}

		for (CountryGroup const& group : groups) {
			Dictionary entry;
			entry["province_number"] = static_cast<int32_t>(province.province_definition.get_province_number());
			entry["position"] = group.has_position ? group.position : get_province_anchor(*game_singleton, province, unit_branch_t::NAVAL);
			entry["paths"] = group.paths;
			entry["country_identifier"] = convert_to<String>(group.country->get_identifier());
			entry["country_index"] = static_cast<int32_t>(type_safe::get(group.country->index));
			entry["is_player"] = group.country == player_country;
			entry["army_count"] = group.army_count;
			entry["regiments"] = group.regiments;
			entry["carried"] = group.carried;
			entry["strength"] = group.max_strength > 0 ? static_cast<float>(group.strength / group.max_strength) : 0.0f;
			entry["organisation"] =
			    group.max_organisation > 0 ? static_cast<float>(group.organisation / group.max_organisation) : 0.0f;
			entry["in_combat"] = group.in_combat;
			entry["moving"] = group.moving;
			entry["attrition"] = false;
			entry["blockade"] = group.attrition;
			entry["army_ids"] = group.army_ids;
			entry["is_navy"] = true;
			entry["occupied"] = false;
			entry["siege_progress"] = -1.0f;
			result.push_back(std::move(entry));
		}
	}

	return result;
}

// Credit and the central bank
namespace {
	String format_date(Date const date) {
		return Utilities::format("%d.%d.%d", static_cast<int32_t>(date.get_year()), static_cast<int32_t>(date.get_month()), static_cast<int32_t>(date.get_day()));
	}

	Dictionary make_loan_entry(Loan const& loan, MenuSingleton const& menu_singleton, CountryInstance const& player) {
		Dictionary entry;
		entry["id"] = static_cast<int32_t>(loan.id);
		entry["principal"] = static_cast<float>(loan.principal);
		entry["remaining"] = static_cast<float>(loan.remaining);
		entry["rate"] = static_cast<float>(loan.annual_rate);
		entry["due"] = format_date(loan.due_date);
		entry["interest_paid"] = static_cast<float>(loan.interest_paid);
		entry["term"] = static_cast<int32_t>(loan.term);
		entry["policy"] = static_cast<int32_t>(loan.policy);
		entry["unspent"] = static_cast<float>(loan.unspent);
		entry["grace_end"] = format_date(loan.grace_end);
		CountryInstance const& other = loan.lender == &player ? *loan.borrower : *loan.lender;
		entry["other_index"] = static_cast<int32_t>(type_safe::get(other.index));
		entry["other_name"] = Utilities::get_country_name(menu_singleton, other);
		return entry;
	}
}

Dictionary PlayerSingleton::get_credit_overview() const {
	Dictionary result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MenuSingleton const* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, result);

	CreditManager const& credit = instance_manager->get_credit_manager();

	result["cash"] = static_cast<float>(player_country->get_cash_stockpile().load());

	Dictionary bank;
	bank["internal_rate"] = static_cast<float>(player_country->get_internal_loan_rate());
	bank["external_rate"] = static_cast<float>(player_country->get_external_loan_rate());
	bank["min_rate"] = static_cast<float>(CreditManager::get_min_rate());
	bank["max_rate"] = static_cast<float>(CreditManager::get_max_rate());
	result["central_bank"] = bank;

	result["total_debt"] = static_cast<float>(credit.get_total_debt(*player_country));
	result["monthly_interest"] = static_cast<float>(credit.get_monthly_interest(*player_country));
	result["debt_limit"] = static_cast<float>(CreditManager::get_debt_limit(*player_country));

	Array external_taken, external_given, internal_given;
	for (std::unique_ptr<Loan> const& loan : credit.get_loans()) {
		if (!loan->active) {
			continue;
		}
		if (loan->kind == Loan::kind_t::EXTERNAL) {
			if (loan->borrower == player_country) {
				external_taken.push_back(make_loan_entry(*loan, *menu_singleton, *player_country));
			} else if (loan->lender == player_country) {
				external_given.push_back(make_loan_entry(*loan, *menu_singleton, *player_country));
			}
		} else if (loan->lender == player_country) {
			Dictionary entry = make_loan_entry(*loan, *menu_singleton, *player_country);
			ProvinceInstance const* capital = loan->state->get_capital();
			entry["province_index"] = capital != nullptr ? static_cast<int32_t>(type_safe::get(capital->index)) : -1;
			entry["province_identifier"] = capital != nullptr ? convert_to<String>(capital->get_identifier()) : String {};
			internal_given.push_back(entry);
		}
	}
	result["external_taken"] = external_taken;
	result["external_given"] = external_given;
	result["internal_given"] = internal_given;

	Array offers;
	for (ExternalOffer const& offer : credit.get_offers(*instance_manager, *player_country)) {
		Dictionary entry;
		entry["lender_index"] = static_cast<int32_t>(type_safe::get(offer.lender->index));
		entry["lender_name"] = Utilities::get_country_name(*menu_singleton, *offer.lender);
		entry["max_amount"] = static_cast<float>(offer.max_amount);
		entry["rate"] = static_cast<float>(offer.rate);
		offers.push_back(entry);
	}
	result["offers"] = offers;

	// States whose capitalists can borrow
	Array states;
	PopType const* capitalists = instance_manager->definition_manager.get_pop_manager().get_pop_type_by_identifier("capitalists");
	for (State const* state : player_country->get_states()) {
		ProvinceInstance const* capital = state->get_capital();
		if (capital == nullptr || capitalists == nullptr) {
			continue;
		}
		int32_t size = 0;
		for (Pop const& pop : state->get_pops_cache_by_type()[capitalists->index]) {
			size += type_safe::get(pop.get_size());
		}
		if (size <= 0) {
			continue;
		}
		Dictionary entry;
		entry["province_index"] = static_cast<int32_t>(type_safe::get(capital->index));
		entry["province_identifier"] = convert_to<String>(capital->get_identifier());
		entry["capitalist_money"] = static_cast<float>(state->get_capitalist_money(Loan::purpose_t::CONSTRUCTION, 365));
		entry["capitalists"] = size;
		states.push_back(entry);
	}
	result["states"] = states;

	PackedInt32Array selected;
	for (CountryInstance const* target : credit.get_staged_targets(*player_country)) {
		selected.push_back(static_cast<int32_t>(type_safe::get(target->index)));
	}
	result["selected_targets"] = selected;

	Array requests;
	for (AllianceRequest const& request : credit.get_alliance_requests()) {
		if (request.to != player_country) {
			continue;
		}
		Dictionary entry;
		entry["from_index"] = static_cast<int32_t>(type_safe::get(request.from->index));
		entry["from_name"] = Utilities::get_country_name(*menu_singleton, *request.from);
		entry["date"] = format_date(request.date);
		requests.push_back(entry);
	}
	result["alliance_requests"] = requests;

	return result;
}

bool PlayerSingleton::take_external_loan(int32_t lender_index, float amount, int32_t term) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(lender_index < 0 || term < 0, false);
	return instance_manager->queue_game_action<take_external_loan_argument_t>(
	    player_country->index, country_index_t(static_cast<uint32_t>(lender_index)), fixed_point_t::parse_unsafe(amount),
	    static_cast<uint32_t>(term)
	);
}

bool PlayerSingleton::give_external_loans(int32_t group, float amount_each, float rate, int32_t term) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(group < 0 || term < 0, false);
	return instance_manager->queue_game_action<give_external_loans_argument_t>(
	    player_country->index, static_cast<uint32_t>(group), fixed_point_t::parse_unsafe(amount_each),
	    fixed_point_t::parse_unsafe(rate), static_cast<uint32_t>(term)
	);
}

bool PlayerSingleton::stage_loan_target(int32_t country_index, bool selected) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(country_index < 0, false);
	return instance_manager->queue_game_action<stage_loan_target_argument_t>(
	    player_country->index, country_index_t(static_cast<uint32_t>(country_index)), selected
	);
}

bool PlayerSingleton::give_internal_loan(int32_t province_index, float amount, float rate, int32_t term, int32_t policy) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(province_index < 0 || term < 0 || policy < 0, false);
	return instance_manager->queue_game_action<give_internal_loan_argument_t>(
	    player_country->index, province_index_t(static_cast<uint32_t>(province_index)), fixed_point_t::parse_unsafe(amount),
	    fixed_point_t::parse_unsafe(rate), static_cast<uint32_t>(term), static_cast<uint32_t>(policy)
	);
}

bool PlayerSingleton::repay_loan(int32_t loan_id, float amount) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(loan_id <= 0, false);
	return instance_manager->queue_game_action<repay_loan_argument_t>(
	    player_country->index, static_cast<uint32_t>(loan_id), fixed_point_t::parse_unsafe(amount)
	);
}

bool PlayerSingleton::set_central_bank_rates(float internal_rate, float external_rate) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	return instance_manager->queue_game_action<set_central_bank_rates_argument_t>(
	    player_country->index, fixed_point_t::parse_unsafe(internal_rate), fixed_point_t::parse_unsafe(external_rate)
	);
}

bool PlayerSingleton::answer_alliance_request(int32_t from_index, bool accept) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(from_index < 0, false);
	return instance_manager->queue_game_action<answer_alliance_request_argument_t>(
	    player_country->index, country_index_t(static_cast<uint32_t>(from_index)), accept
	);
}

Dictionary PlayerSingleton::get_tariff_info() const {
	Dictionary result;
	ERR_FAIL_NULL_V(player_country, result);

	result["import_value"] = static_cast<float>(player_country->get_yesterdays_import_value_untracked());
	result["effective_rate"] = static_cast<float>(player_country->effective_tariff_rate.get_untracked());
	result["administrative_efficiency"] =
	    static_cast<float>(player_country->get_administrative_efficiency_from_administrators_untracked());
	result["tariff_efficiency"] = static_cast<float>(player_country->tariff_efficiency.get_untracked());
	return result;
}

// Selected army panel and recruitment
namespace {
	Dictionary make_fleet_details(
		InstanceManager& instance_manager, MenuSingleton& menu_singleton, NavyInstance const& navy, CountryInstance const* player
	) {
		Dictionary result;
		CountryInstance const& country = navy.get_country();
		ProvinceInstance const& location = navy.get_location();
		const bool at_sea = location.province_definition.is_water();

		result["is_navy"] = true;
		result["id"] = static_cast<int64_t>(navy.unique_id);
		result["name"] = convert_to<String>(navy.get_name());
		result["country_index"] = static_cast<int32_t>(type_safe::get(country.index));
		result["country_name"] = Utilities::get_country_name(menu_singleton, country);
		result["is_player"] = &country == player;
		result["province_number"] = static_cast<int32_t>(location.province_definition.get_province_number());
		result["province_identifier"] = convert_to<String>(location.get_identifier());
		result["province_name"] = menu_singleton.tr(convert_to<String>(location.get_identifier()));
		result["docked"] = !at_sea;
		result["regiments"] = static_cast<int32_t>(navy.get_unit_count()); // ships
		result["strength"] = static_cast<float>(navy.get_total_strength());
		result["max_strength"] = static_cast<float>(navy.get_total_max_strength());
		result["organisation"] = static_cast<float>(navy.get_organisation_proportion());
		result["moving"] = navy.is_moving();
		result["in_combat"] = navy.is_in_combat();
		result["speed"] = static_cast<float>(navy.get_movement_speed());
		result["eta_days"] = navy.get_movement_days_left();
		result["dig_in"] = 0;
		result["dig_in_cap"] = 0;
		result["supply"] = static_cast<float>(country.get_army_supply_ratio());
		result["capacity"] = static_cast<int32_t>(navy.get_transport_capacity());
		result["carried_regiments"] = static_cast<int32_t>(navy.get_carried_regiment_count());

		ProvinceInstance const* destination = navy.get_movement_destination_province();
		result["destination_number"] =
			destination != nullptr ? static_cast<int32_t>(destination->province_definition.get_province_number()) : 0;
		result["destination_name"] =
			destination != nullptr ? menu_singleton.tr(convert_to<String>(destination->get_identifier())) : String {};

		LeaderInstance const* leader = navy.get_leader();
		result["leader_id"] = leader != nullptr ? static_cast<int64_t>(leader->unique_id) : 0;
		if (leader != nullptr) {
			result["leader"] = menu_singleton.make_leader_dict(*leader);
		}

		Array units;
		for (UnitInstance const& unit : navy.get_units()) {
			ShipType const& type = static_cast<ShipInstance const&>(unit).get_ship_type();
			Dictionary entry;
			entry["id"] = static_cast<int64_t>(unit.unique_id);
			entry["name"] = convert_to<String>(unit.get_name());
			entry["type_identifier"] = convert_to<String>(type.get_identifier());
			entry["type_name"] = menu_singleton.tr(convert_to<String>(type.get_identifier()));
			entry["strength"] = static_cast<float>(unit.get_strength());
			entry["max_strength"] = static_cast<float>(unit.get_max_strength());
			entry["organisation"] = static_cast<float>(unit.get_organisation());
			entry["max_organisation"] = static_cast<float>(unit.get_max_organisation());
			entry["hull"] = static_cast<float>(type.hull);
			entry["gun_power"] = static_cast<float>(type.gun_power);
			entry["is_transport"] = type.is_transport;
			units.push_back(entry);
		}
		result["units"] = units;

		Array carried;
		for (ArmyInstance const& army : navy.get_carried_armies()) {
			Dictionary entry;
			entry["id"] = static_cast<int64_t>(army.unique_id);
			entry["name"] = convert_to<String>(army.get_name());
			entry["regiments"] = static_cast<int32_t>(army.get_unit_count());
			carried.push_back(entry);
		}
		result["carried"] = carried;

		// Armies in the port that can be loaded
		Array loadable;
		if (!at_sea) {
			for (ArmyInstance const& army : location.get_armies()) {
				if (&army.get_country() != &country || army.get_transport_navy() != nullptr || army.is_moving() || army.is_in_combat()) {
					continue;
				}
				Dictionary entry;
				entry["id"] = static_cast<int64_t>(army.unique_id);
				entry["name"] = convert_to<String>(army.get_name());
				entry["regiments"] = static_cast<int32_t>(army.get_unit_count());
				loadable.push_back(entry);
			}
		}
		result["loadable"] = loadable;

		// Coasts next to the sea where the carried armies can land
		Array targets;
		if (at_sea) {
			for (ProvinceDefinition::adjacency_t const& adjacency : location.province_definition.get_adjacencies()) {
				ProvinceDefinition const& to = adjacency.get_to();
				if (to.is_water() || adjacency.get_type() != ProvinceDefinition::adjacency_t::type_t::COASTAL) {
					continue;
				}
				ProvinceInstance const& target = instance_manager.get_map_instance().get_province_instance_by_definition(to);
				if (!UnitInstanceGroup::can_country_enter(country, target)) {
					continue;
				}
				Dictionary entry;
				entry["number"] = static_cast<int32_t>(to.get_province_number());
				entry["name"] = menu_singleton.tr(convert_to<String>(target.get_identifier()));
				entry["hostile"] = target.get_owner() != &country && target.get_controller() != &country;
				targets.push_back(entry);
			}
		}
		result["landing_targets"] = targets;

		// Blockade: the fleet sits in front of a port of an enemy
		result["blockading"] = at_sea && [&]() -> bool {
			WarManager const& war_manager = instance_manager.get_war_manager();
			for (ProvinceInstance const& port : instance_manager.get_map_instance().get_province_instances()) {
				if (port.province_definition.get_port_adjacent_province() == &location.province_definition
					&& war_manager.is_blockaded(port) && port.get_owner() != nullptr && port.get_owner()->is_at_war_with(country)) {
					return true;
				}
			}
			return false;
		}();

		return result;
	}

	ArmyInstance* get_player_army(InstanceManager& instance_manager, CountryInstance const* player, const int64_t army_id) {
		UnitInstanceGroup* const group = instance_manager.get_unit_instance_manager().get_unit_instance_group_by_unique_id(
			static_cast<unique_id_t>(army_id)
		);
		if (group == nullptr || group->branch != unit_branch_t::LAND || &group->get_country() != player) {
			return nullptr;
		}
		return static_cast<ArmyInstance*>(group);
	}
}

Dictionary PlayerSingleton::get_army_details(int64_t army_id) const {
	Dictionary result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MenuSingleton* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, result);

	// Any army can be looked at, but only the armies of the player can be ordered
	UnitInstanceGroup* const group = instance_manager->get_unit_instance_manager().get_unit_instance_group_by_unique_id(
		static_cast<unique_id_t>(army_id)
	);
	if (group == nullptr) {
		return result;
	}
	if (group->branch == unit_branch_t::NAVAL) {
		return make_fleet_details(*instance_manager, *menu_singleton, static_cast<NavyInstance const&>(*group), player_country);
	}
	ArmyInstance const& army = static_cast<ArmyInstance const&>(*group);
	CountryInstance const& country = army.get_country();
	result["is_navy"] = false;

	result["id"] = static_cast<int64_t>(army.unique_id);
	result["name"] = convert_to<String>(army.get_name());
	result["country_index"] = static_cast<int32_t>(type_safe::get(country.index));
	result["country_name"] = Utilities::get_country_name(*menu_singleton, country);
	result["is_player"] = &country == player_country;
	result["province_number"] = static_cast<int32_t>(army.get_location().province_definition.get_province_number());
	result["province_identifier"] = convert_to<String>(army.get_location().get_identifier());
	result["province_name"] = menu_singleton->tr(convert_to<String>(army.get_location().get_identifier()));
	result["regiments"] = static_cast<int32_t>(army.get_unit_count());
	result["strength"] = static_cast<float>(army.get_total_strength());
	result["max_strength"] = static_cast<float>(army.get_total_max_strength());
	result["organisation"] = static_cast<float>(army.get_organisation_proportion());
	result["dig_in"] = static_cast<int32_t>(army.get_dig_in_level());
	result["dig_in_cap"] = static_cast<int32_t>(country.get_dig_in_cap());
	result["moving"] = army.is_moving();
	result["in_combat"] = army.is_in_combat();
	result["supply"] = static_cast<float>(country.get_army_supply_ratio());
	result["speed"] = static_cast<float>(army.get_movement_speed());
	result["eta_days"] = army.get_movement_days_left();

	ProvinceInstance const* destination = army.get_movement_destination_province();
	result["destination_number"] =
		destination != nullptr ? static_cast<int32_t>(destination->province_definition.get_province_number()) : 0;
	result["destination_name"] =
		destination != nullptr ? menu_singleton->tr(convert_to<String>(destination->get_identifier())) : String {};

	int32_t front_id = 0;
	for (Front const& front : instance_manager->get_war_manager().get_fronts()) {
		if (front.country == &country) {
			for (const unique_id_t front_army : front.army_ids) {
				if (front_army == army.unique_id) {
					front_id = static_cast<int32_t>(front.id);
				}
			}
		}
	}
	result["front_id"] = front_id;

	LeaderInstance const* leader = army.get_leader();
	result["leader_id"] = leader != nullptr ? static_cast<int64_t>(leader->unique_id) : 0;
	if (leader != nullptr) {
		result["leader"] = menu_singleton->make_leader_dict(*leader);
	}

	Array units;
	for (UnitInstance const& unit : army.get_units()) {
		Dictionary entry;
		entry["id"] = static_cast<int64_t>(unit.unique_id);
		entry["name"] = convert_to<String>(unit.get_name());
		entry["type_identifier"] = convert_to<String>(unit.unit_type.get_identifier());
		entry["type_name"] = menu_singleton->tr(convert_to<String>(unit.unit_type.get_identifier()));
		entry["strength"] = static_cast<float>(unit.get_strength());
		entry["max_strength"] = static_cast<float>(unit.get_max_strength());
		entry["organisation"] = static_cast<float>(unit.get_organisation());
		entry["max_organisation"] = static_cast<float>(unit.get_max_organisation());
		Pop const* pop = static_cast<RegimentInstance const&>(unit).get_pop();
		entry["pop_type"] = pop != nullptr ? menu_singleton->tr(convert_to<String>(pop->get_type().get_identifier())) : String {};
		entry["pop_culture"] =
			pop != nullptr ? menu_singleton->tr(convert_to<String>(pop->culture.get_identifier())) : String {};
		units.push_back(entry);
	}
	result["units"] = units;

	return result;
}

namespace {
	Array make_leader_list(CountryInstance const* player, MenuSingleton* menu_singleton, const unit_branch_t branch) {
		Array result;
		const auto add = [&](auto const& leaders) -> void {
			for (LeaderInstance const& leader : leaders) {
				Dictionary entry = menu_singleton->make_leader_dict(leader).duplicate();
				entry["leader_id"] = static_cast<int64_t>(leader.unique_id);
				entry["prestige"] = static_cast<float>(leader.get_prestige());
				entry["personality"] = leader.get_personality() != nullptr
					? menu_singleton->tr(convert_to<String>(leader.get_personality()->get_identifier())) : String {};
				entry["background"] = leader.get_background() != nullptr
					? menu_singleton->tr(convert_to<String>(leader.get_background()->get_identifier())) : String {};
				UnitInstanceGroup const* group = leader.get_unit_instance_group();
				entry["army_id"] = group != nullptr ? static_cast<int64_t>(group->unique_id) : 0;
				entry["army_name"] = group != nullptr ? convert_to<String>(group->get_name()) : String {};
				result.push_back(entry);
			}
		};
		if (branch == unit_branch_t::LAND) {
			add(player->get_leaders<unit_branch_t::LAND>());
		} else {
			add(player->get_leaders<unit_branch_t::NAVAL>());
		}
		return result;
	}
}

Array PlayerSingleton::get_generals() const {
	ERR_FAIL_NULL_V(player_country, Array {});
	MenuSingleton* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, Array {});
	return make_leader_list(player_country, menu_singleton, unit_branch_t::LAND);
}

Array PlayerSingleton::get_admirals() const {
	ERR_FAIL_NULL_V(player_country, Array {});
	MenuSingleton* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, Array {});
	return make_leader_list(player_country, menu_singleton, unit_branch_t::NAVAL);
}

Array PlayerSingleton::get_mergeable_armies(int64_t army_id) const {
	Array result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);

	ArmyInstance* const army = get_player_army(*instance_manager, player_country, army_id);
	if (army == nullptr) {
		return result;
	}
	for (ArmyInstance const& other : army->get_location().get_armies()) {
		if (&other == army || &other.get_country() != player_country || other.is_moving() || other.is_in_combat()) {
			continue;
		}
		Dictionary entry;
		entry["id"] = static_cast<int64_t>(other.unique_id);
		entry["name"] = convert_to<String>(other.get_name());
		entry["regiments"] = static_cast<int32_t>(other.get_unit_count());
		result.push_back(entry);
	}
	return result;
}

Dictionary PlayerSingleton::get_leader_settings() const {
	Dictionary result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);

	const fixed_point_t cost = GameSingleton::get_singleton()->get_definition_manager().get_define_manager()
		.get_military_defines().get_leader_recruit_cost();
	result["auto_create"] = player_country->get_auto_create_leaders();
	result["auto_assign"] = player_country->get_auto_assign_leaders();
	result["leadership_points"] = static_cast<float>(player_country->get_leadership_point_stockpile());
	result["monthly_leadership_points"] = static_cast<float>(player_country->get_monthly_leadership_points());
	result["leader_cost"] = static_cast<float>(cost);
	result["can_create"] = player_country->get_leadership_point_stockpile() >= cost;
	return result;
}

bool PlayerSingleton::set_leader_auto(bool auto_create, bool auto_assign) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	bool changed = false;
	if (player_country->get_auto_create_leaders() != auto_create) {
		changed |= instance_manager->queue_game_action<set_auto_create_leaders_argument_t>(player_country->index, auto_create);
	}
	if (player_country->get_auto_assign_leaders() != auto_assign) {
		changed |= instance_manager->queue_game_action<set_auto_assign_leaders_argument_t>(player_country->index, auto_assign);
	}
	return changed;
}

bool PlayerSingleton::create_general() const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	return instance_manager->queue_game_action<create_leader_argument_t>(player_country->index, unit_branch_t::LAND);
}

bool PlayerSingleton::split_regiment(int64_t regiment_id) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	UnitInstance* const unit =
		instance_manager->get_unit_instance_manager().get_unit_instance_by_unique_id(static_cast<unique_id_t>(regiment_id));
	ERR_FAIL_NULL_V(unit, false);
	ArmyInstance* const army = instance_manager->get_unit_instance_manager().get_army_of_regiment(
		static_cast<RegimentInstance&>(*unit)
	);
	ERR_FAIL_COND_V(army == nullptr || &army->get_country() != player_country, false);
	return instance_manager->queue_game_action<split_regiment_argument_t>(static_cast<unique_id_t>(regiment_id));
}

bool PlayerSingleton::merge_armies(int64_t target_army_id, int64_t source_army_id) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_NULL_V(get_player_army(*instance_manager, player_country, target_army_id), false);
	ERR_FAIL_NULL_V(get_player_army(*instance_manager, player_country, source_army_id), false);
	return instance_manager->queue_game_action<merge_armies_argument_t>(
		static_cast<unique_id_t>(target_army_id), static_cast<unique_id_t>(source_army_id)
	);
}

bool PlayerSingleton::set_army_leader(int64_t army_id, int64_t leader_id) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	UnitInstanceGroup* const leader_group = instance_manager->get_unit_instance_manager().get_unit_instance_group_by_unique_id(
		static_cast<unique_id_t>(army_id)
	);
	ERR_FAIL_NULL_V(leader_group, false);
	ERR_FAIL_COND_V(&leader_group->get_country() != player_country, false);
	return instance_manager->queue_game_action<set_army_leader_argument_t>(
		static_cast<unique_id_t>(army_id), static_cast<unique_id_t>(leader_id)
	);
}

bool PlayerSingleton::disband_regiment(int64_t regiment_id) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	UnitInstance* const unit =
		instance_manager->get_unit_instance_manager().get_unit_instance_by_unique_id(static_cast<unique_id_t>(regiment_id));
	ERR_FAIL_NULL_V(unit, false);
	ArmyInstance* const army = instance_manager->get_unit_instance_manager().get_army_of_regiment(
		static_cast<RegimentInstance&>(*unit)
	);
	ERR_FAIL_COND_V(army == nullptr || &army->get_country() != player_country, false);
	return instance_manager->queue_game_action<disband_regiment_argument_t>(static_cast<unique_id_t>(regiment_id));
}

bool PlayerSingleton::disband_army(int64_t army_id) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_NULL_V(get_player_army(*instance_manager, player_country, army_id), false);
	return instance_manager->queue_game_action<disband_army_argument_t>(static_cast<unique_id_t>(army_id));
}

Dictionary PlayerSingleton::get_recruitment_info(int32_t province_number) const {
	Dictionary result;
	ERR_FAIL_NULL_V(player_country, result);
	GameSingleton* game_singleton = GameSingleton::get_singleton();
	InstanceManager* instance_manager = game_singleton->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MenuSingleton* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, result);

	ProvinceInstance const* province = instance_manager->get_map_instance().get_province_instance_from_number(province_number);
	ERR_FAIL_NULL_V(province, result);

	result["province_number"] = province_number;
	result["province_name"] = menu_singleton->tr(convert_to<String>(province->get_identifier()));
	result["owned"] = province->get_owner() == player_country && province->get_controller() == player_country;

	Array regiment_types;
	for (RegimentType const& regiment_type :
		 game_singleton->get_definition_manager().get_military_manager().get_unit_type_manager().get_regiment_types()) {
		Dictionary entry;
		entry["index"] = static_cast<int32_t>(type_safe::get(regiment_type.index));
		entry["identifier"] = convert_to<String>(regiment_type.get_identifier());
		entry["name"] = menu_singleton->tr(convert_to<String>(regiment_type.get_identifier()));
		entry["days"] = UnitInstanceManager::get_recruitment_days(*player_country, regiment_type);
		entry["unlocked"] = player_country->is_unit_type_unlocked(regiment_type);

		Array cost;
		for (auto const& [good, amount] : regiment_type.get_build_cost()) {
			Dictionary cost_entry;
			cost_entry["good_name"] = menu_singleton->tr(convert_to<String>(good->get_identifier()));
			cost_entry["amount"] = static_cast<float>(amount);
			cost_entry["have"] = static_cast<float>(player_country->get_good_data(*good).stockpile_amount);
			cost.push_back(cost_entry);
		}
		entry["cost"] = cost;
		regiment_types.push_back(entry);
	}
	result["regiment_types"] = regiment_types;

	Array pops;
	for (Pop const& pop : province->get_pops()) {
		Dictionary entry;
		entry["id"] = static_cast<int32_t>(type_safe::get(pop.id_in_province));
		entry["type_name"] = menu_singleton->tr(convert_to<String>(pop.get_type().get_identifier()));
		entry["culture_name"] = menu_singleton->tr(convert_to<String>(pop.culture.get_identifier()));
		entry["size"] = static_cast<int32_t>(type_safe::get(pop.get_size()));
		entry["regiments"] = static_cast<int32_t>(pop.get_regiment_count());
		entry["max_regiments"] = static_cast<int32_t>(pop.get_max_supported_regiments());
		entry["recruitable"] = pop.get_type().can_be_recruited;
		entry["culture_ok"] = Pop::is_culture_status_allowed(
			player_country->get_allowed_regiment_cultures(), pop.get_culture_status()
		);
		pops.push_back(entry);
	}
	result["pops"] = pops;

	return result;
}

String PlayerSingleton::get_recruitment_block_reason(int32_t regiment_type_index, int32_t province_number, int32_t pop_id) const {
	ERR_FAIL_NULL_V(player_country, String {});
	GameSingleton* game_singleton = GameSingleton::get_singleton();
	InstanceManager* instance_manager = game_singleton->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, String {});

	RegimentType const* regiment_type = game_singleton->get_definition_manager().get_military_manager()
		.get_unit_type_manager().get_regiment_type_by_index(regiment_type_index_t(regiment_type_index));
	ERR_FAIL_NULL_V(regiment_type, String {});
	ProvinceInstance const* province = instance_manager->get_map_instance().get_province_instance_from_number(province_number);
	ERR_FAIL_NULL_V(province, String {});
	Pop const* pop = province->find_pop_by_id(pop_id_in_province_t(static_cast<size_t>(pop_id)));
	ERR_FAIL_NULL_V(pop, String {});

	return String::utf8(
		UnitInstanceManager::get_recruitment_block_reason(*player_country, *regiment_type, *province, *pop).data()
	);
}

bool PlayerSingleton::start_recruitment(int32_t regiment_type_index, int32_t province_number, int32_t pop_id) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);

	ProvinceInstance const* province = instance_manager->get_map_instance().get_province_instance_from_number(province_number);
	ERR_FAIL_NULL_V(province, false);
	ERR_FAIL_COND_V(province->get_owner() != player_country, false);

	return instance_manager->queue_game_action<start_land_unit_recruitment_argument_t>(
		regiment_type_index_t(regiment_type_index), province->index, pop_id_in_province_t(static_cast<size_t>(pop_id))
	);
}

Array PlayerSingleton::get_recruitment_queue() const {
	Array result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MenuSingleton* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, result);

	for (RecruitmentOrder const& order : instance_manager->get_unit_instance_manager().get_recruitment_orders()) {
		if (order.country != player_country) {
			continue;
		}
		Dictionary entry;
		entry["id"] = static_cast<int64_t>(order.id);
		entry["type_name"] = menu_singleton->tr(convert_to<String>(
			order.ship_type != nullptr ? order.ship_type->get_identifier() : order.regiment_type->get_identifier()
		));
		entry["is_ship"] = order.ship_type != nullptr;
		entry["province_number"] = static_cast<int32_t>(order.province->province_definition.get_province_number());
		entry["province_name"] = menu_singleton->tr(convert_to<String>(order.province->get_identifier()));
		entry["days_left"] = order.days_left;
		entry["days_total"] = order.days_total;
		result.push_back(entry);
	}
	return result;
}

bool PlayerSingleton::cancel_recruitment(int64_t order_id) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	return instance_manager->queue_game_action<cancel_recruitment_argument_t>(
		player_country->index, static_cast<unique_id_t>(order_id)
	);
}

// Fleets: transport and ship building
bool PlayerSingleton::load_army(int64_t army_id, int64_t navy_id) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_NULL_V(get_player_army(*instance_manager, player_country, army_id), false);
	return instance_manager->queue_game_action<load_army_argument_t>(static_cast<unique_id_t>(army_id), static_cast<unique_id_t>(navy_id));
}

bool PlayerSingleton::unload_army(int64_t army_id) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_NULL_V(get_player_army(*instance_manager, player_country, army_id), false);
	return instance_manager->queue_game_action<unload_army_argument_t>(static_cast<unique_id_t>(army_id));
}

bool PlayerSingleton::land_army(int64_t army_id, int32_t province_number) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_NULL_V(get_player_army(*instance_manager, player_country, army_id), false);
	ProvinceInstance const* province = instance_manager->get_map_instance().get_province_instance_from_number(province_number);
	ERR_FAIL_NULL_V(province, false);
	return instance_manager->queue_game_action<land_army_argument_t>(static_cast<unique_id_t>(army_id), province->index);
}

Array PlayerSingleton::get_ship_types(int32_t province_number) const {
	Array result;
	ERR_FAIL_NULL_V(player_country, result);
	GameSingleton* game_singleton = GameSingleton::get_singleton();
	InstanceManager* instance_manager = game_singleton->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MenuSingleton* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, result);
	ProvinceInstance const* province = instance_manager->get_map_instance().get_province_instance_from_number(province_number);
	ERR_FAIL_NULL_V(province, result);

	for (ShipType const& ship_type :
		 game_singleton->get_definition_manager().get_military_manager().get_unit_type_manager().get_ship_types()) {
		Dictionary entry;
		entry["index"] = static_cast<int32_t>(type_safe::get(ship_type.index));
		entry["identifier"] = convert_to<String>(ship_type.get_identifier());
		entry["name"] = menu_singleton->tr(convert_to<String>(ship_type.get_identifier()));
		entry["days"] = UnitInstanceManager::get_recruitment_days(*player_country, ship_type);
		entry["unlocked"] = player_country->is_unit_type_unlocked(ship_type);
		entry["transport"] = ship_type.is_transport;
		entry["hull"] = static_cast<float>(ship_type.hull);
		entry["gun_power"] = static_cast<float>(ship_type.gun_power);
		entry["min_port_level"] = static_cast<int32_t>(ship_type.min_port_level);
		entry["reason"] = String::utf8(
			instance_manager->get_unit_instance_manager().get_ship_block_reason(*player_country, ship_type, *province).data()
		);

		Array cost;
		for (auto const& [good, amount] : ship_type.get_build_cost()) {
			Dictionary cost_entry;
			cost_entry["good_name"] = menu_singleton->tr(convert_to<String>(good->get_identifier()));
			cost_entry["amount"] = static_cast<float>(amount);
			cost_entry["have"] = static_cast<float>(player_country->get_good_data(*good).stockpile_amount);
			cost.push_back(cost_entry);
		}
		entry["cost"] = cost;
		result.push_back(entry);
	}
	return result;
}

bool PlayerSingleton::start_ship_building(int32_t ship_type_index, int32_t province_number) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ProvinceInstance const* province = instance_manager->get_map_instance().get_province_instance_from_number(province_number);
	ERR_FAIL_NULL_V(province, false);
	ERR_FAIL_COND_V(province->get_owner() != player_country, false);
	return instance_manager->queue_game_action<start_ship_building_argument_t>(ship_type_index_t(ship_type_index), province->index);
}

Dictionary PlayerSingleton::get_blockade_info() const {
	Dictionary result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MenuSingleton* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, result);

	WarManager const& war_manager = instance_manager->get_war_manager();
	result["share"] = static_cast<float>(war_manager.get_blockade_share(*player_country));

	Array our_ports, enemy_ports;
	for (ProvinceInstance const& province : instance_manager->get_map_instance().get_province_instances()) {
		if (!war_manager.is_blockaded(province) || province.get_owner() == nullptr) {
			continue;
		}
		Dictionary entry;
		entry["number"] = static_cast<int32_t>(province.province_definition.get_province_number());
		entry["name"] = menu_singleton->tr(convert_to<String>(province.get_identifier()));
		entry["owner"] = Utilities::get_country_name(*menu_singleton, *province.get_owner());
		if (province.get_owner() == player_country) {
			our_ports.push_back(entry);
		} else if (province.get_owner()->is_at_war_with(*player_country)) {
			enemy_ports.push_back(entry);
		}
	}
	result["our_blockaded_ports"] = our_ports;
	result["enemy_blockaded_ports"] = enemy_ports;
	return result;
}

// Peace negotiations
namespace {
	String state_name(MenuSingleton& menu_singleton, ProvinceInstance const& state_province) {
		return menu_singleton.tr(convert_to<String>(state_province.get_identifier()));
	}

	Dictionary make_offer_entry(
		MenuSingleton& menu_singleton, WarManager const& war_manager, War const& war, PeaceOffer const& offer, Date const today
	) {
		Dictionary entry;
		entry["war_id"] = static_cast<int32_t>(offer.war_id);
		entry["from_name"] = Utilities::get_country_name(menu_singleton, *offer.from);
		entry["concede"] = offer.terms.concede;
		Array states;
		for (ProvinceInstance const* state : offer.terms.states) {
			states.push_back(state_name(menu_singleton, *state));
		}
		entry["states"] = states;
		entry["reparations"] = offer.terms.reparations;
		entry["humiliate"] = offer.terms.humiliate;
		entry["cost"] = static_cast<float>(war_manager.get_terms_cost(war, *offer.from, offer.terms));
		entry["days_left"] = WarManager::OFFER_VALID_DAYS - static_cast<int32_t>((today - offer.date).to_int());
		return entry;
	}
}

Dictionary PlayerSingleton::get_peace_info(int32_t war_id) const {
	Dictionary result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MenuSingleton* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, result);

	WarManager& war_manager = instance_manager->get_war_manager();
	War const* war = war_manager.get_war_by_id(static_cast<std::uint32_t>(war_id));
	if (war == nullptr || !war->has_participant(*player_country)) {
		return result;
	}
	const bool we_attack = war->is_attacker(*player_country);
	const Date today = instance_manager->get_today();

	result["war_id"] = war_id;
	result["we_attack"] = we_attack;
	result["days"] = static_cast<int32_t>((today - war->start_date).to_int());
	result["our_score"] = static_cast<float>(war->get_score(we_attack));
	result["their_score"] = static_cast<float>(war->get_score(!we_attack));
	result["goal_type"] = static_cast<int32_t>(war->goal.type);
	result["goal_name"] = war->goal.state_province != nullptr ? state_name(*menu_singleton, *war->goal.state_province) : String {};

	Array attackers, defenders;
	for (CountryInstance const* country : war->attackers) {
		attackers.push_back(Utilities::get_country_name(*menu_singleton, *country));
	}
	for (CountryInstance const* country : war->defenders) {
		defenders.push_back(Utilities::get_country_name(*menu_singleton, *country));
	}
	result["attackers"] = attackers;
	result["defenders"] = defenders;

	PeaceTerms const* draft_ptr = war_manager.find_peace_draft(*player_country);
	PeaceTerms draft;
	if (draft_ptr != nullptr && draft_ptr->war_id == static_cast<std::uint32_t>(war_id)) {
		draft = *draft_ptr;
	}
	draft.war_id = static_cast<std::uint32_t>(war_id);
	result["concede"] = draft.concede;
	result["reparations"] = draft.reparations;
	result["humiliate"] = draft.humiliate;
	result["reparations_cost"] = WarManager::REPARATIONS_COST;
	result["humiliate_cost"] = WarManager::HUMILIATE_COST;

	const bool winners_are_attackers = draft.concede ? !we_attack : we_attack;
	Array states;
	for (ProvinceInstance const* candidate : war_manager.get_peace_candidates(*war, *player_country, draft.concede)) {
		Dictionary entry;
		entry["province_number"] = static_cast<int32_t>(candidate->province_definition.get_province_number());
		entry["name"] = state_name(*menu_singleton, *candidate);
		entry["owner_name"] = candidate->get_owner() != nullptr ? Utilities::get_country_name(*menu_singleton, *candidate->get_owner()) : String {};
		entry["cost"] = static_cast<float>(war_manager.get_state_cost(*war, winners_are_attackers, *candidate));
		bool selected = false;
		for (ProvinceInstance const* chosen : draft.states) {
			selected = selected || chosen == candidate
				|| (chosen->get_state() != nullptr && chosen->get_state() == candidate->get_state());
		}
		entry["selected"] = selected;
		entry["is_goal"] = war->goal.type == WarGoal::type_t::CONQUER_STATE && war->goal.state_province != nullptr
			&& (war->goal.state_province == candidate
				|| (war->goal.state_province->get_state() != nullptr && war->goal.state_province->get_state() == candidate->get_state()));
		states.push_back(entry);
	}
	result["states"] = states;

	const fixed_point_t cost = war_manager.get_terms_cost(*war, *player_country, draft);
	result["cost"] = static_cast<float>(cost);
	result["available"] = static_cast<float>(draft.concede ? war->get_score(!we_attack) : war->get_score(we_attack));

	memory::string reason;
	result["accepts"] = war_manager.evaluate_offer(*instance_manager, *war, we_attack, draft, &reason);
	result["reason"] = String::utf8(reason.c_str());

	if (PeaceResponse const* response = war_manager.get_last_response(*player_country)) {
		Dictionary last;
		last["accepted"] = response->accepted;
		last["text"] = String::utf8(response->text.c_str());
		last["days_ago"] = static_cast<int32_t>((today - response->date).to_int());
		result["last_response"] = last;
	}

	Array offers;
	for (PeaceOffer const& offer : war_manager.get_offers_for(*player_country)) {
		if (offer.war_id == static_cast<std::uint32_t>(war_id)) {
			offers.push_back(make_offer_entry(*menu_singleton, war_manager, *war, offer, today));
		}
	}
	result["offers"] = offers;
	return result;
}

bool PlayerSingleton::set_peace_demand(int32_t war_id, int32_t kind, int32_t province_number, bool enabled) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(war_id <= 0 || kind < 0, false);

	ProvinceInstance const* province = province_number > 0
		? instance_manager->get_map_instance().get_province_instance_from_number(province_number) : nullptr;
	province_index_t index = province != nullptr ? province->index : province_index_t(0);
	return instance_manager->queue_game_action<set_peace_demand_argument_t>(
		player_country->index, static_cast<std::uint32_t>(war_id), static_cast<std::uint32_t>(kind), index, enabled
	);
}

bool PlayerSingleton::send_peace_offer(int32_t war_id) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(war_id <= 0, false);
	return instance_manager->queue_game_action<send_peace_offer_argument_t>(player_country->index, static_cast<std::uint32_t>(war_id));
}

bool PlayerSingleton::answer_peace_offer(int32_t war_id, bool accept) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(war_id <= 0, false);
	return instance_manager->queue_game_action<answer_peace_offer_argument_t>(
		player_country->index, static_cast<std::uint32_t>(war_id), accept
	);
}

Array PlayerSingleton::get_peace_offers() const {
	Array result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MenuSingleton* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, result);

	WarManager const& war_manager = instance_manager->get_war_manager();
	for (PeaceOffer const& offer : war_manager.get_offers_for(*player_country)) {
		War const* war = war_manager.get_war_by_id(offer.war_id);
		if (war != nullptr) {
			result.push_back(make_offer_entry(*menu_singleton, war_manager, *war, offer, instance_manager->get_today()));
		}
	}
	return result;
}

Array PlayerSingleton::get_declarable_countries() const {
	Array result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MenuSingleton* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, result);

	WarManager const& war_manager = instance_manager->get_war_manager();
	for (CountryInstance const& country : instance_manager->get_country_instance_manager().get_country_instances()) {
		if (!war_manager.can_declare_war(*player_country, country, instance_manager->get_today())) {
			continue;
		}
		Dictionary entry;
		entry["index"] = static_cast<int32_t>(type_safe::get(country.index));
		entry["name"] = Utilities::get_country_name(*menu_singleton, country);
		result.push_back(entry);
	}
	return result;
}

Array PlayerSingleton::get_war_goal_states(int32_t country_index) const {
	Array result;
	ERR_FAIL_NULL_V(player_country, result);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MenuSingleton* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, result);
	ERR_FAIL_COND_V(country_index < 0, result);

	CountryInstance const& country = instance_manager->get_country_instance_manager().get_country_instance_by_index(
		country_index_t(static_cast<size_t>(country_index))
	);
	std::unordered_set<State const*> seen;
	for (ProvinceInstance const* province : country.get_owned_provinces()) {
		State const* state = province->get_state();
		if (state != nullptr && !seen.insert(state).second) {
			continue;
		}
		ProvinceInstance const* key = state != nullptr && state->get_capital() != nullptr ? state->get_capital() : province;
		Dictionary entry;
		entry["province_number"] = static_cast<int32_t>(key->province_definition.get_province_number());
		entry["name"] = state_name(*menu_singleton, *key);
		result.push_back(entry);
	}
	return result;
}

bool PlayerSingleton::declare_war_with_goal(int32_t country_index, int32_t goal_type, int32_t province_number) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(country_index < 0 || goal_type < 0, false);

	ProvinceInstance const* province = province_number > 0
		? instance_manager->get_map_instance().get_province_instance_from_number(province_number) : nullptr;
	province_index_t index = province != nullptr ? province->index : province_index_t(0);
	return instance_manager->queue_game_action<declare_war_goal_argument_t>(
		player_country->index, country_index_t(static_cast<size_t>(country_index)), static_cast<std::uint32_t>(goal_type), index
	);
}

Array PlayerSingleton::get_market_overview() const {
	Array result;
	ERR_FAIL_NULL_V(player_country, result);
	GameSingleton* game_singleton = GameSingleton::get_singleton();
	InstanceManager* instance_manager = game_singleton->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MenuSingleton* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, result);

	GoodInstanceManager const& good_instance_manager = instance_manager->get_good_instance_manager();
	for (GoodCategory const& category : game_singleton->get_definition_manager().get_economy_manager().get_good_definition_manager().get_good_categories()) {
		for (GoodDefinition const& good_definition : category.get_good_definitions()) {
			GoodInstance const& good = good_instance_manager.get_good_instance_by_definition(good_definition);
			if (!good.is_trading_good()) {
				continue;
			}
			Dictionary entry;
			entry["name"] = menu_singleton->tr(convert_to<String>(good_definition.get_identifier()));
			entry["category"] = menu_singleton->tr(convert_to<String>(category.get_identifier()));
			entry["price"] = static_cast<float>(good.get_price());
			entry["price_change"] = static_cast<float>(good.get_price_change_yesterday());
			entry["base_price"] = static_cast<float>(good_definition.base_price);
			entry["supply"] = static_cast<float>(good.get_total_supply_yesterday());
			entry["demand"] = static_cast<float>(good.get_total_demand_yesterday());
			entry["traded"] = static_cast<float>(good.get_quantity_traded_yesterday());
			entry["stockpile"] = static_cast<float>(player_country->get_good_data(good).stockpile_amount);

			PackedFloat32Array history;
			for (fixed_point_t const& price : good.get_price_history()) {
				history.push_back(static_cast<float>(price));
			}
			entry["price_history"] = history;
			result.push_back(entry);
		}
	}
	return result;
}

Dictionary PlayerSingleton::get_politics_info() const {
	Dictionary result;
	ERR_FAIL_NULL_V(player_country, result);
	GameSingleton* game_singleton = GameSingleton::get_singleton();
	InstanceManager* instance_manager = game_singleton->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, result);
	MenuSingleton* menu_singleton = MenuSingleton::get_singleton();
	ERR_FAIL_NULL_V(menu_singleton, result);

	PoliticsManager const& politics = game_singleton->get_definition_manager().get_politics_manager();
	CountryInstance const& country = *player_country;
	const Date today = instance_manager->get_today();
	const double total_population = static_cast<double>(type_safe::get(country.get_total_population()));

	GovernmentType const* government = country.get_government_type_untracked();
	result["government"] = government != nullptr ? menu_singleton->tr(convert_to<String>(government->get_identifier())) : String {};
	CountryParty const* ruling = country.get_ruling_party_untracked();
	result["ruling_party"] = ruling != nullptr ? menu_singleton->tr(convert_to<String>(ruling->get_identifier())) : String {};
	result["ruling_ideology"] = ruling != nullptr && ruling->ideology != nullptr
		? menu_singleton->tr(convert_to<String>(ruling->ideology->get_identifier())) : String {};
	result["holds_elections"] = government != nullptr && government->holds_elections;
	int32_t days_to_election = -1;
	if (government != nullptr && government->holds_elections && country.get_last_election() != Date {}) {
		days_to_election = static_cast<int32_t>((country.get_last_election() + government->term_duration - today).to_int());
	}
	result["days_to_election"] = days_to_election;

	// Parties and their votes
	Array parties;
	double votes_total = 0.0;
	for (CountryParty const& party : country.country_definition.get_parties()) {
		votes_total += static_cast<double>(country.get_vote_equivalents_by_party(party));
	}
	result["voters_share"] = total_population > 0.0 ? static_cast<float>(votes_total / total_population) : 0.0f;
	for (CountryParty const& party : country.country_definition.get_parties()) {
		if (!(party.start_date <= today && today <= party.end_date)) {
			continue;
		}
		Dictionary entry;
		entry["name"] = menu_singleton->tr(convert_to<String>(party.get_identifier()));
		entry["ideology"] = party.ideology != nullptr ? menu_singleton->tr(convert_to<String>(party.ideology->get_identifier())) : String {};
		entry["vote_share"] = votes_total > 0.0 ? static_cast<float>(static_cast<double>(country.get_vote_equivalents_by_party(party)) / votes_total) : 0.0f;
		entry["ruling"] = &party == ruling;
		entry["colour"] = convert_to<Color>(party.get_colour());
		parties.push_back(entry);
	}
	result["parties"] = parties;

	Array ideologies, upper_house;
	for (Ideology const& ideology : politics.get_ideology_manager().get_ideologies()) {
		Dictionary entry;
		entry["name"] = menu_singleton->tr(convert_to<String>(ideology.get_identifier()));
		entry["colour"] = convert_to<Color>(ideology.get_colour());
		entry["share"] = total_population > 0.0
			? static_cast<float>(static_cast<double>(country.get_supporter_equivalents_by_ideology()[ideology.index]) / total_population) : 0.0f;
		ideologies.push_back(entry);

		Dictionary house = entry.duplicate();
		house["share"] = static_cast<float>(country.get_upper_house_proportion_by_ideology().at(ideology));
		upper_house.push_back(house);
	}
	result["ideologies"] = ideologies;
	result["upper_house"] = upper_house;

	// Reforms
	Array groups;
	for (ReformGroup const& group : politics.get_issue_manager().get_reform_groups()) {
		Dictionary group_entry;
		group_entry["name"] = menu_singleton->tr(convert_to<String>(group.get_identifier()));
		group_entry["type"] = menu_singleton->tr(convert_to<String>(group.reform_type.get_identifier()));
		group_entry["ordered"] = group.is_ordered;
		group_entry["civilizing"] = group.is_civilizing();
		Array options;
		Reform const* current = country.get_reforms().at(group);
		for (Reform const& reform : group.get_reforms()) {
			PoliticsDynamics::ReformStatus status = PoliticsDynamics::get_reform_status(*instance_manager, country, reform);
			Dictionary option;
			option["index"] = static_cast<int32_t>(type_safe::get(reform.index));
			option["name"] = menu_singleton->tr(convert_to<String>(reform.get_identifier()));
			option["current"] = &reform == current;
			option["support"] = static_cast<float>(status.support);
			option["upper_house"] = static_cast<float>(status.upper_house);
			option["can_enact"] = status.can_enact;
			option["reason"] = String::utf8(status.reason.c_str());
			options.push_back(option);
		}
		group_entry["options"] = options;
		groups.push_back(group_entry);
	}
	result["groups"] = groups;

	// Unrest: average militancy, the most restless provinces and the risings in progress
	double militancy_sum = 0.0, people_sum = 0.0;
	std::vector<std::pair<double, ProvinceInstance const*>> restless;
	for (ProvinceInstance const* province : country.get_owned_provinces()) {
		double province_militancy = 0.0, province_people = 0.0;
		for (Pop const& pop : province->get_pops()) {
			const double size = static_cast<double>(type_safe::get(pop.get_size()));
			province_militancy += static_cast<double>(pop.get_militancy()) * size;
			province_people += size;
		}
		militancy_sum += province_militancy;
		people_sum += province_people;
		if (province_people > 0.0) {
			restless.emplace_back(province_militancy / province_people, province);
		}
	}
	result["average_militancy"] = people_sum > 0.0 ? static_cast<float>(militancy_sum / people_sum) : 0.0f;
	std::sort(restless.begin(), restless.end(), [](auto const& a, auto const& b) { return a.first > b.first; });
	Array restless_array;
	for (size_t i = 0; i < restless.size() && i < 6; ++i) {
		Dictionary entry;
		entry["name"] = menu_singleton->tr(convert_to<String>(restless[i].second->get_identifier()));
		entry["militancy"] = static_cast<float>(restless[i].first);
		restless_array.push_back(entry);
	}
	result["restless"] = restless_array;
	Array uprisings;
	for (auto const& uprising : RebelDynamics::get_uprisings(*instance_manager, country)) {
		Dictionary entry;
		entry["name"] = menu_singleton->tr(convert_to<String>(uprising.province->get_identifier()));
		entry["regiments"] = uprising.regiments;
		entry["strength"] = static_cast<float>(uprising.strength);
		uprisings.push_back(entry);
	}
	result["uprisings"] = uprisings;
	return result;
}

bool PlayerSingleton::enact_reform(int32_t reform_index) const {
	ERR_FAIL_NULL_V(player_country, false);
	InstanceManager* instance_manager = GameSingleton::get_singleton()->get_instance_manager();
	ERR_FAIL_NULL_V(instance_manager, false);
	ERR_FAIL_COND_V(reform_index < 0, false);
	return instance_manager->queue_game_action<enact_reform_argument_t>(player_country->index, reform_index_t(static_cast<size_t>(reform_index)));
}

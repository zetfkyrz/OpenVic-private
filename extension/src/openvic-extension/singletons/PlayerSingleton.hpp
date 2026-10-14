#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <openvic-simulation/core/object/FixedPoint.hpp>
#include <openvic-simulation/population/PopType.hpp>
#include <openvic-simulation/utility/Getters.hpp>

namespace OpenVic {
	struct CountryInstance;
	struct ProvinceInstance;
	struct GUIScrollbar;

	class PlayerSingleton : public godot::Object {
		GDCLASS(PlayerSingleton, godot::Object)

		static inline PlayerSingleton* singleton = nullptr;

		CountryInstance* player_country = nullptr;
		ProvinceInstance const* PROPERTY(selected_province, nullptr);

		static godot::StringName const& _signal_province_selected();

	protected:
		static void _bind_methods();

	public:
		static PlayerSingleton* get_singleton();

		PlayerSingleton();
		~PlayerSingleton();

		void reset_player_singleton();

		// Player country
		[[nodiscard]] constexpr CountryInstance* get_player_country() {
			return player_country;
		}
		[[nodiscard]] constexpr CountryInstance const* get_player_country() const {
			return player_country;
		}
		void set_player_country(CountryInstance* new_player_country);
		void set_player_country_by_province_number(int32_t province_number);
		godot::Vector2 get_player_country_capital_position() const;
		godot::String get_player_country_identifier() const;
		godot::String get_player_country_name() const;

		// Selected province
		void set_selected_province(ProvinceInstance const* new_selected_province);
		void set_selected_province_by_number(int32_t province_number);
		void unset_selected_province();
		int32_t get_selected_province_number() const;

		// Core
		void toggle_paused() const;
		void increase_speed() const;
		void decrease_speed() const;

		// Land armies on the map, one entry per country and province:
		// { province_number, position, country_identifier, country_index, is_player, army_count, regiments,
		//   strength, organisation, in_combat, moving, army_ids, siege_progress (-1 if none), occupied }
		godot::Array get_map_units() const;

		// Production
		void expand_selected_province_building(int32_t building_index) const;

		// Budget
		void set_administration_spending_slider_value(fixed_point_t const value) const;
		void set_education_spending_slider_value(fixed_point_t const value) const;
		void set_military_spending_slider_value(fixed_point_t const value) const;
		void set_social_spending_slider_value(fixed_point_t const value) const;
		void set_national_stockpile_army_spending_slider_value(fixed_point_t const value) const;
		void set_national_stockpile_navy_spending_slider_value(fixed_point_t const value) const;
		void set_national_stockpile_construction_spending_slider_value(fixed_point_t const value) const;
		void set_strata_tax_rate_slider_value(Strata const& strata, fixed_point_t const value) const;
		void set_tariff_rate_slider_value(fixed_point_t const value) const;

		// Production
		// Array of { province_index, name, free_slots, factories: [...], buildable: [...] } for the states of the player
		godot::Array get_production_info() const;
		bool build_factory(int32_t province_index, int32_t building_type_index) const;
		bool set_factory_subsidised(int32_t province_index, int32_t building_type_index, bool subsidised) const;
		// Actions for all factories of the player country
		bool set_all_factories_open(bool open) const;
		bool set_all_factories_subsidised(bool subsidised) const;
		bool expand_all_factories() const;
		// 0 = the state pays all losses of subsidised factories, 1 = state owned factories only, 2 = by ownership share
		bool set_subsidy_mode(int32_t mode) const;
		// { mode, state_paid, capitalists_paid } the subsidies of yesterday
		godot::Dictionary get_subsidy_info() const;
		// The state buys / sells a part (in percent) of a factory from / to the capitalists
		bool buy_factory_share(int32_t province_index, int32_t building_type_index, int32_t percent) const;
		bool sell_factory_share(int32_t province_index, int32_t building_type_index, int32_t percent) const;
		bool set_factory_open(int32_t province_index, int32_t building_type_index, bool open) const;

		// Technology
		// { folders: [{ index, identifier, name, researched_count, total_count, areas: [{ identifier, name,
		// technologies: [{ index, identifier, name, year, cost, status, position }] }] }], current: {...}, ... }
		// status: 0 = locked, 1 = can be researched, 2 = researched, 3 = being researched
		godot::Dictionary get_technology_info() const;
		bool start_research(int32_t technology_index) const;

		// Politics

		// Population

		// Trade
		void set_good_automated(int32_t good_index, bool is_automated) const;
		void set_good_trade_order(int32_t good_index, bool is_selling, GUIScrollbar const* amount_slider) const;

		// Diplomacy
		// Identifiers of all diplomatic actions, the position in the array is the index passed to send_diplomatic_action.
		godot::PackedStringArray get_diplomatic_action_identifiers() const;
		// Array of { index, identifier, name } dictionaries for all existing countries, sorted by name.
		godot::Array get_diplomacy_country_list() const;
		// Relation of the player country with the given country.
		godot::Dictionary get_diplomatic_relation(int32_t country_index) const;
		// Queues the action from the player country to the given country, returns whether it was queued.
		bool send_diplomatic_action(int32_t receiver_country_index, int32_t action_index) const;

		// Wars, armies and fronts
		// { wars: [{ id, we_attack, days, attacker_score, defender_score, attackers: [{ index, name }], defenders: [...] }],
		//   armies: [{ id, name, province_number, province_identifier, regiments, strength, max_strength, organisation,
		//              moving, destination_number, in_combat, front_id }],
		//   fronts: [{ id, mode, enemy_index, enemy_name, provinces: [{ number, identifier }], army_ids: [...] }],
		//   auto_plan: bool, selected_province_number }
		godot::Dictionary get_war_overview() const;
		bool move_army(int64_t army_id, int32_t province_number) const;
		// Adds the province to the end of the route of the army (Shift + right click)
		bool queue_army_move(int64_t army_id, int32_t province_number) const;
		bool stop_army(int64_t army_id) const;
		// peace_type: 0 = white peace, 1 = take the states occupied by us, 2 = give the states occupied by the enemy
		bool propose_peace(int32_t war_id, int32_t peace_type) const;
		// enemy_country_index < 0 creates an empty front to draw by hand, otherwise the border with the enemy is generated
		bool create_front(int32_t enemy_country_index) const;
		bool delete_front(int32_t front_id) const;
		// Adds the province to the front line or removes it from the line if it is already there
		bool toggle_front_province(int32_t front_id, int32_t province_number) const;
		// mode: 0 = defend, 1 = attack
		bool set_front_mode(int32_t front_id, int32_t mode) const;
		bool set_front_army(int32_t front_id, int64_t army_id, bool assigned) const;
		bool assign_free_armies(int32_t front_id) const;
		bool set_auto_plan(bool enabled) const;

		// Military
		// Argument true for general, false for admiral
		void create_leader(bool is_general) const;
		void set_can_use_leader(uint64_t leader_id, bool can_use) const;
		void set_auto_create_leaders(bool value) const;
		void set_auto_assign_leaders(bool value) const;
		void set_mobilise(bool value) const;
	};
}

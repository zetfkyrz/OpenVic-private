#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

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

		// Selected province
		void set_selected_province(ProvinceInstance const* new_selected_province);
		void set_selected_province_by_number(int32_t province_number);
		void unset_selected_province();
		int32_t get_selected_province_number() const;

		// Core
		void toggle_paused() const;
		void increase_speed() const;
		void decrease_speed() const;

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

		// Technology

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

		// Military
		// Argument true for general, false for admiral
		void create_leader(bool is_general) const;
		void set_can_use_leader(uint64_t leader_id, bool can_use) const;
		void set_auto_create_leaders(bool value) const;
		void set_auto_assign_leaders(bool value) const;
		void set_mobilise(bool value) const;
	};
}

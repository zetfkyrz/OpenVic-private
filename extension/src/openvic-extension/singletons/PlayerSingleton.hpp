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
		bool set_player_country_by_identifier(godot::String const& identifier);
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
		//   strength, organisation, in_combat, moving, attrition (losing men), army_ids, siege_progress (-1 if none), occupied }
		godot::Array get_map_units() const;

		// Values used by the tariffs: { import_value, effective_rate, administrative_efficiency, tariff_efficiency }
		godot::Dictionary get_tariff_info() const;

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

		// Selected army panel (A1):
		// { id, name, province_number, province_identifier, province_name, regiments, strength, max_strength,
		//   organisation (0..1), dig_in, dig_in_cap, moving, destination_number, destination_name, eta_days, in_combat,
		//   supply (0..1), speed, front_id, leader_id (0 if none), leader: Dictionary of MenuSingleton.make_leader_dict,
		//   units: [{ id, name, type_identifier, type_name, strength, max_strength, organisation, max_organisation,
		//             pop_type, pop_culture }] }
		godot::Dictionary get_army_details(int64_t army_id) const;
		// Generals of the country: [{ leader_id, name, picture, tooltip, personality, background, prestige, army_id, army_name }]
		godot::Array get_generals() const;
		// The same for admirals (leaders of fleets)
		godot::Array get_admirals() const;
		// Armies in the same province as the army that can be merged into it: [{ id, name, regiments }]
		godot::Array get_mergeable_armies(int64_t army_id) const;
		// { auto_create, auto_assign, leadership_points, monthly_leadership_points, leader_cost, can_create }
		godot::Dictionary get_leader_settings() const;
		bool set_leader_auto(bool auto_create, bool auto_assign) const;
		// Makes a new general for leadership points
		bool create_general() const;
		bool split_regiment(int64_t regiment_id) const;
		bool merge_armies(int64_t target_army_id, int64_t source_army_id) const;
		// leader_id = 0 takes the general off the army
		bool set_army_leader(int64_t army_id, int64_t leader_id) const;
		bool disband_regiment(int64_t regiment_id) const;
		bool disband_army(int64_t army_id) const;

		// Colonisation (F2): { total_points, used_points, rank_ok, candidates: [{ province_number, name, cost, reason }],
		//   projects: [{ province_number, name, days_done, days_total, cost }] }
		godot::Dictionary get_colonisation_info() const;
		bool start_colonisation(int32_t province_number) const;
		bool cancel_colonisation(int32_t province_number) const;

		// Events for the player (E1): [{ id, date, kind, subject, text_args... }] with id greater than after_id, oldest first.
		// kind: invention, technology, election, uprising, war_declared, peace_signed; country / other are names
		godot::Array get_notifications(int64_t after_id) const;

		// Rankings (E3): [{ rank, name, country_index, is_player, prestige, industrial, military, total, great_power }]
		godot::Array get_country_ranking() const;
		godot::Dictionary get_lobby_country_info() const;

		// Politics (D3): { government, ruling_party, ruling_ideology, holds_elections, last_election, days_to_election,
		//   voters_share, parties: [{ name, ideology, vote_share, ruling, colour }], ideologies: [{ name, share, colour }],
		//   upper_house: [{ name, share, colour }],
		//   groups: [{ name, type, ordered, options: [{ index, name, current, support, can_enact, reason, upper_house }] }] }
		godot::Dictionary get_politics_info() const;
		bool enact_reform(int32_t reform_index) const;

		// World market (C): [{ name, category, price, price_change, base_price, supply, demand, traded, stockpile,
		//   price_history: PackedFloat32Array (oldest first) }] of the trading goods
		godot::Array get_market_overview() const;

		// Peace negotiations (B). get_peace_info(war_id):
		// { war_id, we_attack, days, our_score, their_score, goal_type, goal_name, attackers: [name], defenders: [name],
		//   concede, reparations, humiliate, reparations_cost, humiliate_cost, states: [{ province_number, name, owner_name,
		//   cost, selected, is_goal }], cost, available, accepts, reason, last_response: { accepted, text, days_ago } | {},
		//   offers: [{ from_name, concede, states: [name], reparations, humiliate, cost, days_left }] }
		godot::Dictionary get_peace_info(int32_t war_id) const;
		// kind: 0 = state (province_number), 1 = reparations, 2 = humiliation, 3 = we give instead of demanding, 4 = clear
		bool set_peace_demand(int32_t war_id, int32_t kind, int32_t province_number, bool enabled) const;
		bool send_peace_offer(int32_t war_id) const;
		bool answer_peace_offer(int32_t war_id, bool accept) const;
		// Offers of the AI waiting for an answer: [{ war_id, from_name, ... }] (same fields as in get_peace_info offers)
		godot::Array get_peace_offers() const;
		// Countries the player can declare war on: [{ index, name }]
		godot::Array get_declarable_countries() const;
		// States of the country that can be a war goal: [{ province_number, name }]
		godot::Array get_war_goal_states(int32_t country_index) const;
		// goal_type: 0 = none, 1 = conquer the state of province_number, 2 = humiliate, 3 = reparations
		bool declare_war_with_goal(int32_t country_index, int32_t goal_type, int32_t province_number) const;

		// Fleets (A8-A10): details of a fleet are returned by get_army_details with is_navy = true:
		// + docked, capacity, carried_regiments, carried: [{ id, name, regiments }], loadable: [{ id, name, regiments }] (armies in
		//   the port), landing_targets: [{ number, name, hostile }], blockading, units: [{ ..., hull, gun_power, is_transport }]
		bool load_army(int64_t army_id, int64_t navy_id) const;
		bool unload_army(int64_t army_id) const;
		bool land_army(int64_t army_id, int32_t province_number) const;
		// Ship types with the reason that one cannot be built in the port of the province (empty if it can):
		// [{ index, identifier, name, days, unlocked, transport, hull, gun_power, min_port_level, reason, cost: [...] }]
		godot::Array get_ship_types(int32_t province_number) const;
		bool start_ship_building(int32_t ship_type_index, int32_t province_number) const;
		// { share, our_blockaded_ports: [{ number, name, owner }], enemy_blockaded_ports: [...] }
		godot::Dictionary get_blockade_info() const;

		// Recruitment (A4/A7):
		// { province_number, province_name, owned, regiment_types: [{ index, identifier, name, days, unlocked,
		//     cost: [{ good_name, amount, have }] }],
		//   pops: [{ id, type_name, culture_name, size, regiments, max_regiments, culture_ok, recruitable }] }
		godot::Dictionary get_recruitment_info(int32_t province_number) const;
		// Empty if the pop can recruit the regiment, otherwise the reason (Russian text for the player)
		godot::String get_recruitment_block_reason(int32_t regiment_type_index, int32_t province_number, int32_t pop_id) const;
		bool start_recruitment(int32_t regiment_type_index, int32_t province_number, int32_t pop_id) const;
		// Recruitment orders of the player: [{ id, type_name, province_number, province_name, days_left, days_total }]
		godot::Array get_recruitment_queue() const;
		bool cancel_recruitment(int64_t order_id) const;

		// Credit and the central bank
		// { cash, central_bank: { internal_rate, external_rate }, total_debt, monthly_interest,
		//   external_taken: [{ id, lender_index, lender_name, principal, remaining, rate, due, interest_paid }],
		//   external_given: [{ id, borrower_index, borrower_name, principal, remaining, rate, due, interest_paid }],
		//   internal_given: [{ id, province_index, province_identifier, principal, remaining, unspent, rate, term, grace_end, due,
		//                      policy }],
		//   offers: [{ lender_index, lender_name, max_amount, rate }],
		//   states: [{ province_index, province_identifier, capitalist_money, capitalists }],
		//   selected_targets: [country_index], alliance_requests: [{ from_index, from_name, date }] }
		godot::Dictionary get_credit_overview() const;
		bool take_external_loan(int32_t lender_index, float amount, int32_t term) const;
		// group: 0 = all countries, 1 = allies, 2 = friends (relations above 100), 3 = the selected countries
		bool give_external_loans(int32_t group, float amount_each, float rate, int32_t term) const;
		bool stage_loan_target(int32_t country_index, bool selected) const;
		// term: 0 = 5 years, 1 = 10 years, 2 = 20 years; policy: 0 = forgive, 1 = soft collection, 2 = hard collection
		bool give_internal_loan(int32_t province_index, float amount, float rate, int32_t term, int32_t policy) const;
		bool repay_loan(int32_t loan_id, float amount) const;
		bool set_loan_auto_repay(int32_t loan_id, bool auto_repay) const;
		bool set_central_bank_rates(float internal_rate, float external_rate) const;
		bool answer_alliance_request(int32_t from_index, bool accept) const;

		// Military
		// Argument true for general, false for admiral
		void create_leader(bool is_general) const;
		void set_can_use_leader(uint64_t leader_id, bool can_use) const;
		void set_auto_create_leaders(bool value) const;
		void set_auto_assign_leaders(bool value) const;
		void set_mobilise(bool value) const;
	};
}

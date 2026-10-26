#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

#include <openvic-simulation/core/object/Date.hpp>

namespace OpenVic {
	struct InstanceManager;

	/* The economy debugger: while it is running it writes the economy of the whole game to CSV files in a folder of the user
	 * directory (user://economy_debug/<date and time>_<country>/), one set of files per recording:
	 *  - every day: world_goods.csv (price, supply, demand, trade, production by kind, consumption, shortage and unsold goods of
	 *    every good in the world), world_summary.csv (population, hunger, unemployment, money of every holder, factories);
	 *  - every month (and at the start): countries.csv, country_goods.csv (production, demand, consumption, stockpile and net
	 *    export of every good in every country), states.csv (regions), state_classes.csv (every class of every region: size,
	 *    cash, income by source, expenses, needs), factories.csv, rgo.csv (resource gathering of the provinces), money_flows.csv
	 *    (the journal of the movement of money by label, it is switched on while recording), investments.csv.
	 * README.txt in the folder describes the columns. Recording does not change the game. */
	class EconomyRecorder {
	public:
		EconomyRecorder();
		~EconomyRecorder();

		// Returns the folder of the recording (a path of the operating system), empty if it could not be started
		godot::String start(InstanceManager& instance_manager, godot::String const& player_tag);
		void stop();
		bool is_running() const {
			return running;
		}
		// Called after every update of the gamestate: writes the tables of the days that came
		void update(InstanceManager& instance_manager);
		// { running, folder, date (of the last record), days, rows, megabytes, tables: { name: rows } }
		godot::Dictionary get_info() const;

	private:
		struct Table {
			std::string name;
			godot::Ref<godot::FileAccess> file;
			std::string buffer;
			std::size_t rows = 0;
			std::size_t bytes = 0;
		};

		bool running = false;
		bool enabled_ledger = false;
		godot::String folder;
		std::vector<Table> tables;
		std::string last_date;
		std::size_t days_recorded = 0;
		// Totals of the money journal at the last monthly record (raw), to write the change per month
		std::vector<std::int64_t> last_flow_totals;
		std::int64_t last_measured_raw = 0;
		std::int64_t last_explained_raw = 0;
		bool has_last_date = false;
		OpenVic::Date last_date_value;
		OpenVic::Date last_investment_date;

		enum table_index_t : std::size_t {
			WORLD_GOODS, WORLD_SUMMARY, COUNTRIES, COUNTRY_GOODS, STATES, STATE_CLASSES, FACTORIES, RGO, MONEY_FLOWS, INVESTMENTS,
			TRADE_FLOWS,
			TABLE_COUNT
		};

		bool open_table(table_index_t index, char const* name, char const* header);
		void flush(Table& table);
		void flush_all();

		void record_daily(InstanceManager& instance_manager, std::string const& date);
		void record_monthly(InstanceManager& instance_manager, std::string const& date);
		void write_readme();
	};
}

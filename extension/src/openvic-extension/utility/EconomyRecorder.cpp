#include "EconomyRecorder.hpp"

#include <algorithm>
#include <iterator>

#include <fmt/format.h>

#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <openvic-simulation/DefinitionManager.hpp>
#include <openvic-simulation/InstanceManager.hpp>
#include <openvic-simulation/country/CountryInstance.hpp>
#include <openvic-simulation/economy/BuildingType.hpp>
#include <openvic-simulation/economy/GoodDefinition.hpp>
#include <openvic-simulation/economy/GoodInstance.hpp>
#include <openvic-simulation/economy/production/FactoryInstance.hpp>
#include <openvic-simulation/economy/production/ProductionType.hpp>
#include <openvic-simulation/economy/production/ResourceGatheringOperation.hpp>
#include <openvic-simulation/economy/trading/MarketInstance.hpp>
#include <openvic-simulation/map/MapInstance.hpp>
#include <openvic-simulation/map/ProvinceInstance.hpp>
#include <openvic-simulation/map/State.hpp>
#include <openvic-simulation/misc/MoneyLedger.hpp>
#include <openvic-simulation/population/Pop.hpp>
#include <openvic-simulation/population/PopManager.hpp>
#include <openvic-simulation/population/PopType.hpp>

using namespace OpenVic;
using namespace godot;

namespace {
	// A number of the simulation as a plain number for the tables (exact: the raw value divided by the scale)
	double num(const fixed_point_t value) {
		return static_cast<double>(value.get_raw_value()) / static_cast<double>(1 << fixed_point_t::PRECISION);
	}

	double pop_num(const pop_size_t value) {
		return static_cast<double>(type_safe::get(value));
	}

	constexpr std::size_t FLUSH_BYTES = 1 << 16;

	char const* const LABEL_NAMES[] = {
#define OV_ECON_LABEL_NAME(name, category) #name,
		OV_MONEY_LABELS(OV_ECON_LABEL_NAME)
#undef OV_ECON_LABEL_NAME
	};
	char const* const LABEL_CATEGORIES[] = {
#define OV_ECON_LABEL_CATEGORY(name, category) category,
		OV_MONEY_LABELS(OV_ECON_LABEL_CATEGORY)
#undef OV_ECON_LABEL_CATEGORY
	};

	// The part of the income of a pop that comes from the budget of the country, for the table of the classes
	struct ClassTotals {
		std::int64_t pops = 0;
		double size = 0, unemployed = 0, cash = 0, income = 0, expenses = 0, life = 0, everyday = 0, luxury = 0;
		double rgo_owner = 0, rgo_worker = 0, factory_worker = 0, factory_owner = 0, unemployment_subsidies = 0, pensions = 0;
		double salary_administration = 0, salary_education = 0, salary_military = 0, events = 0, loan_interest = 0;
		double life_expense = 0, everyday_expense = 0, luxury_expense = 0, artisan_inputs = 0;
	};

	struct GoodTotals {
		double produced = 0, produced_rgo = 0, produced_factory = 0, produced_artisan = 0;
		double consumed_pops = 0, consumed_inputs = 0, pop_demand = 0, factory_demand = 0;
		double army = 0, navy = 0, government = 0, stockpile = 0, stock_change = 0, exported = 0;
	};

	template<typename... Args>
	void add(std::string& buffer, fmt::format_string<Args...> format, Args&&... args) {
		fmt::format_to(std::back_inserter(buffer), format, std::forward<Args>(args)...);
	}
}

EconomyRecorder::EconomyRecorder() {
	tables.resize(TABLE_COUNT);
}

EconomyRecorder::~EconomyRecorder() {
	stop();
}

bool EconomyRecorder::open_table(const table_index_t index, char const* name, char const* header) {
	Table& table = tables[index];
	table.name = name;
	table.rows = 0;
	table.bytes = 0;
	table.buffer.clear();
	table.file = FileAccess::open(folder + String("/") + String(name), FileAccess::WRITE);
	if (table.file.is_null()) {
		UtilityFunctions::push_error("Economy debugger: cannot create ", folder + String("/") + String(name));
		return false;
	}
	table.buffer = header;
	table.buffer += '\n';
	flush(table);
	table.rows = 0;
	return true;
}

void EconomyRecorder::flush(Table& table) {
	if (table.file.is_null() || table.buffer.empty()) {
		return;
	}
	table.file->store_string(String::utf8(table.buffer.data(), static_cast<int64_t>(table.buffer.size())));
	table.bytes += table.buffer.size();
	table.buffer.clear();
}

void EconomyRecorder::flush_all() {
	for (Table& table : tables) {
		flush(table);
		if (table.file.is_valid()) {
			table.file->flush();
		}
	}
}

String EconomyRecorder::start(InstanceManager& instance_manager, String const& player_tag) {
	if (running) {
		return ProjectSettings::get_singleton()->globalize_path(folder);
	}

	String stamp = Time::get_singleton()->get_datetime_string_from_system(false, false).replace(":", "-").replace("T", "_");
	folder = String("user://economy_debug/") + stamp + String("_") + (player_tag.is_empty() ? String("none") : player_tag);
	if (DirAccess::make_dir_recursive_absolute(folder) != OK) {
		UtilityFunctions::push_error("Economy debugger: cannot create the folder ", folder);
		return {};
	}

	bool ok = true;
	ok &= open_table(WORLD_GOODS, "world_goods.csv",
		"date,good,available,price,base_price,price_ratio,price_change,min_next_price,max_next_price,supply,demand,traded,"
		"unsold,unmet,produced,produced_rgo,produced_factory,produced_artisan,consumed_pops,consumed_inputs,pop_demand,"
		"factory_demand,army_needs,navy_needs,government_needs,stockpile_total,stockpile_change,exported_net");
	ok &= open_table(WORLD_SUMMARY, "world_summary.csv",
		"date,population,unemployed,unemployed_pct,hungry_pct,life_needs_avg,everyday_needs_avg,luxury_needs_avg,money_pops,"
		"money_countries,money_investment_funds,money_factory_budgets,money_expansion_funds,money_capitalist_funds,money_total,"
		"factories,factories_open,factories_building,factory_levels,factory_employees,factory_max_employees,factory_revenue,"
		"factory_profit,trade_value,unsold_value,unmet_value,countries_in_deficit,countries");
	ok &= open_table(COUNTRIES, "countries.csv",
		"date,tag,is_ai,rank,provinces,states,population,unemployed,cash,investment_fund,investment_spent_total,"
		"construction_slider,income_yesterday,balance_yesterday,balance_avg_before_investment,tax_income,tariff_income,"
		"gold_income,spend_administration,spend_education,spend_military,spend_pensions,spend_unemployment,import_subsidies,"
		"stockpile_spending,stockpile_income,subsidy_mode,factories,factories_open,factories_building,factory_levels,"
		"factory_revenue,factory_profit,industrial_power");
	ok &= open_table(COUNTRY_GOODS, "country_goods.csv",
		"date,tag,good,produced,produced_rgo,produced_factory,produced_artisan,pop_demand,factory_demand,army_needs,navy_needs,"
		"government_needs,consumed_pops,consumed_inputs,stockpile,stockpile_change,exported_net,stockpile_trade_money");
	ok &= open_table(STATES, "states.csv",
		"date,state,region,capital_province,owner,colonial,population,unemployed,pops_cash,capitalist_fund,factories,factories_open,"
		"factory_levels,factory_employees,factory_revenue,factory_profit,rgo_provinces,rgo_output,rgo_unsold,rgo_revenue,"
		"rgo_employees,life_needs,everyday_needs,luxury_needs");
	ok &= open_table(STATE_CLASSES, "state_classes.csv",
		"date,state,owner,class,pops,size,unemployed,cash,income,expenses,life_needs,everyday_needs,luxury_needs,rgo_owner_income,"
		"rgo_worker_income,factory_worker_income,factory_owner_income,unemployment_subsidies,pensions,salary_administration,"
		"salary_education,salary_military,event_income,loan_interest,life_expense,everyday_expense,luxury_expense,artisan_inputs");
	ok &= open_table(FACTORIES, "factories.csv",
		"date,state,owner,type,level,open,constructing,construction_progress,state_share,owner_class,subsidised,budget,"
		"expansion_fund,efficiency,throttle,employees,max_employees,output_yesterday,sold_yesterday,revenue,input_cost,wages,"
		"profit,average_profit,value,subsidy_yesterday,private_cover_yesterday,inputs_lacking,output_good,output_price");
	ok &= open_table(RGO, "rgo.csv",
		"date,province,state,owner,good,production_type,size_multiplier,employees,max_employees,output,unsold,revenue,price");
	ok &= open_table(MONEY_FLOWS, "money_flows.csv", "date,label,category,change_in_period,total_since_start");
	ok &= open_table(INVESTMENTS, "investments.csv", "date,tag,kind,building,state,builder_class,cost,for_deficit");
	if (!ok) {
		stop();
		return {};
	}

	// The journal of the movement of money is only a record of the payments, it changes nothing in the game
	MoneyLedger& ledger = instance_manager.get_money_ledger();
	if (!ledger.is_enabled()) {
		ledger.enable(instance_manager);
		enabled_ledger = true;
	}
	last_flow_totals.assign(MoneyLedger::LABEL_COUNT, 0);
	last_measured_raw = ledger.get_measured_change_raw(instance_manager);
	last_explained_raw = ledger.get_holder_sum_raw();
	last_investment_date = instance_manager.get_today();

	write_readme();
	running = true;
	has_last_date = false;
	days_recorded = 0;
	last_date.clear();
	update(instance_manager);
	return ProjectSettings::get_singleton()->globalize_path(folder);
}

void EconomyRecorder::stop() {
	if (!running && !enabled_ledger && tables[WORLD_GOODS].file.is_null()) {
		return;
	}
	flush_all();
	for (Table& table : tables) {
		table.file.unref();
	}
	if (enabled_ledger) {
		// The journal is only switched off by the recorder that switched it on
		MoneyLedger::active = nullptr;
		enabled_ledger = false;
	}
	running = false;
}

void EconomyRecorder::update(InstanceManager& instance_manager) {
	if (!running) {
		return;
	}
	const Date today = instance_manager.get_today();
	if (has_last_date && today == last_date_value) {
		return;
	}
	const bool first = !has_last_date;
	has_last_date = true;
	last_date_value = today;
	last_date = fmt::format("{}", today);

	record_daily(instance_manager, last_date);
	if (first || today.is_month_start()) {
		record_monthly(instance_manager, last_date);
	}
	days_recorded++;
	flush_all();
}

Dictionary EconomyRecorder::get_info() const {
	Dictionary info;
	info["running"] = running;
	info["folder"] = running ? ProjectSettings::get_singleton()->globalize_path(folder) : String();
	info["date"] = String(last_date.c_str());
	info["days"] = static_cast<int64_t>(days_recorded);
	std::size_t rows = 0, bytes = 0;
	Dictionary table_rows;
	for (Table const& table : tables) {
		rows += table.rows;
		bytes += table.bytes + table.buffer.size();
		if (!table.name.empty()) {
			table_rows[String(table.name.c_str())] = static_cast<int64_t>(table.rows);
		}
	}
	info["rows"] = static_cast<int64_t>(rows);
	info["megabytes"] = static_cast<double>(bytes) / (1024.0 * 1024.0);
	info["tables"] = table_rows;
	return info;
}

void EconomyRecorder::write_readme() {
	Ref<FileAccess> file = FileAccess::open(folder + String("/README.txt"), FileAccess::WRITE);
	if (file.is_null()) {
		return;
	}
	file->store_string(String::utf8(
		"Economy debugger of OpenVic (keys X + Ъ, i.e. the keys [ and ] together). Every number is per day unless said otherwise,\n"
		"money in pounds, quantities in units of goods. The files are CSV with a header, the decimal point is a dot.\n"
		"\n"
		"world_goods.csv      every day, one row per good: price and its limits, supply / demand / traded (of yesterday's market),\n"
		"                     unsold = supply - traded (goods that were made and thrown away), unmet = demand - traded (what was wanted\n"
		"                     and not bought), produced (by kind: rgo, factory, artisan), consumed_pops, consumed_inputs (inputs of\n"
		"                     factories and artisans), the demand of pops / factories / army / navy / government, the stockpiles of the\n"
		"                     countries, exported_net (the sum of the net exports of the countries, positive: exported).\n"
		"world_summary.csv    every day: population, unemployed, hungry_pct (pops with less than half of the life needs), the money of every\n"
		"                     holder (pops, countries, investment funds, factory budgets, expansion funds, capitalist funds), factories,\n"
		"                     the value of the trade, of the unsold and of the unmet goods at the prices, countries in deficit.\n"
		"countries.csv        every month: the budget, the spending, the investment fund, the factories of every country.\n"
		"country_goods.csv    every month: production, demand, consumption, stockpile, net export of every good in every country.\n"
		"states.csv           every month: every region (state): population, factories, resource gathering, needs.\n"
		"state_classes.csv    every month: every class (pop type) in every region: size, cash, income by source, expenses, needs.\n"
		"factories.csv        every month: every factory with its finances.\n"
		"rgo.csv              every month: every province that gathers resources.\n"
		"money_flows.csv      every month: the journal of the movement of money by label (change in the period and total since the\n"
		"                     start); the last rows (__measured_change, __explained_by_hooks) must be equal: otherwise money appears or\n"
		"                     disappears without a payment.\n"
		"investments.csv      the projects paid from the investment funds.\n"
	));
	file->flush();
}

void EconomyRecorder::record_daily(InstanceManager& instance_manager, std::string const& date) {
	MarketInstance const& market = instance_manager.get_market_instance();
	const std::size_t good_count = instance_manager.get_good_instance_manager().get_good_instances().size();
	std::vector<GoodTotals> totals(good_count);

	std::int32_t countries_in_deficit = 0, countries = 0;
	double investment_funds = 0;
	for (CountryInstance& country : instance_manager.get_country_instance_manager().get_country_instances()) {
		investment_funds += num(country.get_investment_fund());
		if (country.exists() && !country.get_owned_provinces().empty()) {
			countries++;
			if (!country.get_balance_history().empty() && country.get_balance_history().back() < fixed_point_t::_0) {
				countries_in_deficit++;
			}
		}
		for (auto const& [good_instance, good_data] : country.get_goods_data()) {
			GoodTotals& t = totals[static_cast<std::size_t>(type_safe::get(good_instance.index))];
			for (auto const& [production_type, quantity] : good_data.production_per_production_type) {
				const double q = num(quantity);
				t.produced += q;
				switch (production_type->template_type) {
					using enum ProductionType::template_type_t;
				case RGO: t.produced_rgo += q; break;
				case FACTORY: t.produced_factory += q; break;
				case ARTISAN: t.produced_artisan += q; break;
				}
			}
			for (auto const& [pop_type, quantity] : good_data.need_consumption_per_pop_type) {
				t.consumed_pops += num(quantity);
			}
			for (auto const& [production_type, quantity] : good_data.input_consumption_per_production_type) {
				t.consumed_inputs += num(quantity);
			}
			t.pop_demand += num(good_data.pop_demand);
			t.factory_demand += num(good_data.factory_demand);
			t.army += num(good_data.army_needs);
			t.navy += num(good_data.navy_needs);
			t.government += num(good_data.government_needs);
			t.stockpile += num(good_data.stockpile_amount);
			t.stock_change += num(good_data.stockpile_change_yesterday);
			t.exported += num(good_data.exported_amount);
		}
	}

	Table& goods_table = tables[WORLD_GOODS];
	double trade_value = 0, unsold_value = 0, unmet_value = 0;
	for (GoodInstance const& good : instance_manager.get_good_instance_manager().get_good_instances()) {
		GoodTotals const& t = totals[static_cast<std::size_t>(type_safe::get(good.index))];
		const double price = num(good.get_price());
		const double base = num(good.good_definition.base_price);
		const double supply = num(good.get_total_supply_yesterday());
		const double demand = num(good.get_total_demand_yesterday());
		const double traded = num(good.get_quantity_traded_yesterday());
		const double unsold = std::max(0.0, supply - traded);
		const double unmet = std::max(0.0, demand - traded);
		if (!good.good_definition.is_money) {
			trade_value += traded * price;
			unsold_value += unsold * price;
			unmet_value += unmet * price;
		}
		add(goods_table.buffer,
			"{},{},{},{:.4f},{:.4f},{:.4f},{:.4f},{:.4f},{:.4f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},"
			"{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f}\n",
			date, good.get_identifier(), market.get_is_available(good.index) ? 1 : 0, price, base, base > 0 ? price / base : 0.0,
			num(good.get_price_change_yesterday()), num(good.get_min_next_price()), num(good.get_max_next_price()), supply, demand,
			traded, unsold, unmet, t.produced, t.produced_rgo, t.produced_factory, t.produced_artisan, t.consumed_pops,
			t.consumed_inputs, t.pop_demand, t.factory_demand, t.army, t.navy, t.government, t.stockpile, t.stock_change, t.exported
		);
		goods_table.rows++;
		if (goods_table.buffer.size() > FLUSH_BYTES) {
			flush(goods_table);
		}
	}

	// Pops: population, hunger, unemployment, cash
	double population = 0, unemployed = 0, hungry = 0, life = 0, everyday = 0, luxury = 0;
	for (ProvinceInstance& province : instance_manager.get_map_instance().get_province_instances()) {
		for (Pop const& pop : province.get_pops()) {
			const double size = pop_num(pop.get_size());
			population += size;
			unemployed += pop_num(pop.get_unemployed());
			const double life_fulfilled = num(pop.get_life_needs_fulfilled());
			life += life_fulfilled * size;
			everyday += num(pop.get_everyday_needs_fulfilled()) * size;
			luxury += num(pop.get_luxury_needs_fulfilled()) * size;
			if (life_fulfilled < 0.5) {
				hungry += size;
			}
		}
	}

	const MoneyLedger::Totals money = MoneyLedger::measure(instance_manager);
	std::int32_t factories = 0, open = 0, building = 0;
	double levels = 0, employees = 0, max_employees = 0, factory_revenue = 0, factory_profit = 0;
	for (StateSet const& state_set : instance_manager.get_map_instance().get_state_manager().get_state_sets()) {
		for (State const& state : state_set.get_states()) {
			for (FactoryInstance const& factory : state.get_factories()) {
				factories++;
				open += factory.is_open() && factory.get_level() > building_level_t(0) ? 1 : 0;
				building += factory.is_under_construction() ? 1 : 0;
				levels += static_cast<double>(type_safe::get(factory.get_level()));
				employees += pop_num(factory.get_employee_count());
				max_employees += pop_num(factory.get_max_employee_count());
				factory_revenue += num(factory.get_revenue_yesterday());
				factory_profit += num(factory.get_profit_yesterday());
			}
		}
	}

	add(tables[WORLD_SUMMARY].buffer,
		"{},{:.0f},{:.0f},{:.3f},{:.3f},{:.4f},{:.4f},{:.4f},{:.2f},{:.2f},{:.2f},{:.2f},{:.2f},{:.2f},{:.2f},{},{},{},{:.0f},{:.0f},"
		"{:.0f},{:.2f},{:.2f},{:.2f},{:.2f},{:.2f},{},{}\n",
		date, population, unemployed, population > 0 ? 100.0 * unemployed / population : 0.0,
		population > 0 ? 100.0 * hungry / population : 0.0, population > 0 ? life / population : 0.0,
		population > 0 ? everyday / population : 0.0, population > 0 ? luxury / population : 0.0, num(money.pops),
		num(money.countries) - investment_funds, investment_funds, num(money.factory_budgets), num(money.expansion_funds),
		num(money.capitalist_funds), num(money.total()), factories, open, building, levels, employees, max_employees,
		factory_revenue, factory_profit, trade_value, unsold_value, unmet_value, countries_in_deficit, countries
	);
	tables[WORLD_SUMMARY].rows++;
}

void EconomyRecorder::record_monthly(InstanceManager& instance_manager, std::string const& date) {
	MapInstance& map = instance_manager.get_map_instance();
	MarketInstance const& market = instance_manager.get_market_instance();
	const Date today = instance_manager.get_today();
	TypedSpan<pop_type_index_t, const PopType> pop_types = instance_manager.definition_manager.get_pop_manager().get_pop_types();
	const std::size_t pop_type_count = static_cast<std::size_t>(type_safe::get(pop_types.size()));

	// ---- countries and their goods
	Table& countries_table = tables[COUNTRIES];
	Table& country_goods_table = tables[COUNTRY_GOODS];
	Table& investments_table = tables[INVESTMENTS];
	for (CountryInstance& country : instance_manager.get_country_instance_manager().get_country_instances()) {
		if (!country.exists() || country.get_owned_provinces().empty()) {
			continue;
		}
		std::int32_t factories = 0, open = 0, building = 0;
		double levels = 0, revenue = 0, profit = 0;
		for (State const* state : country.get_states()) {
			for (FactoryInstance const& factory : state->get_factories()) {
				factories++;
				open += factory.is_open() && factory.get_level() > building_level_t(0) ? 1 : 0;
				building += factory.is_under_construction() ? 1 : 0;
				levels += static_cast<double>(type_safe::get(factory.get_level()));
				revenue += num(factory.get_revenue_yesterday());
				profit += num(factory.get_profit_yesterday());
			}
		}
		const bool has_balance = !country.get_balance_history().empty();
		double unemployed_total = 0;
		for (auto const& unemployed_of_type : country.get_unemployed_pops_by_type()) {
			unemployed_total += static_cast<double>(type_safe::get(unemployed_of_type));
		}
		// The income of the budget that is not the tariffs, the gold and the sales of the national stockpile is the taxes
		const fixed_point_t tax_income = country.get_income_yesterday() - country.get_tariff_income() -
			country.get_gold_income_untracked() - country.get_actual_national_stockpile_income().load();
		add(countries_table.buffer,
			"{},{},{},{},{},{},{:.0f},{:.0f},{:.2f},{:.2f},{:.2f},{:.3f},{:.2f},{:.2f},{:.2f},{:.2f},{:.2f},{:.2f},{:.2f},{:.2f},{:.2f},"
			"{:.2f},{:.2f},{:.2f},{:.2f},{:.2f},{},{},{},{},{:.0f},{:.2f},{:.2f},{:.2f}\n",
			date, country.get_identifier(), country.is_ai() ? 1 : 0, country.get_total_rank(), country.get_owned_provinces().size(),
			country.get_states().size(), static_cast<double>(type_safe::get(country.get_total_population())), unemployed_total,
			num(country.get_cash_stockpile().load()), num(country.get_investment_fund()),
			num(country.get_investment_spent_total()), num(country.get_construction_spending_slider_value().get_value_untracked()),
			num(country.get_income_yesterday()), has_balance ? num(country.get_balance_history().back()) : 0.0,
			num(country.get_balance_before_investment_average()), num(tax_income),
			num(country.get_tariff_income()), num(country.get_gold_income_untracked()),
			num(country.get_actual_administration_spending().load()), num(country.get_actual_education_spending().load()),
			num(country.get_actual_military_spending().load()), num(country.get_actual_pensions_spending().load()),
			num(country.get_actual_unemployment_subsidies_spending().load()), num(country.get_import_subsidies_spending()),
			num(country.get_actual_national_stockpile_spending().load()), num(country.get_actual_national_stockpile_income().load()),
			static_cast<int>(country.get_subsidy_mode()), factories, open, building, levels, revenue, profit,
			num(country.get_industrial_power_untracked())
		);
		countries_table.rows++;

		for (auto const& [good_instance, good_data] : country.get_goods_data()) {
			GoodTotals t;
			for (auto const& [production_type, quantity] : good_data.production_per_production_type) {
				const double q = num(quantity);
				t.produced += q;
				switch (production_type->template_type) {
					using enum ProductionType::template_type_t;
				case RGO: t.produced_rgo += q; break;
				case FACTORY: t.produced_factory += q; break;
				case ARTISAN: t.produced_artisan += q; break;
				}
			}
			for (auto const& [pop_type, quantity] : good_data.need_consumption_per_pop_type) {
				t.consumed_pops += num(quantity);
			}
			for (auto const& [production_type, quantity] : good_data.input_consumption_per_production_type) {
				t.consumed_inputs += num(quantity);
			}
			const double demand = num(good_data.pop_demand) + num(good_data.factory_demand) + num(good_data.army_needs) +
				num(good_data.navy_needs) + num(good_data.government_needs);
			const double stockpile = num(good_data.stockpile_amount);
			if (t.produced == 0 && demand == 0 && stockpile == 0 && t.consumed_pops == 0 && t.consumed_inputs == 0) {
				continue;
			}
			add(country_goods_table.buffer, "{},{},{},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f},{:.3f}\n",
				date, country.get_identifier(), good_instance.get_identifier(), t.produced, t.produced_rgo, t.produced_factory,
				t.produced_artisan, num(good_data.pop_demand), num(good_data.factory_demand), num(good_data.army_needs),
				num(good_data.navy_needs), num(good_data.government_needs), t.consumed_pops, t.consumed_inputs, stockpile,
				num(good_data.stockpile_change_yesterday), num(good_data.exported_amount), num(good_data.money_traded_yesterday)
			);
			country_goods_table.rows++;
		}
		if (country_goods_table.buffer.size() > FLUSH_BYTES) {
			flush(country_goods_table);
		}

		// The projects of the investment fund since the last record
		for (auto const& record : country.get_recent_investments()) {
			if (record.date <= last_investment_date) {
				continue;
			}
			static char const* const KINDS[] = { "new_factory", "expanded_factory", "railroad" };
			add(investments_table.buffer, "{},{},{},{},{},{},{:.2f},{}\n", fmt::format("{}", record.date), country.get_identifier(),
				KINDS[static_cast<std::size_t>(record.kind)],
				record.building_type != nullptr ? record.building_type->get_identifier() : std::string_view {},
				record.state != nullptr ? std::string(std::string_view { record.state->get_identifier() }) : std::string {},
				record.builder != nullptr ? record.builder->get_identifier() : std::string_view {}, num(record.cost),
				record.deficit ? 1 : 0
			);
			investments_table.rows++;
		}
	}
	last_investment_date = today;
	flush(countries_table);
	flush(country_goods_table);
	flush(investments_table);

	// ---- regions, classes, factories
	Table& states_table = tables[STATES];
	Table& classes_table = tables[STATE_CLASSES];
	Table& factories_table = tables[FACTORIES];
	std::vector<ClassTotals> classes(pop_type_count);
	for (StateSet const& state_set : map.get_state_manager().get_state_sets()) {
		for (State const& state : state_set.get_states()) {
			CountryInstance const* const owner = state.get_owner();
			const std::string state_name = std::string(std::string_view { state.get_identifier() });
			const std::string_view owner_tag = owner != nullptr ? owner->get_identifier() : std::string_view { "none" };

			std::fill(classes.begin(), classes.end(), ClassTotals {});
			double population = 0, unemployed = 0, cash = 0, life = 0, everyday = 0, luxury = 0;
			double rgo_output = 0, rgo_unsold = 0, rgo_revenue = 0, rgo_employees = 0;
			std::int32_t rgo_provinces = 0;
			for (ProvinceInstance const& province : state.get_provinces()) {
				for (Pop const& pop : province.get_pops()) {
					ClassTotals& c = classes[static_cast<std::size_t>(type_safe::get(pop.get_type().index))];
					const double size = pop_num(pop.get_size());
					const double pop_cash = num(pop.get_cash().get_copy_of_value());
					c.pops++;
					c.size += size;
					c.unemployed += pop_num(pop.get_unemployed());
					c.cash += pop_cash;
					c.income += num(pop.get_income());
					c.expenses += num(pop.get_expenses().get_copy_of_value());
					c.life += num(pop.get_life_needs_fulfilled()) * size;
					c.everyday += num(pop.get_everyday_needs_fulfilled()) * size;
					c.luxury += num(pop.get_luxury_needs_fulfilled()) * size;
					c.rgo_owner += num(pop.get_rgo_owner_income());
					c.rgo_worker += num(pop.get_rgo_worker_income());
					c.factory_worker += num(pop.get_factory_worker_income());
					c.factory_owner += num(pop.get_factory_owner_income());
					c.unemployment_subsidies += num(pop.get_unemployment_subsidies());
					c.pensions += num(pop.get_pensions());
					c.salary_administration += num(pop.get_government_salary_administration());
					c.salary_education += num(pop.get_government_salary_education());
					c.salary_military += num(pop.get_government_salary_military());
					c.events += num(pop.get_event_and_decision_income());
					c.loan_interest += num(pop.get_loan_interest_payments());
					c.life_expense += num(pop.get_life_needs_expense());
					c.everyday_expense += num(pop.get_everyday_needs_expense());
					c.luxury_expense += num(pop.get_luxury_needs_expense());
					c.artisan_inputs += num(pop.get_artisan_inputs_expense());
					population += size;
					unemployed += pop_num(pop.get_unemployed());
					cash += pop_cash;
					life += num(pop.get_life_needs_fulfilled()) * size;
					everyday += num(pop.get_everyday_needs_fulfilled()) * size;
					luxury += num(pop.get_luxury_needs_fulfilled()) * size;
				}
				ResourceGatheringOperation const& rgo = province.get_rgo();
				if (rgo.is_valid()) {
					rgo_provinces++;
					rgo_output += num(rgo.get_output_quantity_yesterday());
					rgo_unsold += num(rgo.get_unsold_quantity_yesterday());
					rgo_revenue += num(rgo.get_revenue_yesterday());
					rgo_employees += pop_num(rgo.get_total_employees_count_cache());

					ProductionType const& production_type = *rgo.get_production_type_nullable();
					add(tables[RGO].buffer, "{},{},{},{},{},{},{:.4f},{:.0f},{:.0f},{:.3f},{:.3f},{:.3f},{:.4f}\n", date, province.get_identifier(),
						state_name, owner_tag, production_type.output_good.get_identifier(), production_type.get_identifier(),
						num(rgo.get_size_multiplier()), pop_num(rgo.get_total_employees_count_cache()),
						pop_num(rgo.get_max_employee_count_cache()), num(rgo.get_output_quantity_yesterday()),
						num(rgo.get_unsold_quantity_yesterday()), num(rgo.get_revenue_yesterday()),
						num(market.get_good_instance(production_type.output_good.index).get_price())
					);
					tables[RGO].rows++;
				}
			}

			for (std::size_t i = 0; i < pop_type_count; i++) {
				ClassTotals const& c = classes[i];
				if (c.pops == 0) {
					continue;
				}
				PopType const& pop_type = pop_types[pop_type_index_t(static_cast<std::uint32_t>(i))];
				const double size = std::max(c.size, 1.0);
				add(classes_table.buffer,
					"{},{},{},{},{},{:.0f},{:.0f},{:.2f},{:.2f},{:.2f},{:.4f},{:.4f},{:.4f},{:.2f},{:.2f},{:.2f},{:.2f},{:.2f},{:.2f},"
					"{:.2f},{:.2f},{:.2f},{:.2f},{:.2f},{:.2f},{:.2f},{:.2f},{:.2f}\n",
					date, state_name, owner_tag, pop_type.get_identifier(), c.pops, c.size, c.unemployed, c.cash, c.income, c.expenses,
					c.life / size, c.everyday / size, c.luxury / size, c.rgo_owner, c.rgo_worker, c.factory_worker, c.factory_owner,
					c.unemployment_subsidies, c.pensions, c.salary_administration, c.salary_education, c.salary_military, c.events,
					c.loan_interest, c.life_expense, c.everyday_expense, c.luxury_expense, c.artisan_inputs
				);
				classes_table.rows++;
			}

			std::int32_t factories = 0, open = 0;
			double levels = 0, employees = 0, factory_revenue = 0, factory_profit = 0;
			for (FactoryInstance const& factory : state.get_factories()) {
				factories++;
				open += factory.is_open() && factory.get_level() > building_level_t(0) ? 1 : 0;
				levels += static_cast<double>(type_safe::get(factory.get_level()));
				employees += pop_num(factory.get_employee_count());
				factory_revenue += num(factory.get_revenue_yesterday());
				factory_profit += num(factory.get_profit_yesterday());

				std::int32_t lacking = 0;
				for (FactoryInstance::Input const& input : factory.get_inputs()) {
					if (input.stockpile < input.quantity_per_level * std::max<std::int32_t>(1, static_cast<std::int32_t>(type_safe::get(factory.get_level())))) {
						lacking++;
					}
				}
				std::string_view owner_class;
				if (const std::optional<pop_type_index_t> owner_type = factory.get_effective_owner_pop_type_index(); owner_type.has_value()) {
					owner_class = pop_types[*owner_type].get_identifier();
				}
				GoodDefinition const& output_good = factory.production_type.output_good;
				add(factories_table.buffer,
					"{},{},{},{},{},{},{},{:.3f},{:.4f},{},{},{:.2f},{:.2f},{:.4f},{:.4f},{:.0f},{:.0f},{:.3f},{:.3f},{:.2f},{:.2f},{:.2f},"
					"{:.2f},{:.3f},{:.2f},{:.2f},{:.2f},{},{},{:.4f}\n",
					date, state_name, owner_tag, factory.building_type.get_identifier(), type_safe::get(factory.get_level()),
					factory.is_open() ? 1 : 0, factory.is_under_construction() ? 1 : 0, num(factory.get_construction_progress(today)),
					num(factory.get_state_share()), owner_class, factory.is_subsidised() ? 1 : 0, num(factory.get_budget()),
					num(factory.get_expansion_fund()), num(factory.get_efficiency()), num(factory.get_throttle()),
					pop_num(factory.get_employee_count()), pop_num(factory.get_max_employee_count()),
					num(factory.get_output_quantity_yesterday()), num(factory.get_sold_quantity_yesterday()),
					num(factory.get_revenue_yesterday()), num(factory.get_input_cost_yesterday()), num(factory.get_wages_yesterday()),
					num(factory.get_profit_yesterday()), num(factory.get_average_profit()), num(factory.calculate_value(market)),
					num(factory.get_subsidy_yesterday()), num(factory.get_private_cover_yesterday()), lacking, output_good.get_identifier(),
					num(market.get_good_instance(output_good.index).get_price())
				);
				factories_table.rows++;
			}

			std::int32_t colonial = state.is_colonial_state() ? 1 : 0;
			add(states_table.buffer, "{},{},{},{},{},{},{:.0f},{:.0f},{:.2f},{:.2f},{},{},{:.0f},{:.0f},{:.2f},{:.2f},{},{:.3f},{:.3f},{:.2f},{:.0f},{:.4f},{:.4f},{:.4f}\n",
				date, state_name, state_set.region.get_identifier(), state.get_capital() != nullptr ? state.get_capital()->get_identifier() : std::string_view { "none" },
				owner_tag, colonial, population, unemployed, cash, num(state.get_capitalist_fund()), factories, open, levels,
				employees, factory_revenue, factory_profit, rgo_provinces, rgo_output, rgo_unsold, rgo_revenue, rgo_employees,
				population > 0 ? life / population : 0.0, population > 0 ? everyday / population : 0.0,
				population > 0 ? luxury / population : 0.0
			);
			states_table.rows++;
		}
		for (Table* table : { &states_table, &classes_table, &factories_table, &tables[RGO] }) {
			if (table->buffer.size() > FLUSH_BYTES) {
				flush(*table);
			}
		}
	}
	flush(states_table);
	flush(classes_table);
	flush(factories_table);
	flush(tables[RGO]);

	// ---- the journal of the money: the change of every label since the last record
	MoneyLedger& ledger = instance_manager.get_money_ledger();
	if (ledger.is_enabled()) {
		Table& flows = tables[MONEY_FLOWS];
		for (std::size_t i = 0; i < MoneyLedger::LABEL_COUNT; i++) {
			const std::int64_t total = ledger.get_flow_total_raw(static_cast<MoneyLedger::label_t>(i));
			if (total == 0 && last_flow_totals[i] == 0) {
				continue;
			}
			add(flows.buffer, "{},{},{},{:.2f},{:.2f}\n", date, LABEL_NAMES[i], LABEL_CATEGORIES[i],
				static_cast<double>(total - last_flow_totals[i]) / static_cast<double>(1 << fixed_point_t::PRECISION),
				static_cast<double>(total) / static_cast<double>(1 << fixed_point_t::PRECISION)
			);
			flows.rows++;
			last_flow_totals[i] = total;
		}
		const std::int64_t measured = ledger.get_measured_change_raw(instance_manager);
		const std::int64_t explained = ledger.get_holder_sum_raw();
		const double scale = static_cast<double>(1 << fixed_point_t::PRECISION);
		add(flows.buffer, "{},__measured_change,check,{:.2f},{:.2f}\n", date, static_cast<double>(measured - last_measured_raw) / scale,
			static_cast<double>(measured) / scale);
		add(flows.buffer, "{},__explained_by_hooks,check,{:.2f},{:.2f}\n", date, static_cast<double>(explained - last_explained_raw) / scale,
			static_cast<double>(explained) / scale);
		flows.rows += 2;
		last_measured_raw = measured;
		last_explained_raw = explained;
		flush(flows);
	}
}

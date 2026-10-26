#include "BudgetMenu.hpp"

#include <cstddef>

#include <godot_cpp/core/error_macros.hpp>

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include <openvic-simulation/country/CountryInstance.hpp>
#include <openvic-simulation/population/PopType.hpp>

#include "openvic-extension/classes/GUILabel.hpp"
#include "openvic-extension/classes/GUINode.hpp"
#include "openvic-extension/classes/GUIPieChart.hpp"
#include "openvic-extension/core/Convert.hpp"
#include "openvic-extension/singletons/GameSingleton.hpp"
#include "openvic-extension/singletons/PlayerSingleton.hpp"
#include "openvic-extension/utility/Utilities.hpp"

using namespace OpenVic;

BudgetMenu::BudgetMenu(
    GUINode const& parent,
    forwardable_span<const Strata> strata_keys,
    ModifierEffectCache const& modifier_effect_cache,
    CountryDefines const& country_defines
) :
    cash_stockpile_label { *parent.get_gui_label_from_nodepath("./country_budget/total_funds_val") },
    gold_income_label { *parent.get_gui_label_from_nodepath("./country_budget/gold_inc") },
    projected_balance_label { *parent.get_gui_label_from_nodepath("./country_budget/balance") },
    projected_expenses_label { *parent.get_gui_label_from_nodepath("./country_budget/total_exp") },
    projected_income_label { *parent.get_gui_label_from_nodepath("./country_budget/total_inc") },
    administration_budget { parent, country_defines }, diplomatic_budget { parent }, education_budget { parent },
    military_budget { parent }, national_stockpile_budget { parent }, social_budget { parent },
    tariff_budget { parent, country_defines },
    projected_income_template { generate_projected_income_template(strata_keys.size()) } {
	tax_budgets.reserve(strata_keys.size());
	connections.reserve(7 + strata_keys.size());
	connections.push_back(
	    administration_budget.balance_changed.connect(&BudgetMenu::update_projected_expenses_and_balance, this)
	);
	connections.push_back(diplomatic_budget.balance_changed.connect(&BudgetMenu::update_all_projections, this));
	connections.push_back(education_budget.balance_changed.connect(&BudgetMenu::update_projected_expenses_and_balance, this));
	connections.push_back(military_budget.balance_changed.connect(&BudgetMenu::update_projected_expenses_and_balance, this));
	connections.push_back(
	    national_stockpile_budget.balance_changed.connect(&BudgetMenu::update_projected_expenses_and_balance, this)
	);
	connections.push_back(social_budget.balance_changed.connect(&BudgetMenu::update_projected_expenses_and_balance, this));
	connections.push_back(tariff_budget.balance_changed.connect(&BudgetMenu::update_all_projections, this));
	for (Strata const& strata : strata_keys) {
		StrataTaxBudget& strata_tax_budget = tax_budgets.emplace_back(parent, strata, modifier_effect_cache);
		connections.push_back(
		    strata_tax_budget.balance_changed.connect(&BudgetMenu::update_projected_income_and_balance, this)
		);
	}

	GUILabel::set_text_and_tooltip(parent, "./country_budget/gold_desc", "GOLD", "precious_metal_desc");
	GUILabel::set_text_and_tooltip(parent, "./country_budget/ind_sub_desc", "BUDGET_INDUSTRIAL_SUBSIDIES", "IND_SUP_DESC");

	strata_charts.resize(strata_keys.size(), nullptr);
	for (Strata const& strata : strata_keys) {
		strata_charts[static_cast<size_t>(type_safe::get(strata.index))] = parent.get_gui_pie_chart_from_nodepath(
		    Utilities::format("./country_budget/chart_%d", static_cast<uint64_t>(type_safe::get(strata.index)))
		);
	}

	projected_income_args.resize(5 + strata_keys.size());
	projected_expenses_args.resize(8);
}

BudgetMenu::extras_t BudgetMenu::get_extras(CountryInstance const& country) const {
	extras_t extras;
	extras.stockpile_sales = country.get_actual_national_stockpile_income().load();
	extras.freight = country.get_transport_to_treasury();
	extras.other_income = country.get_treasury_other_income();
	extras.subsidies = country.get_treasury_subsidy_spending();
	extras.other_spending = country.get_treasury_other_spending();
	// What the government really paid for the goods of its stockpile yesterday replaces the need of the army and the navy that the
	// sliders count (the need is what the units would use, the treasury pays only what it can): the difference is added here
	extras.extra_purchases =
		country.get_actual_national_stockpile_spending().load() - national_stockpile_budget.get_military_supply_expenses();
	return extras;
}

void BudgetMenu::update_projected_balance() {
	CountryInstance const* const country_ptr = PlayerSingleton::get_singleton()->get_player_country();
	ERR_FAIL_NULL(country_ptr);
	CountryInstance const& country = *country_ptr;
	fixed_point_t projected_balance =
		country.get_gold_income_untracked() + administration_budget.get_balance() + diplomatic_budget.get_balance() +
		education_budget.get_balance() + military_budget.get_balance() + national_stockpile_budget.get_balance() +
		social_budget.get_balance() + tariff_budget.get_balance();

	fixed_point_t taxes = 0;
	for (StrataTaxBudget const& strata_tax_budget : tax_budgets) {
		projected_balance += strata_tax_budget.get_balance();
		taxes += strata_tax_budget.get_income();
	}

	// Everything else that fills the treasury or empties it (the figures of the last day)
	const extras_t extras = get_extras(country);
	projected_balance += extras.income() - extras.spending();

	// The tooltip: every source of money of the treasury and every use of it
	const auto line = [](char const* name, const fixed_point_t amount, const bool income) -> godot::String {
		return Utilities::format(
			godot::String::utf8("\n %s: §%s%s§!"), godot::String::utf8(name), income ? "G" : "R", Utilities::cash_to_string_dp_dynamic(amount)
		);
	};
	const fixed_point_t total_income = taxes + tariff_budget.get_income() + country.get_gold_income_untracked() + extras.income();
	const fixed_point_t total_expenses = total_income - projected_balance;
	godot::String tooltip = Utilities::format(
		godot::String::utf8("Примерное дневное сальдо казны: §%s%s§!\n--------------\nПоступления: §G%s§!"),
		Utilities::get_colour_and_sign(projected_balance), Utilities::cash_to_string_dp_dynamic(projected_balance),
		Utilities::cash_to_string_dp_dynamic(total_income)
	);
	tooltip += line("Налоги", taxes, true);
	tooltip += line("Пошлины", tariff_budget.get_income(), true);
	tooltip += line("Золотодобыча", country.get_gold_income_untracked(), true);
	tooltip += line("Продажа товаров гос. запасов (за вчера)", extras.stockpile_sales, true);
	tooltip += line("Плата за перевозки (доля казны, за вчера)", extras.freight, true);
	tooltip += line("Прочее: дивиденды госзаводов, займы, выплаты (за вчера)", extras.other_income, true);
	tooltip += Utilities::format(godot::String::utf8("\n\nТраты: §R%s§!"), Utilities::cash_to_string_dp_dynamic(total_expenses));
	tooltip += line("Образование", education_budget.get_expenses(), false);
	tooltip += line("Управление", administration_budget.get_expenses(), false);
	tooltip += line("Социальная сфера (пенсии, пособия)", social_budget.get_expenses(), false);
	tooltip += line("Оборона (жалованье армии)", military_budget.get_expenses(), false);
	tooltip += line("Закупки товаров для гос. запасов: армия, флот, стройка (оплачено вчера)", country.get_actual_national_stockpile_spending().load(), false);
	tooltip += line("Отчисление в инвестиционный фонд", national_stockpile_budget.get_expenses() - national_stockpile_budget.get_military_supply_expenses(), false);
	tooltip += line("Субсидии промышленности (за вчера)", extras.subsidies, false);
	tooltip += line("Прочее: стройка, займы, проценты (за вчера)", extras.other_spending, false);
	tooltip += line("Дипломатия", diplomatic_budget.get_expenses(), false);
	tooltip += Utilities::format(
		godot::String::utf8("\n\nПотребность армии и флота в снабжении: §Y%s§! в день (армия §Y%s§!, флот §Y%s§!), казна оплачивает, сколько может."),
		Utilities::cash_to_string_dp_dynamic(national_stockpile_budget.get_military_supply_expenses()),
		Utilities::cash_to_string_dp_dynamic(country.calculate_army_supply_cost_per_day()),
		Utilities::cash_to_string_dp_dynamic(country.calculate_navy_supply_cost_per_day())
	);
	tooltip += godot::String::utf8(
		"\n\nКазна — «Гос. банк»: деньги страны. График вверху показывает фактическое изменение казны за день, сальдо — расчёт по "
		"ползункам и данным за вчера."
	);
	projected_balance_label.set_tooltip_string(tooltip);

	projected_balance_label.set_text(
	    Utilities::format(
	        godot::String::utf8("§%s%s§!"),
	        Utilities::get_colour_and_sign(projected_balance),
	        Utilities::cash_to_string_dp_dynamic(projected_balance)
	    )
	);
}

void BudgetMenu::update_projected_expenses() {
	static const godot::String projected_expenses_template = "%s\n--------------\n%s\n%s\n%s\n%s\n%s\n%s%s";
	CountryInstance const* const country_for_extras = PlayerSingleton::get_singleton()->get_player_country();
	const extras_t extras = country_for_extras != nullptr ? get_extras(*country_for_extras) : extras_t {};
	const fixed_point_t projected_expenses =
		administration_budget.get_expenses() + diplomatic_budget.get_expenses() + education_budget.get_expenses() +
		military_budget.get_expenses() + national_stockpile_budget.get_expenses() + social_budget.get_expenses() +
		tariff_budget.get_expenses() + extras.spending();
	// TODO: + import subsidies?
	// TODO: + factory subsidies
	// TODO: + interest
	const fixed_point_t interest_expenses = 0;

	projected_expenses_label.set_text(Utilities::cash_to_string_dp_dynamic(projected_expenses));

	projected_expenses_args[0] =
	    projected_expenses_label.tr("BUDGET_TOTAL_EXPENSE")
	        .replace(
	            Utilities::get_short_value_placeholder(),
	            Utilities::float_to_string_dp(static_cast<float>(projected_expenses), 3)
	        );
	projected_expenses_args[1] = education_budget.generate_expenses_summary_text(projected_expenses_label);
	projected_expenses_args[2] = administration_budget.generate_expenses_summary_text(projected_expenses_label);
	projected_expenses_args[3] = social_budget.generate_expenses_summary_text(projected_expenses_label);
	projected_expenses_args[4] = military_budget.generate_expenses_summary_text(projected_expenses_label);
	projected_expenses_args[5] =
	    projected_expenses_label.tr("BUDGET_INTEREST")
	        .replace(
	            Utilities::get_short_value_placeholder(),
	            Utilities::float_to_string_dp(static_cast<float>(interest_expenses), 1)
	        );
	projected_expenses_args[6] = national_stockpile_budget.generate_expenses_summary_text(projected_expenses_label);
	projected_expenses_args[7] = diplomatic_budget.generate_expenses_summary_text(projected_expenses_label);
	godot::String expenses_tooltip = projected_expenses_template % projected_expenses_args;
	// The spending that has no slider (the figures of the last day)
	expenses_tooltip += Utilities::format(
		godot::String::utf8("\n Субсидии промышленности: §Y%s§!\n Поправка: закупки гос. запасов фактически минус потребность армии и флота: §Y%s§!\n Стройка, займы и прочее: §Y%s§!"),
		Utilities::cash_to_string_dp_dynamic(extras.subsidies), Utilities::cash_to_string_dp_dynamic(extras.extra_purchases),
		Utilities::cash_to_string_dp_dynamic(extras.other_spending)
	);
	projected_expenses_label.set_tooltip_string(expenses_tooltip);
}

void BudgetMenu::update_projected_expenses_and_balance() {
	update_projected_expenses();
	update_projected_balance();
}

void BudgetMenu::update_projected_income() {
	CountryInstance const* const country_ptr = PlayerSingleton::get_singleton()->get_player_country();
	ERR_FAIL_NULL(country_ptr);
	CountryInstance const& country = *country_ptr;
	size_t i = 1;

	fixed_point_t projected_income_excluding_tariffs = 0;
	for (StrataTaxBudget const& strata_tax_budget : tax_budgets) {
		const fixed_point_t strata_tax = strata_tax_budget.get_income();
		projected_income_excluding_tariffs += strata_tax;
		projected_income_args[i++] = strata_tax_budget.generate_income_summary_text(projected_income_label);
	}

	projected_income_args[i++] = tariff_budget.generate_income_summary_text(projected_income_label);
	const fixed_point_t stockpile_income = country.get_actual_national_stockpile_income().load();
	projected_income_excluding_tariffs += stockpile_income;
	projected_income_args[i++] =
	    projected_income_label.tr("BUDGET_EXPORTS")
	        .replace(
	            Utilities::get_short_value_placeholder(), Utilities::float_to_string_dp(static_cast<float>(stockpile_income), 1)
	        );

	const fixed_point_t gold_income = country.get_gold_income_untracked();
	projected_income_excluding_tariffs += gold_income;
	projected_income_args[i++] =
	    projected_income_label.tr("BUDGET_GOLD")
	        .replace(
	            Utilities::get_short_value_placeholder(), Utilities::float_to_string_dp(static_cast<float>(gold_income), 1)
	        );
	projected_income_args[i++] = diplomatic_budget.generate_income_summary_text(projected_income_label);

	// The freight and the other income of the last day
	const extras_t extras = get_extras(country);
	projected_income_excluding_tariffs += extras.freight + extras.other_income;

	const fixed_point_t projected_income = projected_income_excluding_tariffs + tariff_budget.get_income();
	projected_income_args[0] =
	    projected_income_label.tr("BUDGET_TOTAL_INCOME")
	        .replace(
	            Utilities::get_short_value_placeholder(), Utilities::float_to_string_dp(static_cast<float>(projected_income), 3)
	        );
	projected_income_label.set_text(Utilities::cash_to_string_dp_dynamic(projected_income_excluding_tariffs));
	godot::String income_tooltip = projected_income_template % projected_income_args;
	income_tooltip += Utilities::format(
		godot::String::utf8("\n Плата за перевозки (доля казны): §Y%s§!\n Прочее (дивиденды, займы, выплаты): §Y%s§!"),
		Utilities::cash_to_string_dp_dynamic(extras.freight), Utilities::cash_to_string_dp_dynamic(extras.other_income)
	);
	projected_income_label.set_tooltip_string(income_tooltip);

	// TODO stockpile sold to construction projects
}

void BudgetMenu::update_projected_income_and_balance() {
	update_projected_income();
	update_projected_balance();
}

void BudgetMenu::update_all_projections() {
	update_projected_balance();
	update_projected_expenses();
	update_projected_income();
}

#define DO_FOR_ALL_COMPONENTS(F) \
	administration_budget.F; \
	diplomatic_budget.F; \
	education_budget.F; \
	military_budget.F; \
	national_stockpile_budget.F; \
	social_budget.F; \
	tariff_budget.F; \
	for (StrataTaxBudget& strata_tax_budget : tax_budgets) { \
		strata_tax_budget.F; \
	}

void BudgetMenu::update_strata_charts(CountryInstance const& country) {
	GameSingleton* game_singleton = GameSingleton::get_singleton();
	ERR_FAIL_NULL(game_singleton);

	// Slice of every pop type in the strata of its chart: the taxable income it provides, or its size while no income
	// has been calculated yet. The colour is the colour of the pop type and the tooltip names it.
	for (size_t chart_index = 0; chart_index < strata_charts.size(); ++chart_index) {
		GUIPieChart* const chart = strata_charts[chart_index];
		if (chart == nullptr) {
			continue;
		}

		for (const bool use_income : { true, false }) {
			godot::Array slices;
			float total = 0.0f;

			for (PopType const& pop_type : game_singleton->get_pop_types()) {
				if (static_cast<size_t>(type_safe::get(pop_type.strata.index)) != chart_index) {
					continue;
				}

				const float weight = use_income
				                       ? static_cast<float>(country.get_taxable_income_by_pop_type().at_index(pop_type.index))
				                       : static_cast<float>(type_safe::get(country.get_population_by_type()[pop_type.index]));
				if (weight <= 0.0f) {
					continue;
				}
				total += weight;

				godot::Dictionary slice;
				slice["identifier"] = convert_to<godot::String>(pop_type.get_identifier());
				slice["colour"] = convert_to<godot::Color>(pop_type.get_colour());
				slice["weight"] = weight;
				// The tooltip is completed below, when the total is known
				slice["tooltip"] = chart->tr(convert_to<godot::String>(pop_type.get_identifier()));
				slices.push_back(slice);
			}

			if (total <= 0.0f) {
				continue;
			}

			for (int64_t i = 0; i < slices.size(); ++i) {
				godot::Dictionary slice = slices[i];
				slice["tooltip"] = godot::String("%s: %d%%").replace("%s", slice["tooltip"]).replace(
				    "%d", godot::String::num_int64(static_cast<int64_t>(100.0f * static_cast<float>(slice["weight"]) / total))
				);
			}

			chart->set_slices_array(slices);
			break;
		}
	}
}

void BudgetMenu::update() {
	CountryInstance* const country_ptr = PlayerSingleton::get_singleton()->get_player_country();
	ERR_FAIL_NULL(country_ptr);
	CountryInstance& country = *country_ptr;

	// this will trigger a lot of signals we should ignore
	for (connection& c : connections) {
		c.block();
	};
	DO_FOR_ALL_COMPONENTS(full_update(country))
	for (connection& c : connections) {
		c.unblock();
	};
	update_all_projections();

	const fixed_point_t gold_income = country.get_gold_income_untracked();
	gold_income_label.set_text(
	    Utilities::format_with_currency(Utilities::float_to_string_dp(static_cast<float>(gold_income), 1))
	);
	gold_income_label.set_tooltip_string(
	    gold_income_label.tr("BUDGET_GOLD_INCOME_DESC")
	    // TODO add separator & list all province names + income if gold_income > 0
	);
	update_strata_charts(country);

	const fixed_point_t cash_stockpile = country.get_cash_stockpile();
	cash_stockpile_label.set_text(
	    Utilities::format_with_currency(Utilities::float_to_string_suffixed(static_cast<float>(cash_stockpile)))
	);
}

godot::String BudgetMenu::generate_projected_income_template(const size_t tax_budgets_size) {
	static const std::string_view projected_income_template_start = "%s\n--------------";
	static const std::string_view projected_income_template_dynamic_part = "\n%s";

	memory::string projected_income_template;
	projected_income_template.reserve(
	    projected_income_template_start.size() + projected_income_template_dynamic_part.size() * (tax_budgets_size + 3)
	);

	projected_income_template.append(projected_income_template_start);
	for (size_t i = 0; i < tax_budgets_size; ++i) {
		projected_income_template.append(projected_income_template_dynamic_part);
	}
	projected_income_template += "\n%s\n%s\n%s%s";
	return projected_income_template.data();
}

#undef DO_FOR_ALL_COMPONENTS

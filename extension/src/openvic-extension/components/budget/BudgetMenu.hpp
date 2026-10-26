#pragma once

#include <godot_cpp/classes/object.hpp>

#include <openvic-simulation/core/portable/ForwardableSpan.hpp>
#include <openvic-simulation/types/Signal.hpp>

#include "openvic-extension/components/budget/AdministrationBudget.hpp"
#include "openvic-extension/components/budget/DiplomaticBudget.hpp"
#include "openvic-extension/components/budget/EducationBudget.hpp"
#include "openvic-extension/components/budget/MilitaryBudget.hpp"
#include "openvic-extension/components/budget/NationalStockpileBudget.hpp"
#include "openvic-extension/components/budget/SocialBudget.hpp"
#include "openvic-extension/components/budget/StrataTaxBudget.hpp"
#include "openvic-extension/components/budget/TariffBudget.hpp"

namespace OpenVic {
	struct CountryInstance;
	class GUINode;
	struct GUILabel;
	class GUIPieChart;

	struct BudgetMenu {
	private:
		static godot::String generate_projected_income_template(const size_t tax_budgets_size);

		godot::String projected_income_template;
		godot::Array projected_income_args;
		godot::Array projected_expenses_args;
		memory::vector<connection> connections;
		GUILabel& cash_stockpile_label;
		GUILabel& gold_income_label;
		GUILabel& projected_balance_label;
		GUILabel& projected_expenses_label;
		GUILabel& projected_income_label;
		AdministrationBudget administration_budget;
		DiplomaticBudget diplomatic_budget;
		EducationBudget education_budget;
		MilitaryBudget military_budget;
		NationalStockpileBudget national_stockpile_budget;
		SocialBudget social_budget;
		TariffBudget tariff_budget;
		memory::vector<StrataTaxBudget> tax_budgets;
		// Pie charts of the classes (chart_0 to chart_2), one per strata, with a slice for each pop type of the strata
		memory::vector<GUIPieChart*> strata_charts;

		// What the sliders do not show but what changes the treasury (the figures of the last day): the income from the sales of the national
		// stockpile, the freight, other income (dividends, loans, ...), the subsidies of the factories, other spending (construction, loans,
		// ...) and the purchases of the national stockpile that are more than the supplies of the army and the navy
		struct extras_t {
			fixed_point_t stockpile_sales, freight, other_income;
			fixed_point_t subsidies, other_spending, extra_purchases;
			fixed_point_t income() const {
				return stockpile_sales + freight + other_income;
			}
			fixed_point_t spending() const {
				return subsidies + other_spending + extra_purchases;
			}
		};
		extras_t get_extras(CountryInstance const& country) const;

		void update_strata_charts(CountryInstance const& country);

		void update_projected_balance();
		void update_projected_expenses();
		void update_projected_expenses_and_balance();
		void update_projected_income();
		void update_projected_income_and_balance();
		void update_all_projections();

	public:
		BudgetMenu(
		    GUINode const& parent,
		    forwardable_span<const Strata> strata_keys,
		    ModifierEffectCache const& modifier_effect_cache,
		    CountryDefines const& country_defines
		);
		void update();
	};
}

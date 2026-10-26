#pragma once

#include "openvic-extension/components/budget/ArmyStockpileBudget.hpp"
#include "openvic-extension/components/budget/ConstructionStockpileBudget.hpp"
#include "openvic-extension/components/budget/NavyStockpileBudget.hpp"
#include "openvic-extension/components/budget/abstract/BudgetComponent.hpp"

namespace OpenVic {
	struct GUILabel;
	class GUINode;
	struct GUIScrollbar;

	struct NationalStockpileBudget : public BudgetComponent, public BudgetExpenseComponent {
	private:
		connection connections[3];
		GUILabel& military_costs_label;
		GUILabel& todays_actual_stockpile_spending_label;
		GUILabel& overseas_costs_label;
		GUILabel& expenses_label;
		ArmyStockpileBudget army_stockpile_budget;
		NavyStockpileBudget navy_stockpile_budget;
		ConstructionStockpileBudget construction_stockpile_budget;
		void on_slider_value_changed();
		void update_labels(CountryInstance& country);

	public:
		NationalStockpileBudget(GUINode const& parent);
		fixed_point_t get_expenses() const override;
		// The part of the expenses that is the supplies of the army and the navy (the rest is the allocation to the investment fund)
		fixed_point_t get_military_supply_expenses() const {
			return army_stockpile_budget.get_expenses() + navy_stockpile_budget.get_expenses();
		}
		void full_update(CountryInstance& country) override;
	};
}

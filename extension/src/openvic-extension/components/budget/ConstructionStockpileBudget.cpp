#include "ConstructionStockpileBudget.hpp"

#include <openvic-simulation/country/CountryInstance.hpp>

#include "openvic-extension/classes/GUIScrollbar.hpp"
#include "openvic-extension/singletons/PlayerSingleton.hpp"
#include "openvic-extension/utility/Utilities.hpp"

using namespace OpenVic;

ConstructionStockpileBudget::ConstructionStockpileBudget(GUINode const& parent) :
    SliderBudgetComponent(parent, "MILITARY_SPENDINGS_PROJECTS", EXPENSES, "./country_budget/projects_stockpile_slider"),
    BudgetExpenseComponent("MILITARY_SPENDINGS_PROJECTS") {
	slider.set_block_signals(true);
	slider.set_step_count(100);
	slider.set_scale(0, 1, 100);
	slider.set_block_signals(false);
}

fixed_point_t ConstructionStockpileBudget::get_expenses() const {
	return std::max(fixed_point_t::_0, -get_balance());
}

fixed_point_t ConstructionStockpileBudget::calculate_budget_and_update_custom(
    CountryInstance& country, const fixed_point_t scaled_value
) {
	// The slider is the allocation to the investment fund: 100 percent of it is half of the income (the budget) of the country
	return country.get_investment_allocation(scaled_value);
}

ReadOnlyClampedValue& ConstructionStockpileBudget::get_clamped_value(CountryInstance& country) const {
	return country.get_construction_spending_slider_value();
}

void ConstructionStockpileBudget::update_slider_tooltip(CountryInstance& country, const fixed_point_t scaled_value) {
	const fixed_point_t allocation = country.get_investment_allocation(scaled_value);
	slider.set_tooltip_string(
	    Utilities::format(
	        godot::String::utf8(
	            "Инвестиционный фонд (деньги на новое строительство)\nШкала: §Y%s§! — это §Y%s§! бюджета, §Y%s§! в день\n"
	            "В фонде сейчас: §Y%s§!\n\nРаз в неделю деньги получают те, кто построит прибыльное предприятие "
	            "или железную дорогу (прибыль за полгода не меньше 10%% стоимости постройки)."
	        ),
	        Utilities::percentage_to_string_dp(scaled_value, 1),
	        Utilities::percentage_to_string_dp(scaled_value * CountryInstance::get_investment_budget_share(), 1),
	        Utilities::cash_to_string_dp_dynamic(allocation),
	        Utilities::cash_to_string_dp_dynamic(country.get_investment_fund())
	    )
	);
}

void ConstructionStockpileBudget::on_slider_value_changed(const fixed_point_t scaled_value) {
	PlayerSingleton::get_singleton()->set_national_stockpile_construction_spending_slider_value(scaled_value);
}

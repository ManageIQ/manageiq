class ApplicationHelper::Button::ChargebackRates < ApplicationHelper::Button::ButtonNewDiscover
    def role_allows_feature?
      role_allows?(:feature => 'chargeback_rates')
    end

    def visible?
      super && @view_context.x_active_tree == :cb_rates_tree
    end
end

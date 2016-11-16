class ApplicationHelper::Button::ChargebackRates < ApplicationHelper::Button::Basic
    def role_allows_feature?
      role_allows?(:feature => 'chargeback_rates')
    end

    def visible?
      @view_context.x_active_tree == :cb_rates_tree
    end
end

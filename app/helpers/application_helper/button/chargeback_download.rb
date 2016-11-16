class ApplicationHelper::Button::ChargebackDownload < ApplicationHelper::Button::Basic
    def role_allows_feature?
      role_allows?(:feature => 'chargeback_reports')
    end

    def visible?
      @view_context.x_active_tree == :cb_reports_tree
    end
end

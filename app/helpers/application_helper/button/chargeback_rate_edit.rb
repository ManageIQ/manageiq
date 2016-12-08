class ApplicationHelper::Button::ChargebackRateEdit < ApplicationHelper::Button::ChargebackRates
  needs :@record

  def disabled?
    @error_message = _('Default Chargeback Rate cannot be edited.') if @record.default?
    @error_message.present?
  end
end

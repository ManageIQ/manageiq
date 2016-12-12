class ApplicationHelper::Button::ChargebackRateRemove < ApplicationHelper::Button::ChargebackRates
  needs :@record

  def disabled?
    @error_message = _('Default Chargeback Rate cannot be removed.') if default?
    @error_message.present?
  end

  private

  def default?
    @record.default? || @record.description == 'Default Container Image Rate'
  end
end

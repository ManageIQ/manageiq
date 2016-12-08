class ApplicationHelper::Button::ChargebackRateRemove < ApplicationHelper::Button::ChargebackRates
  needs :@record

  def disabled?
    if @record.default? || @record.description == 'Default Container Image Rate'
      @error_message = _("Default Chargeback Rate cannot be removed.")
    end
    @error_message.present?
  end

  def calculate_properties
    super
    self[:title] = @error_message if disabled?
  end
end

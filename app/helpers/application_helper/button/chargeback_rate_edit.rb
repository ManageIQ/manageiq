class ApplicationHelper::Button::ChargebackRateEdit < ApplicationHelper::Button::ChargebackRates
  needs :@record

  def disabled?
    if @record.default?
      @error_message = _("Default Chargeback Rate cannot be edited.")
    end
    @error_message.present?
  end

  def calculate_properties
    super
    self[:title] = @error_message if disabled?
  end
end

class ApplicationHelper::Button::ChargebackRateEdit < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if @record.default?
      self[:enabled] = false
      self[:title] = _("Default Chargeback Rate cannot be edited.")
    end
  end
end

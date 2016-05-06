class ApplicationHelper::Button::ChargebackRateRemove < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if @record.default?
      self[:enabled] = false
      self[:title] = N_("Default Chargeback Rate cannot be removed.")
    end
  end
end

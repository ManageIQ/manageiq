class ApplicationHelper::Button::ChargebackRateRemove < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if @record.default?  || @record.description == 'Default Container Image Rate'
      self[:enabled] = false
      self[:title] = _("Default Chargeback Rate cannot be removed.")
    end
  end
end

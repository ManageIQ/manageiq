class ApplicationHelper::Button::SetOwnership < ApplicationHelper::Button::Basic
  needs :@record

  def disabled?
    @record.try(:ext_management_system).try(:tenant_mapping_enabled?)
  end

  def calculate_properties
    super
    self[:title] = _('Ownership is controlled by tenant mapping') if disabled?
  end
end

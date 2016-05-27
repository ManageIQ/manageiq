class ApplicationHelper::Button::InstanceMigrate < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = @record.unsupported_reason(:live_migrate) if disabled?
  end

  def disabled?
    !@record.supports_live_migrate?
  end
end

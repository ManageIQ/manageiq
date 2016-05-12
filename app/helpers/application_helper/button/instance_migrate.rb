class ApplicationHelper::Button::InstanceMigrate < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = @record.is_available_now_error_message(:live_migrate) if disabled?
  end

  def disabled?
    !@record.is_available?(:live_migrate)
  end
end

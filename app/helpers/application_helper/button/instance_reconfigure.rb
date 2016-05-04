class ApplicationHelper::Button::InstanceReconfigure < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = @record.is_available_now_error_message(:resize) if disabled?
  end

  def disabled?
    !@record.is_available?(:resize)
  end
end

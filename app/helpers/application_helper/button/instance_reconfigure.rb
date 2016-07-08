class ApplicationHelper::Button::InstanceReconfigure < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = @record.unsupported_reason(:resize) if disabled?
  end

  def disabled?
    !@record.supports_resize?
  end
end

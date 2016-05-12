class ApplicationHelper::Button::InstanceEvacuate < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = @record.is_available_now_error_message(:evacuate) if disabled?
  end

  def disabled?
    !@record.is_available?(:evacuate)
  end
end

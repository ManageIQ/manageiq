class ApplicationHelper::Button::VolumeAttach < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = @record.is_available_now_error_message(:attach_volume) if disabled?
  end

  def disabled?
    !@record.is_available?(:attach_volume)
  end
end

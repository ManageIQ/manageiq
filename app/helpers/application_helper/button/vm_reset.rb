class ApplicationHelper::Button::VmReset < ApplicationHelper::Button::Basic
  needs_record

  def calculate_properties
    self[:title] = @error_message if disabled?
  end

  def skip?
    !@record.is_available?(:reset)
  end

  def disabled?
    !!(@error_message = @record.is_available_now_error_message(:reset))
  end
end

class ApplicationHelper::Button::VmSuspend < ApplicationHelper::Button::Basic
  needs_record

  def calculate_properties
    self[:title] = @error_message if disabled?
  end

  def skip?
    !@record.is_available?(:suspend)
  end

  def disabled?
    !!(@error_message = @record.is_available_now_error_message(:suspend))
  end
end

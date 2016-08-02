class ApplicationHelper::Button::VmStart < ApplicationHelper::Button::Basic
  needs_record

  def calculate_properties
    self[:title] = @error_message if disabled?
  end

  def skip?
    !@record.is_available?(:start)
  end

  def disabled?
    !!(@error_message = @record.is_available_now_error_message(:start))
  end
end

class ApplicationHelper::Button::VmStop < ApplicationHelper::Button::Basic
  needs_record

  def calculate_properties
    super
    self[:title] = @record.is_available_now_error_message(:stop) if disabled?
  end

  def skip?
    !@record.is_available?(:stop)
  end

  def disable?
    !!@record.is_available_now_error_message(:stop)
  end
end

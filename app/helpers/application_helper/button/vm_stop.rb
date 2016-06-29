class ApplicationHelper::Button::VmStop < ApplicationHelper::Button::Basic
  def skip?
    !@record.is_available?(:stop)
  end

  def disable?
    @record.is_available_now_error_message(:stop)
  end
end

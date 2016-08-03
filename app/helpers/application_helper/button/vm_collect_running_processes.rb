class ApplicationHelper::Button::VmCollectRunningProcesses < ApplicationHelper::Button::Basic
  needs_record

  def calculate_properties
    self[:title] = @error_message if disabled?
  end

  def skip?
    (@record.retired || @record.current_state == "never") && !@record.is_available?(:collect_running_processes)
  end

  def disabled?
    !!(@error_message = @record.is_available_now_error_message(:collect_running_processes))
  end
end

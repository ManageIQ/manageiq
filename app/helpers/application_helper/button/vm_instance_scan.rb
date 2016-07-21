class ApplicationHelper::Button::VmInstanceScan < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    return false if @display == "instances"
    !(@record.is_available?(:smartstate_analysis) ||
      @record.is_available_now_error_message(:smartstate_analysis)) ||
    !@record.has_proxy?
  end

  def disable?
    if !@record.is_available?(:smartstate_analysis)
      return @record.is_available_now_error_message(:smartstate_analysis)
    elsif !@record.has_active_proxy?
      return @record.active_proxy_error_message
    end
  end
end

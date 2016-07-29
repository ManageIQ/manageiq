class ApplicationHelper::Button::VmInstanceScan < ApplicationHelper::Button::Basic
  needs_record

  def calculate_properties
    super
    if disabled?
      self[:title] = if !@record.is_available?(:smartstate_analysis)
                       @record.is_available_now_error_message(:smartstate_analysis)
                     else
                       @record.active_proxy_error_message
                     end
    end
  end

  def skip?
    return false if @display == "instances"
    !(@record.is_available?(:smartstate_analysis) ||
      @record.is_available_now_error_message(:smartstate_analysis)) ||
    !@record.has_proxy?
  end

  def disabled?
    return false if @display == "instances"
    !(@record.is_available?(:smartstate_analysis) && @record.has_active_proxy?)
  end
end

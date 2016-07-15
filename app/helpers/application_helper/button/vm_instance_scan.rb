class ApplicationHelper::Button::VmInstanceScan < ApplicationHelper::Button::Basic
  needs_record

  def calculate_properties
    super
    if disabled?
      self[:title] = if !@record.supports_smartstate_analysis?
                       @record.unsupported_reason(:smartstate_analysis)
                     else
                       @record.active_proxy_error_message
                     end
    end
  end

  def skip?
    return false if @display == "instances"
    !(@record.supports_smartstate_analysis? || @record.unsupported_reason(:smartstate_analysis)) ||
      !@record.has_proxy?
  end

  def disabled?
    return false if @display == "instances"
    !(@record.supports_smartstate_analysis? && @record.has_active_proxy?)
  end
end

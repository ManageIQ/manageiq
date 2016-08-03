class ApplicationHelper::Button::InstanceReset < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    return false if @record.kind_of?(OrchestrationStack) && @display == "instances"
    !@record.is_available?(:reset)
  end
end

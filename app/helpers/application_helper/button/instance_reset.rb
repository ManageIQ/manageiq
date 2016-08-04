class ApplicationHelper::Button::InstanceReset < ApplicationHelper::Button::Basic
  needs_record

  def visible?
    return true if @display == "instances" #&& @record.kind_of?(OrchestrationStack)
    @record.is_available?(:reset)
  end
end

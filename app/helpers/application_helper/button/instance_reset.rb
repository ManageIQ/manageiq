class ApplicationHelper::Button::InstanceReset < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    return true if @display == "instances"
    @record.is_available?(:reset)
  end
end

class ApplicationHelper::Button::InstanceReset < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    return true if @display == "instances"
    @record.supports_reset?
  end
end

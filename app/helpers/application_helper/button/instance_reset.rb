class ApplicationHelper::Button::InstanceReset < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    return false if @display == "instances"
    !@record.is_available?(:reset)
  end
end

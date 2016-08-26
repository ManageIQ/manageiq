class ApplicationHelper::Button::InstanceReset < ApplicationHelper::Button::Basic
  needs_record

  def visible?
    return true if @display == "instances"
    @record.is_available?(:reset)
  end
end

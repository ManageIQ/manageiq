class ApplicationHelper::Button::InstanceSuspend < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    !@record.is_available?(:suspend)
  end
end

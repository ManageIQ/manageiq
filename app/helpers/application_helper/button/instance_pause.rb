class ApplicationHelper::Button::InstancePause < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    !@record.is_available?(:pause)
  end
end

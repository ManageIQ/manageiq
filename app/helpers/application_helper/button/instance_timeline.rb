class ApplicationHelper::Button::InstanceTimeline < ApplicationHelper::Button::Basic
  def skip?
    !@record.is_available?(:timeline)
  end
end

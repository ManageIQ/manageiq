class ApplicationHelper::Button::EmsContainerTimeline < ApplicationHelper::Button::Basic
  def skip?
    !@record.is_available?(:timeline)
  end
end

class ApplicationHelper::Button::EmsCloudTimeline < ApplicationHelper::Button::Basic
  def skip?
    !@record.is_available?(:timeline)
  end
end

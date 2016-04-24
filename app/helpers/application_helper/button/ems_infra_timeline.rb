class ApplicationHelper::Button::EmsInfraTimeline < ApplicationHelper::Button::Basic
  def skip?
    !@record.is_available?(:timeline)
  end
end

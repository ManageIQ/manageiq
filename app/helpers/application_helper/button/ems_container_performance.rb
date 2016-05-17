class ApplicationHelper::Button::EmsContainerPerformance < ApplicationHelper::Button::Basic
  def skip?
    !@record.is_available?(:performance)
  end
end

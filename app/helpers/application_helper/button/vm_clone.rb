class ApplicationHelper::Button::VmClone < ApplicationHelper::Button::Basic
  def skip?
    !@record.is_available?(:clone)
  end
end

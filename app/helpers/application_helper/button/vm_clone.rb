class ApplicationHelper::Button::VmClone < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    !@record.is_available?(:clone)
  end
end

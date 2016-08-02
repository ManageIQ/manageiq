class ApplicationHelper::Button::InstanceStart < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    !@record.is_available?(:start)
  end
end

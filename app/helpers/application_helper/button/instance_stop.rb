class ApplicationHelper::Button::InstanceStop < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    !@record.is_available?(:stop)
  end
end

class ApplicationHelper::Button::InstanceShelve < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    !@record.is_available?(:shelve)
  end
end

class ApplicationHelper::Button::InstanceMigrate < ApplicationHelper::Button::Basic
  def skip?
    !@record.is_available?(:live_migrate)
  end
end

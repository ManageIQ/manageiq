class ApplicationHelper::Button::VmMigrate < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    !@record.supports_migrate?
  end
end

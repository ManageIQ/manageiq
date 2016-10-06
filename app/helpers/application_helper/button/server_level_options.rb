class ApplicationHelper::Button::ServerLevelOptions < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    @record.class == AssignedServerRole && @record.master_supported?
  end
end

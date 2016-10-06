class ApplicationHelper::Button::RolePowerOptions < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    @record.class == AssignedServerRole && @record.miq_server.started?
  end
end

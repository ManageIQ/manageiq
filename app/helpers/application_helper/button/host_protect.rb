class ApplicationHelper::Button::HostProtect < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    @record.smart?
  end
end

class ApplicationHelper::Button::HostProtect < ApplicationHelper::Button::Basic
  needs_record

  def visible?
    @record.smart?
  end
end

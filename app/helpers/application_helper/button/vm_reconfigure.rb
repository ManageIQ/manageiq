class ApplicationHelper::Button::VmReconfigure < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    @record.reconfigurable?
  end
end

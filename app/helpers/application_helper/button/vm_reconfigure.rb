class ApplicationHelper::Button::VmReconfigure < ApplicationHelper::Button::Basic
  needs_record

  def visible?
    @record.reconfigurable?
  end
end

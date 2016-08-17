class ApplicationHelper::Button::VmReconfigure < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    !@record.reconfigurable?
  end
end

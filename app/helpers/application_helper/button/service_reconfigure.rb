class ApplicationHelper::Button::ServiceReconfigure < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    !@record.validate_reconfigure
  end
end

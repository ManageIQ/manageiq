class ApplicationHelper::Button::MiqAeClassCopy < ApplicationHelper::Button::MiqAe
  needs :@record

  def visible?
    super || editable_domain?(@record)
  end
end

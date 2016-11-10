class ApplicationHelper::Button::MiqAeDefault < ApplicationHelper::Button::MiqAe
  needs :@record

  def disabled?
    false
  end

  def visible?
    super || editable_domain?(@record)
  end
end

class ApplicationHelper::Button::PolicyEditEvents < ApplicationHelper::Button::PolicyEdit

  def visible?
    !(@policy.mode == "compliance")
  end
end

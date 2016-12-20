class ApplicationHelper::Button::BlankButton < ApplicationHelper::Button::ButtonWithoutRbacCheck
  def visible?
    false
  end
end

class ApplicationHelper::Button::ButtonWithoutRbacCheck < ApplicationHelper::Button::Basic
  def role_allows_feature?
    true
  end
end

class ApplicationHelper::Button::PolicyEdit < ApplicationHelper::Button::PolicyButton

  def role_allows_feature?
    role_allows?(:feature => "policy_edit")
  end
end
